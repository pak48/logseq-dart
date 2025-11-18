/// Graph model for Logseq
library;

import 'package:equatable/equatable.dart';
import 'block.dart';
import 'page.dart';
import 'enums.dart';
import 'advanced_models.dart';

/// Represents the entire Logseq graph
class LogseqGraph extends Equatable {
  final String rootPath;
  final Map<String, Page> pages;
  final Map<String, Block> blocks;
  final Map<String, dynamic> config;

  // Advanced features
  final Map<String, Template> templates;
  final Map<String, List<String>> namespaces; // namespace -> page names
  final Map<String, Page> whiteboards;

  // Plugin and theme data
  final Map<String, Map<String, dynamic>> plugins;
  final Map<String, Map<String, dynamic>> themes;
  String? customCss;

  // Index for fast lookups
  final Map<String, String> aliasIndex; // alias -> page_name
  final Map<String, Set<String>> tagIndex; // tag -> page_names

  LogseqGraph({
    required this.rootPath,
    Map<String, Page>? pages,
    Map<String, Block>? blocks,
    Map<String, dynamic>? config,
    Map<String, Template>? templates,
    Map<String, List<String>>? namespaces,
    Map<String, Page>? whiteboards,
    Map<String, Map<String, dynamic>>? plugins,
    Map<String, Map<String, dynamic>>? themes,
    this.customCss,
    Map<String, String>? aliasIndex,
    Map<String, Set<String>>? tagIndex,
  })  : pages = pages ?? {},
        blocks = blocks ?? {},
        config = config ?? {},
        templates = templates ?? {},
        namespaces = namespaces ?? {},
        whiteboards = whiteboards ?? {},
        plugins = plugins ?? {},
        themes = themes ?? {},
        aliasIndex = aliasIndex ?? {},
        tagIndex = tagIndex ?? {};

  @override
  List<Object?> get props => [
        rootPath,
        pages,
        blocks,
        config,
        templates,
        namespaces,
        whiteboards,
        plugins,
        themes,
        customCss,
        aliasIndex,
        tagIndex,
      ];

  /// Add a page to the graph
  void addPage(Page page) {
    pages[page.name] = page;

    // Add all blocks to the blocks index
    for (final block in page.blocks) {
      blocks[block.id] = block;
    }

    // Update advanced indexes
    _updateIndexesForPage(page);
  }

  /// Get a page by name
  Page? getPage(String name) => pages[name];

  /// Get a block by ID
  Block? getBlock(String blockId) => blocks[blockId];

  /// Find pages containing a specific tag
  List<Page> getPagesByTag(String tag) {
    return pages.values.where((page) => page.tags.contains(tag)).toList();
  }

  /// Get all journal pages sorted by date
  List<Page> getJournalPages() {
    final journalPages =
        pages.values.where((page) => page.isJournal).toList();
    journalPages.sort((a, b) {
      if (a.journalDate == null) return 1;
      if (b.journalDate == null) return -1;
      return a.journalDate!.compareTo(b.journalDate!);
    });
    return journalPages;
  }

  /// Search for text across all pages
  Map<String, List<Block>> searchContent(String searchText,
      {bool caseSensitive = false}) {
    final results = <String, List<Block>>{};

    for (final entry in pages.entries) {
      final matchingBlocks =
          entry.value.getBlocksByContent(searchText, caseSensitive: caseSensitive);
      if (matchingBlocks.isNotEmpty) {
        results[entry.key] = matchingBlocks;
      }
    }

    return results;
  }

  /// Get all pages that link to the specified page
  Set<String> getBacklinks(String pageName) {
    final backlinks = <String>{};

    for (final page in pages.values) {
      if (page.links.contains(pageName)) {
        backlinks.add(page.name);
      }
    }

    return backlinks;
  }

  /// Get graph statistics
  Map<String, dynamic> getStatistics() {
    final totalBlocks = blocks.length;
    final totalPages = pages.length;
    final journalPages = pages.values.where((p) => p.isJournal).length;
    final regularPages = totalPages - journalPages;

    final allTags = <String>{};
    final allLinks = <String>{};

    for (final page in pages.values) {
      allTags.addAll(page.tags);
      allLinks.addAll(page.links);
    }

    return {
      'totalPages': totalPages,
      'regularPages': regularPages,
      'journalPages': journalPages,
      'totalBlocks': totalBlocks,
      'totalTags': allTags.length,
      'totalLinks': allLinks.length,
      'uniqueTags': allTags.toList()..sort(),
      'uniqueLinks': allLinks.toList()..sort(),
      'templates': templates.length,
      'namespaces': namespaces.length,
      'whiteboards': whiteboards.length,
      'taskBlocks': blocks.values.where((b) => b.isTask()).length,
      'completedTasks': blocks.values.where((b) => b.isCompletedTask()).length,
      'scheduledBlocks': blocks.values.where((b) => b.isScheduled()).length,
      'codeBlocks':
          blocks.values.where((b) => b.blockType == BlockType.code).length,
      'queryBlocks': blocks.values.where((b) => b.query != null).length,
    };
  }

