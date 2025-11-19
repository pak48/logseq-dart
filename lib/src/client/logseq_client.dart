/// Database-backed Logseq client with same API as original
library;

import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import '../models/block.dart';
import '../models/page.dart';
import '../models/graph.dart';
import '../utils/logseq_utils.dart';
import '../query/query_builder.dart';
import '../storage/database.dart';
import '../storage/cache.dart';
import '../storage/file_watcher.dart';
import '../storage/repositories/page_repository.dart';
import '../storage/repositories/block_repository.dart';
import '../storage/repositories/graph_repository.dart';

/// Configuration for LogseqClient
///
/// IMPORTANT: Markdown files are the GROUND TRUTH.
/// The database serves as a cache/index for performance.
/// All writes go to files first, then database is updated.
class LogseqClientConfig {
  /// Maximum number of pages to cache
  final int maxCachedPages;

  /// Maximum number of blocks to cache
  final int maxCachedBlocks;

  /// Enable file system watcher (recommended: true)
  /// Keeps database synchronized with file changes
  final bool enableFileWatcher;

  /// Custom database path (default: graphPath/.logseq/logseq.db)
  final String? databasePath;

  const LogseqClientConfig({
    this.maxCachedPages = 100,
    this.maxCachedBlocks = 1000,
    this.enableFileWatcher = true,
    this.databasePath,
  });
}

/// Main client for interacting with Logseq graphs (database-backed)
class LogseqClient {
  final String graphPath;
  final LogseqClientConfig config;

  late final LogseqDatabase _database;
  late final LogseqCache _cache;
  late final BlockRepository _blockRepository;
  late final PageRepository _pageRepository;
  late final GraphRepository _graphRepository;
  late final FileWatcher? _fileWatcher;

  bool _initialized = false;
  LogseqGraph? _graph;

  LogseqClient(
    this.graphPath, {
    LogseqClientConfig? config,
  }) : config = config ?? const LogseqClientConfig() {
    final dir = Directory(graphPath);
    if (!dir.existsSync()) {
      throw FileSystemException('Graph directory not found', graphPath);
    }
  }

  /// Initialize the database and repositories
  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize database
    _database = LogseqDatabase(graphPath);

    // Initialize repositories
    _blockRepository = BlockRepository(_database);
    _pageRepository = PageRepository(_database, _blockRepository);
    _graphRepository = GraphRepository(_database, _pageRepository, _blockRepository);

    // Initialize cache
    _cache = LogseqCache(
      maxPages: config.maxCachedPages,
      maxBlocks: config.maxCachedBlocks,
    );

    // Initialize file watcher
    if (config.enableFileWatcher) {
      _fileWatcher = FileWatcher(
        graphPath: graphPath,
        database: _database,
        pageRepository: _pageRepository,
      );

      // Check if we need initial sync
      if (await _fileWatcher!.needsInitialSync()) {
        await _fileWatcher!.initialSync();
      }

      await _fileWatcher!.start();
    }

