/// Main client class for Logseq operations
library;

import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import '../models/block.dart';
import '../models/page.dart';
import '../models/graph.dart';
import '../utils/logseq_utils.dart';
import '../query/query_builder.dart';

/// Main client for interacting with Logseq graphs
class LogseqClient {
  final String graphPath;
  LogseqGraph? _graph;
  final Set<String> _modifiedPages = {};

  LogseqClient(this.graphPath) {
    final dir = Directory(graphPath);
    if (!dir.existsSync()) {
      throw FileSystemException('Graph directory not found', graphPath);
    }
  }

  /// Get the loaded graph (loads if not already loaded)
  LogseqGraph get graph {
    _graph ??= loadGraphSync();
    return _graph!;
  }

  /// Load the Logseq graph from disk
  Future<LogseqGraph> loadGraph({bool forceReload = false}) async {
    if (_graph != null && !forceReload) {
      return _graph!;
    }

    _graph = LogseqGraph(rootPath: graphPath);

    // Find all markdown files
    final dir = Directory(graphPath);
    final markdownFiles = dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.md'))
        .where((file) => !file.path.contains('.logseq'));

    for (final mdFile in markdownFiles) {
      try {
        final page = await LogseqUtils.parseMarkdownFile(mdFile.path);
        _graph!.addPage(page);
      } catch (e) {
        print('Warning: Could not parse ${mdFile.path}: $e');
      }
    }

    // Update backlinks
    _updateBacklinks();

    return _graph!;
  }

  /// Load the graph synchronously
  LogseqGraph loadGraphSync({bool forceReload = false}) {
    if (_graph != null && !forceReload) {
      return _graph!;
    }

    _graph = LogseqGraph(rootPath: graphPath);

    // Find all markdown files
    final dir = Directory(graphPath);
    final markdownFiles = dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.md'))
        .where((file) => !file.path.contains('.logseq'));

    for (final mdFile in markdownFiles) {
      try {
        // Synchronous parsing
        final file = File(mdFile.path);
        final content = file.readAsStringSync();
        final pageName =
            p.basenameWithoutExtension(mdFile.path);

        final page = Page(name: pageName, filePath: mdFile.path);

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

        _graph!.addPage(page);
      } catch (e) {
        print('Warning: Could not parse ${mdFile.path}: $e');
      }
    }

    // Update backlinks
    _updateBacklinks();

    return _graph!;
  }

  /// Update backlink information for all pages
  void _updateBacklinks() {
    if (_graph == null) return;

    for (final page in _graph!.pages.values) {
      page.backlinks.clear();
      page.backlinks.addAll(_graph!.getBacklinks(page.name));
    }
  }

  /// Create a new query builder
  QueryBuilder query() {
    return QueryBuilder(graph);
  }

  /// Get a page by name
  Page? getPage(String pageName) {
    return graph.getPage(pageName);
  }

  /// Get a block by ID
  Block? getBlock(String blockId) {
    return graph.getBlock(blockId);
  }

  /// Create a new page
  Future<Page> createPage(
    String name, {
    String? content,
    Map<String, dynamic>? properties,
  }) async {
    // Ensure valid page name
    final validName = LogseqUtils.ensureValidPageName(name);

    // Check if page already exists
    if (graph.getPage(validName) != null) {
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

    // Save to disk
    await _savePage(page);

    // Add to graph
    graph.addPage(page);

    return page;
  }

  /// Add a journal entry
  Future<Page> addJournalEntry(String content, {DateTime? date}) async {
    final journalDate = date ?? DateTime.now();
    final pageName = LogseqUtils.formatDateForJournal(journalDate);

    // Get or create journal page
    var page = graph.getPage(pageName);
    if (page == null) {
      page = await createJournalPage(journalDate);
    }

    // Add content as a new block
    final block = Block(content: content, pageName: pageName);
    page.addBlock(block);
    graph.blocks[block.id] = block;

    // Save to disk
    await _savePage(page);

    return page;
  }

  /// Create a new journal page
  Future<Page> createJournalPage(DateTime date) async {
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

    // Save to disk
    await _savePage(page);

    // Add to graph
    graph.addPage(page);

    return page;
  }

  /// Add a block to a page
  Future<Block> addBlockToPage(
    String pageName,
    String content, {
    String? parentBlockId,
  }) async {
    final page = graph.getPage(pageName);
    if (page == null) {
      throw StateError('Page "$pageName" not found');
    }

    // Create new block
    final block = Block(content: content, pageName: pageName);

    // Handle parent-child relationship
    if (parentBlockId != null) {
      final parentBlock = graph.getBlock(parentBlockId);
      if (parentBlock != null && parentBlock.pageName == pageName) {
        parentBlock.addChild(block);
      }
    }

    // Add to page and graph
    page.addBlock(block);
    graph.blocks[block.id] = block;

    // Save to disk
    await _savePage(page);

    return block;
  }

  /// Update the content of an existing block
  Future<Block?> updateBlock(String blockId, String content) async {
    final block = graph.getBlock(blockId);
    if (block == null) return null;

    // Update content
    block.content = content;
    block.updatedAt = DateTime.now();

    // Save to disk
    if (block.pageName != null) {
      final page = graph.getPage(block.pageName!);
      if (page != null) {
        await _savePage(page);
      }
    }

    return block;
  }

  /// Delete a block
  Future<bool> deleteBlock(String blockId) async {
    final block = graph.getBlock(blockId);
    if (block == null) return false;

    final page = block.pageName != null ? graph.getPage(block.pageName!) : null;
    if (page == null) return false;

    // Remove from parent
    if (block.parentId != null) {
      final parent = graph.getBlock(block.parentId!);
      if (parent != null) {
        parent.childrenIds.remove(blockId);
      }
    }

    // Handle children (promote to parent level)
    for (final childId in block.childrenIds) {
      final child = graph.getBlock(childId);
      if (child != null) {
        child.parentId = block.parentId;
      }
    }

    // Remove from page and graph
    page.blocks.removeWhere((b) => b.id == blockId);
    graph.blocks.remove(blockId);

    // Save to disk
    await _savePage(page);

    return true;
  }

  /// Save a page to disk
  Future<void> _savePage(Page page) async {
    if (page.filePath == null) return;

    // Track modification
    _modifiedPages.add(page.name);

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
  Map<String, dynamic> getStatistics() {
    return graph.getStatistics();
  }

  /// Search for text across all pages
  Map<String, List<Block>> search(
    String query, {
    bool caseSensitive = false,
  }) {
    return graph.searchContent(query, caseSensitive: caseSensitive);
  }

  /// Export the graph to JSON format
  Future<void> exportToJson(String outputPath) async {
    final graphData = {
      'rootPath': graphPath,
      'config': graph.config,
      'pages': graph.pages.map((key, page) => MapEntry(key, page.toJson())),
      'statistics': graph.getStatistics(),
    };

    final file = File(outputPath);
    final encoder = const JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(graphData));
  }

  /// Reload the graph from disk
  Future<LogseqGraph> reloadGraph() {
    return loadGraph(forceReload: true);
  }

  /// Save all modified pages
  Future<int> saveAll() async {
    var savedCount = 0;
    for (final pageName in _modifiedPages) {
      final page = graph.getPage(pageName);
      if (page != null && page.filePath != null) {
        await _savePage(page);
        savedCount++;
      }
    }
    _modifiedPages.clear();
    return savedCount;
  }
}
