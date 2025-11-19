/// File system watcher for syncing markdown files with database
library;

import 'dart:io';
import 'dart:async';
import 'package:watcher/watcher.dart';
import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'database.dart';
import 'repositories/page_repository.dart';
import '../utils/logseq_utils.dart';
import '../models/page.dart';

/// Watches markdown files and syncs changes with database
class FileWatcher {
  final String graphPath;
  final LogseqDatabase database;
  final PageRepository pageRepository;

  StreamSubscription<WatchEvent>? _watcherSubscription;
  final _ignoredWrites = <String>{};
  Timer? _debounceTimer;
  final _pendingChanges = <String, WatchEvent>{};

  FileWatcher({
    required this.graphPath,
    required this.database,
    required this.pageRepository,
  });

  /// Start watching for file changes
  Future<void> start() async {
    final watcher = DirectoryWatcher(graphPath);

    _watcherSubscription = watcher.events.listen((event) {
      _handleFileEvent(event);
    });
  }

  /// Stop watching
  Future<void> stop() async {
    await _watcherSubscription?.cancel();
    _watcherSubscription = null;
    _debounceTimer?.cancel();
  }

  /// Handle file system event with debouncing
  void _handleFileEvent(WatchEvent event) {
    final path = event.path;

    // Ignore non-markdown files
    if (!path.endsWith('.md')) return;

    // Ignore .logseq directory
    if (path.contains('.logseq')) return;

    // Ignore our own writes
    if (_ignoredWrites.contains(path)) {
      _ignoredWrites.remove(path);
      return;
    }

    // Debounce rapid changes
    _pendingChanges[path] = event;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _processPendingChanges();
    });
  }

  /// Process all pending file changes
  Future<void> _processPendingChanges() async {
    final changes = Map<String, WatchEvent>.from(_pendingChanges);
    _pendingChanges.clear();

    for (final entry in changes.entries) {
      final path = entry.key;
      final event = entry.value;

      try {
        switch (event.type) {
          case ChangeType.ADD:
          case ChangeType.MODIFY:
            await _syncFileToDatabase(path);
            break;
          case ChangeType.REMOVE:
            await _removeFileFromDatabase(path);
            break;
        }
      } catch (e) {
        print('Error syncing file $path: $e');
      }
    }
  }

  /// Sync a markdown file to the database
  Future<void> _syncFileToDatabase(String filePath) async {
    final file = File(filePath);

    if (!file.existsSync()) return;

    // Check if file has changed since last sync
    final stats = file.statSync();
    final lastModified = stats.modified;
    final content = await file.readAsString();
    final checksum = md5.convert(utf8.encode(content)).toString();

    final db = await database.database;

    // Check sync state
    final syncState = await db.query(
      'file_sync_state',
      where: 'file_path = ?',
      whereArgs: [filePath],
    );

    if (syncState.isNotEmpty) {
      final lastChecksum = syncState.first['checksum'] as String?;
      if (lastChecksum == checksum) {
        // File hasn't changed, skip
        return;
      }
    }

    // Parse the markdown file
    final pageName = p.basenameWithoutExtension(filePath);
    final page = Page(name: pageName, filePath: filePath);

    // Check if it's a journal page
    page.isJournal = LogseqUtils.isJournalPage(pageName);
    if (page.isJournal) {
      page.journalDate = LogseqUtils.parseJournalDate(pageName);
    }

    // Parse blocks from content
    final blocks = LogseqUtils.parseBlocksFromContent(content, pageName);
    for (final block in blocks) {
      page.addBlock(block);
    }

    // Extract page-level properties
    final properties = LogseqUtils.extractPageProperties(content);
    page.properties.addAll(properties);

    // Save to database
    await pageRepository.savePage(page);

    // Update sync state
    await db.insert(
      'file_sync_state',
      {
        'file_path': filePath,
        'last_modified': lastModified.toIso8601String(),
        'last_synced': DateTime.now().toIso8601String(),
        'checksum': checksum,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Remove a file from the database
  Future<void> _removeFileFromDatabase(String filePath) async {
    final pageName = p.basenameWithoutExtension(filePath);

    await pageRepository.deletePage(pageName);

    final db = await database.database;
    await db.delete(
      'file_sync_state',
      where: 'file_path = ?',
      whereArgs: [filePath],
    );
  }

  /// Mark a file write as ignored (to prevent sync loop)
  void ignoreNextWrite(String filePath) {
    _ignoredWrites.add(filePath);

    // Auto-remove after a timeout
    Timer(const Duration(seconds: 2), () {
      _ignoredWrites.remove(filePath);
    });
  }

  /// Perform initial sync of all markdown files
  Future<void> initialSync() async {
    print('Performing initial sync of markdown files...');

    final dir = Directory(graphPath);
    final markdownFiles = dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.md'))
        .where((file) => !file.path.contains('.logseq'));

    int synced = 0;
    int errors = 0;

    for (final file in markdownFiles) {
      try {
        await _syncFileToDatabase(file.path);
        synced++;
      } catch (e) {
        print('Error syncing ${file.path}: $e');
        errors++;
      }
    }

    print('Initial sync complete: $synced files synced, $errors errors');
  }

  /// Check if database needs initial sync
  Future<bool> needsInitialSync() async {
    final db = await database.database;

    final pageCount = await db.rawQuery('SELECT COUNT(*) as count FROM pages');
    final count = pageCount.first['count'] as int;

    return count == 0;
  }
}