  /// Update various indexes when a page is added
  void _updateIndexesForPage(Page page) {
    // Update namespace index
    if (page.namespace != null) {
      namespaces.putIfAbsent(page.namespace!, () => []);
      namespaces[page.namespace!]!.add(page.name);
    }

    // Update alias index
    for (final alias in page.aliases) {
      aliasIndex[alias] = page.name;
    }

    // Update tag index
    for (final tag in page.tags) {
      tagIndex.putIfAbsent(tag, () => {});
      tagIndex[tag]!.add(page.name);
    }

    // Update templates index
    for (final template in page.templates) {
      templates[template.name] = template;
    }

    // Update whiteboards index
    if (page.isWhiteboard) {
      whiteboards[page.name] = page;
    }
  }

  /// Get a page by its alias
  Page? getPageByAlias(String alias) {
    if (aliasIndex.containsKey(alias)) {
      final pageName = aliasIndex[alias]!;
      return pages[pageName];
    }
    return null;
  }

  /// Get all pages in a namespace
  List<Page> getPagesByNamespace(String namespace) {
    if (namespaces.containsKey(namespace)) {
      return namespaces[namespace]!
          .map((name) => pages[name])
          .whereType<Page>()
          .toList();
    }
    return [];
  }

  /// Get all namespaces in the graph
  List<String> getAllNamespaces() => namespaces.keys.toList();

  /// Get a template by name
  Template? getTemplate(String name) => templates[name];

  /// Get all templates in the graph
  List<Template> getAllTemplates() => templates.values.toList();

  /// Get all whiteboard pages
  List<Page> getWhiteboards() => whiteboards.values.toList();

  /// Get all task blocks in the graph
  List<Block> getTaskBlocks() =>
      blocks.values.where((block) => block.isTask()).toList();

  /// Get all completed task blocks
  List<Block> getCompletedTasks() =>
      blocks.values.where((block) => block.isCompletedTask()).toList();

  /// Get scheduled blocks, optionally filtered by date
  List<Block> getScheduledBlocks({DateTime? dateFilter}) {
    var scheduled = blocks.values.where((block) => block.isScheduled()).toList();
    if (dateFilter != null) {
      return scheduled
          .where((block) =>
              block.scheduled != null &&
              isSameDay(block.scheduled!.date, dateFilter))
          .toList();
    }
    return scheduled;
  }

  /// Get blocks with deadlines, optionally filtered by date
  List<Block> getBlocksWithDeadline({DateTime? dateFilter}) {
    var deadlineBlocks =
        blocks.values.where((block) => block.hasDeadline()).toList();
    if (dateFilter != null) {
      return deadlineBlocks
          .where((block) =>
              block.deadline != null &&
              isSameDay(block.deadline!.date, dateFilter))
          .toList();
    }
    return deadlineBlocks;
  }

  /// Get blocks with specific priority
  List<Block> getBlocksByPriority(Priority priority) {
    return blocks.values.where((block) => block.priority == priority).toList();
  }

  /// Get all query blocks in the graph
  List<Block> getQueryBlocks() =>
      blocks.values.where((block) => block.query != null).toList();

  /// Get code blocks, optionally filtered by language
  List<Block> getCodeBlocks({String? language}) {
    var codeBlocks =
        blocks.values.where((block) => block.blockType == BlockType.code).toList();
    if (language != null) {
      return codeBlocks
          .where((block) => block.codeLanguage == language)
          .toList();
    }
    return codeBlocks;
  }

  /// Get all blocks containing LaTeX/math content
  List<Block> getMathBlocks() =>
      blocks.values.where((block) => block.latexContent != null).toList();

  /// Search blocks by task state
  List<Block> searchBlocksByTaskState(TaskState state) {
    return blocks.values.where((block) => block.taskState == state).toList();
  }

  /// Get a summary of workflow/task information
  Map<String, dynamic> getWorkflowSummary() {
    final taskBlocks = getTaskBlocks();

    // Count by state
    final stateCounts = <String, int>{};
    for (final state in TaskState.values) {
      stateCounts[state.value] =
          taskBlocks.where((b) => b.taskState == state).length;
    }

    // Count by priority
    final priorityCounts = <String, int>{};
    for (final priority in Priority.values) {
      priorityCounts[priority.value] =
          taskBlocks.where((b) => b.priority == priority).length;
    }

    return {
      'totalTasks': taskBlocks.length,
      'taskStates': stateCounts,
      'taskPriorities': priorityCounts,
      'scheduledTasks': taskBlocks.where((b) => b.isScheduled()).length,
      'tasksWithDeadline': taskBlocks.where((b) => b.hasDeadline()).length,
    };
  }

  /// Get comprehensive graph insights
  Map<String, dynamic> getGraphInsights() {
    final insights = getStatistics();
    insights['workflow'] = getWorkflowSummary();

    // Most connected pages (by backlinks)
    final pageConnections = pages.entries
        .map((e) => MapEntry(e.key, e.value.backlinks.length))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    insights['mostConnectedPages'] =
        pageConnections.take(10).map((e) => [e.key, e.value]).toList();

    // Most used tags
    final tagUsage = tagIndex.entries
        .map((e) => MapEntry(e.key, e.value.length))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    insights['mostUsedTags'] =
        tagUsage.take(20).map((e) => [e.key, e.value]).toList();

    return insights;
  }

  /// Helper to check if two dates are the same day
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