    _initialized = true;
  }

  /// Ensure client is initialized
  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('LogseqClient not initialized. Call initialize() first.');
    }
  }

  /// Get the loaded graph (lazy loading from database)
  LogseqGraph get graph {
    _ensureInitialized();

    if (_graph == null) {
      // Create a lazy-loading graph wrapper
      _graph = LogseqGraph(
        rootPath: graphPath,
        pages: {},
        blocks: {},
      );
    }

    return _graph!;
  }

  /// Load the Logseq graph from database
  Future<LogseqGraph> loadGraph({bool forceReload = false}) async {
    await initialize();

    if (_graph != null && !forceReload) {
      return _graph!;
    }

    // Load all pages from database
    final pages = await _pageRepository.getAllPages();

    _graph = LogseqGraph(
      rootPath: graphPath,
      pages: {for (var p in pages) p.name: p},
      blocks: {for (var p in pages) for (var b in p.blocks) b.id: b},
    );

    return _graph!;
  }

  /// Load the graph synchronously (fallback to database)
  LogseqGraph loadGraphSync({bool forceReload = false}) {
    // Note: This is kept for API compatibility but now requires async init
    _ensureInitialized();

    if (_graph != null && !forceReload) {
      return _graph!;
    }

    // Return empty graph, actual data loaded via async methods
    _graph = LogseqGraph(rootPath: graphPath);
    return _graph!;
  }

  /// Create a new query builder
  QueryBuilder query() {
    return QueryBuilder(graph);
  }

  /// Get a page by name (with caching)
  Page? getPage(String pageName) {
    _ensureInitialized();

    // Try to get from graph if loaded
    if (_graph != null && _graph!.pages.containsKey(pageName)) {
      return _graph!.pages[pageName];
    }

    // This is synchronous, so we can't await
    // Caller should use getPageAsync for database lookup
    return null;
  }

  /// Get a page by name (async, from database)
  Future<Page?> getPageAsync(String pageName) async {
    await initialize();

    return await _pageRepository.getPage(pageName);
  }

  /// Get a block by ID (with caching)
  Block? getBlock(String blockId) {
    _ensureInitialized();

    // Try to get from graph if loaded
    if (_graph != null && _graph!.blocks.containsKey(blockId)) {
      return _graph!.blocks[blockId];
    }

    return null;
  }

  /// Get a block by ID (async, from database)
  Future<Block?> getBlockAsync(String blockId) async {
    await initialize();

    return await _blockRepository.getBlock(blockId);
  }

  /// Create a new page
  Future<Page> createPage(
    String name, {
    String? content,
    Map<String, dynamic>? properties,
  }) async {
    await initialize();

    // Ensure valid page name
    final validName = LogseqUtils.ensureValidPageName(name);

    // Check if page already exists
    final existing = await _pageRepository.getPage(validName);
    if (existing != null) {
      throw StateError('Page "$validName" already exists');
    }

    // Create file path
    final filePath = p.join(graphPath, '$validName.md');

    // Create page object
    final page = Page(
      name: validName,
      filePath: filePath,
      properties: properties ?? {},
    );

    // Add content as blocks if provided
    if (content != null && content.isNotEmpty) {
      final blocks = LogseqUtils.parseBlocksFromContent(content, validName);
      for (final block in blocks) {
        page.addBlock(block);
      }
    }

    // FILES ARE GROUND TRUTH: Write to disk first
    _fileWatcher?.ignoreNextWrite(filePath);
    await _savePageToFile(page);

    // Then update database (cache/index)
    await _pageRepository.savePage(page);

    // Add to graph if loaded
    if (_graph != null) {
      _graph!.addPage(page);
    }

    return page;
  }

  /// Add a journal entry
  Future<Page> addJournalEntry(String content, {DateTime? date}) async {
    await initialize();

    final journalDate = date ?? DateTime.now();
    final pageName = LogseqUtils.formatDateForJournal(journalDate);

    // Get or create journal page
    var page = await _pageRepository.getPage(pageName);
    if (page == null) {
      page = await createJournalPage(journalDate);
    }

    // Add content as a new block
    final block = Block(content: content, pageName: pageName);
    page.addBlock(block);

    // FILES ARE GROUND TRUTH: Write to disk first
    if (page.filePath != null) {
      _fileWatcher?.ignoreNextWrite(page.filePath!);
      await _savePageToFile(page);
    }

    // Then update database (cache/index)
    await _pageRepository.savePage(page);

    // Update graph if loaded
    if (_graph != null) {
      _graph!.pages[pageName] = page;
      _graph!.blocks[block.id] = block;
    }

    return page;
  }

  /// Create a new journal page
  Future<Page> createJournalPage(DateTime date) async {
    await initialize();

    final pageName = LogseqUtils.formatDateForJournal(date);
    final journalsDir = Directory(p.join(graphPath, 'journals'));
    if (!journalsDir.existsSync()) {
      journalsDir.createSync(recursive: true);
    }
    final filePath = p.join(journalsDir.path, '$pageName.md');

    final page = Page(
      name: pageName,
      filePath: filePath,
      isJournal: true,
      journalDate: date,
    );

    // FILES ARE GROUND TRUTH: Write to disk first
    _fileWatcher?.ignoreNextWrite(filePath);
    await _savePageToFile(page);

    // Then update database (cache/index)
    await _pageRepository.savePage(page);

    // Add to graph if loaded
    if (_graph != null) {
      _graph!.addPage(page);
    }

    return page;
  }

  /// Add a block to a page
  Future<Block> addBlockToPage(
    String pageName,
    String content, {
    String? parentBlockId,
  }) async {
    await initialize();

    final page = await _pageRepository.getPage(pageName);
    if (page == null) {
      throw StateError('Page "$pageName" not found');
    }

    // Create new block
    final block = Block(content: content, pageName: pageName);

    // Handle parent-child relationship
    if (parentBlockId != null) {
      final parentBlock = await _blockRepository.getBlock(parentBlockId);
      if (parentBlock != null && parentBlock.pageName == pageName) {
        parentBlock.addChild(block);
      }
    }

    // Add to page
    page.addBlock(block);

    // FILES ARE GROUND TRUTH: Write to disk first
    if (page.filePath != null) {
      _fileWatcher?.ignoreNextWrite(page.filePath!);
      await _savePageToFile(page);
    }

    // Then update database (cache/index)
    await _pageRepository.savePage(page);

    // Update graph if loaded
    if (_graph != null) {
      _graph!.pages[pageName] = page;
      _graph!.blocks[block.id] = block;
    }

    return block;
  }

  /// Update the content of an existing block
  Future<Block?> updateBlock(String blockId, String content) async {
    await initialize();

    final block = await _blockRepository.getBlock(blockId);
    if (block == null) return null;

    // Update content
    block.content = content;
    block.updatedAt = DateTime.now();

    // Get the page and save
    if (block.pageName != null) {
      final page = await _pageRepository.getPage(block.pageName!);
      if (page != null) {
        // Update block in page
        final blockIndex = page.blocks.indexWhere((b) => b.id == blockId);
        if (blockIndex >= 0) {
          page.blocks[blockIndex] = block;
        }

        // FILES ARE GROUND TRUTH: Write to disk first
        if (page.filePath != null) {
          _fileWatcher?.ignoreNextWrite(page.filePath!);
          await _savePageToFile(page);
        }

        // Then update database (cache/index)
        await _pageRepository.savePage(page);

        // Update graph if loaded
        if (_graph != null) {
          _graph!.blocks[blockId] = block;
        }
      }
    }

    return block;
  }

  /// Delete a block
  Future<bool> deleteBlock(String blockId) async {
    await initialize();

    final block = await _blockRepository.getBlock(blockId);
    if (block == null) return false;

    final page = block.pageName != null
        ? await _pageRepository.getPage(block.pageName!)
        : null;
    if (page == null) return false;

    // Remove from page
    page.blocks.removeWhere((b) => b.id == blockId);

    // FILES ARE GROUND TRUTH: Write to disk first
    if (page.filePath != null) {
      _fileWatcher?.ignoreNextWrite(page.filePath!);
      await _savePageToFile(page);
    }

    // Then update database (cache/index)
    await _pageRepository.savePage(page);

    // Update graph if loaded
    if (_graph != null) {
      _graph!.blocks.remove(blockId);
    }

    return true;
  }

  /// Save a page to disk
  Future<void> _savePageToFile(Page page) async {
    if (page.filePath == null) return;

    // Ensure parent directory exists
    final file = File(page.filePath!);
    final dir = file.parent;
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    // Generate markdown content
    final content = page.toMarkdown();

    // Write to file
    await file.writeAsString(content);

    // Update timestamps
    page.updatedAt = DateTime.now();
  }

  /// Get graph statistics
  Future<Map<String, dynamic>> getStatistics() async {
    await initialize();

    return await _graphRepository.getStatistics();
  }

  /// Search for text across all pages
  Future<Map<String, List<Block>>> search(
    String query, {
    bool caseSensitive = false,
  }) async {
    await initialize();

    final resultIds = await _graphRepository.searchContent(
      query,
      caseSensitive: caseSensitive,
    );

    final results = <String, List<Block>>{};
    for (final entry in resultIds.entries) {
      final blocks = <Block>[];
      for (final blockId in entry.value) {
        final block = await _blockRepository.getBlock(blockId);
        if (block != null) {
          blocks.add(block);
        }
      }
      if (blocks.isNotEmpty) {
        results[entry.key] = blocks;
      }
    }

    return results;
  }

  /// Export the graph to JSON format
  Future<void> exportToJson(String outputPath) async {
    await initialize();

    final stats = await getStatistics();
    final pages = await _pageRepository.getAllPages();

    final graphData = {
      'rootPath': graphPath,
      'pages': {for (var page in pages) page.name: page.toJson()},
      'statistics': stats,
    };

    final file = File(outputPath);
    final encoder = const JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(graphData));
  }

  /// Reload the graph from database
  Future<LogseqGraph> reloadGraph() {
    return loadGraph(forceReload: true);
  }

  /// Close the client and cleanup resources
  Future<void> close() async {
    await _fileWatcher?.stop();
    await _database.close();
  }

  /// Get cache statistics
  Map<String, int> getCacheStats() {
    return _cache.getStats();
  }
}
