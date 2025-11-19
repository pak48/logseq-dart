/// Graph repository for graph-level operations
library;

import '../database.dart';
import 'page_repository.dart';
import 'block_repository.dart';
import '../../models/enums.dart';

/// Repository for graph-level queries and statistics
class GraphRepository {
  final LogseqDatabase database;
  final PageRepository pageRepository;
  final BlockRepository blockRepository;

  GraphRepository(
    this.database,
    this.pageRepository,
    this.blockRepository,
  );

  /// Get graph statistics
  Future<Map<String, dynamic>> getStatistics() async {
    final db = await database.database;

    // Get counts
    final pageCount = await db.rawQuery('SELECT COUNT(*) as count FROM pages');
    final totalPages = pageCount.first['count'] as int;

    final journalCount = await db.rawQuery('SELECT COUNT(*) as count FROM pages WHERE is_journal = 1');
    final journalPages = journalCount.first['count'] as int;

    final blockCount = await db.rawQuery('SELECT COUNT(*) as count FROM blocks');
    final totalBlocks = blockCount.first['count'] as int;

    final taskCount = await db.rawQuery('SELECT COUNT(*) as count FROM blocks WHERE task_state IS NOT NULL');
    final taskBlocks = taskCount.first['count'] as int;

    final completedCount = await db.rawQuery('SELECT COUNT(*) as count FROM blocks WHERE task_state = ?', [TaskState.done.value]);
    final completedTasks = completedCount.first['count'] as int;

    final scheduledCount = await db.rawQuery('SELECT COUNT(*) as count FROM blocks WHERE scheduled_date IS NOT NULL');
    final scheduledBlocks = scheduledCount.first['count'] as int;

    final codeCount = await db.rawQuery('SELECT COUNT(*) as count FROM blocks WHERE block_type = ?', [BlockType.code.value]);
    final codeBlocks = codeCount.first['count'] as int;

    final queryCount = await db.rawQuery('SELECT COUNT(*) as count FROM queries');
    final queryBlocks = queryCount.first['count'] as int;

    // Get unique tags
    final tagRows = await db.rawQuery('SELECT DISTINCT tag FROM tags ORDER BY tag');
    final uniqueTags = tagRows.map((row) => row['tag'] as String).toList();

    // Get unique links
    final linkRows = await db.rawQuery('SELECT DISTINCT target_page FROM links ORDER BY target_page');
    final uniqueLinks = linkRows.map((row) => row['target_page'] as String).toList();

    // Get template count
    final templateCount = await db.rawQuery('SELECT COUNT(*) as count FROM templates');
    final templates = templateCount.first['count'] as int;

    // Get whiteboard count
    final whiteboardCount = await db.rawQuery('SELECT COUNT(*) as count FROM pages WHERE is_whiteboard = 1');
    final whiteboards = whiteboardCount.first['count'] as int;

    // Get namespace count
    final namespaceRows = await db.rawQuery('SELECT DISTINCT namespace FROM pages WHERE namespace IS NOT NULL');
    final namespaces = namespaceRows.length;

    return {
      'totalPages': totalPages,
      'regularPages': totalPages - journalPages,
      'journalPages': journalPages,
      'totalBlocks': totalBlocks,
      'totalTags': uniqueTags.length,
      'totalLinks': uniqueLinks.length,
      'uniqueTags': uniqueTags,
      'uniqueLinks': uniqueLinks,
      'templates': templates,
      'namespaces': namespaces,
      'whiteboards': whiteboards,
      'taskBlocks': taskBlocks,
      'completedTasks': completedTasks,
      'scheduledBlocks': scheduledBlocks,
      'codeBlocks': codeBlocks,
      'queryBlocks': queryBlocks,
    };
  }

  /// Get workflow summary
  Future<Map<String, dynamic>> getWorkflowSummary() async {
    final db = await database.database;

    // Count by state
    final stateCounts = <String, int>{};
    for (final state in TaskState.values) {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM blocks WHERE task_state = ?',
        [state.value],
      );
      stateCounts[state.value] = result.first['count'] as int;
    }

    // Count by priority
    final priorityCounts = <String, int>{};
    for (final priority in Priority.values) {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM blocks WHERE priority = ? AND task_state IS NOT NULL',
        [priority.value],
      );
      priorityCounts[priority.value] = result.first['count'] as int;
    }

    final taskCount = await db.rawQuery('SELECT COUNT(*) as count FROM blocks WHERE task_state IS NOT NULL');
    final totalTasks = taskCount.first['count'] as int;

    final scheduledCount = await db.rawQuery('SELECT COUNT(*) as count FROM blocks WHERE task_state IS NOT NULL AND scheduled_date IS NOT NULL');
    final scheduledTasks = scheduledCount.first['count'] as int;

    final deadlineCount = await db.rawQuery('SELECT COUNT(*) as count FROM blocks WHERE task_state IS NOT NULL AND deadline_date IS NOT NULL');
    final tasksWithDeadline = deadlineCount.first['count'] as int;

    return {
      'totalTasks': totalTasks,
      'taskStates': stateCounts,
      'taskPriorities': priorityCounts,
      'scheduledTasks': scheduledTasks,
      'tasksWithDeadline': tasksWithDeadline,
    };
  }

  /// Get graph insights
  Future<Map<String, dynamic>> getGraphInsights() async {
    final insights = await getStatistics();
    insights['workflow'] = await getWorkflowSummary();

    final db = await database.database;

    // Most connected pages (by backlinks)
    final backlinkRows = await db.rawQuery('''
      SELECT target_page, COUNT(*) as count
      FROM links
      GROUP BY target_page
      ORDER BY count DESC
      LIMIT 10
    ''');
    insights['mostConnectedPages'] =
        backlinkRows.map((row) => [row['target_page'], row['count']]).toList();

    // Most used tags
    final tagRows = await db.rawQuery('''
      SELECT tag, COUNT(*) as count
      FROM tags
      GROUP BY tag
      ORDER BY count DESC
      LIMIT 20
    ''');
    insights['mostUsedTags'] =
        tagRows.map((row) => [row['tag'], row['count']]).toList();

    return insights;
  }

  /// Search for text across all pages and blocks
  Future<Map<String, List<String>>> searchContent(
    String query, {
    bool caseSensitive = false,
  }) async {
    final db = await database.database;

    final searchQuery = caseSensitive ? query : query.toLowerCase();
    final condition = caseSensitive ? 'b.content LIKE ?' : 'LOWER(b.content) LIKE ?';

    final results = await db.rawQuery('''
      SELECT p.name as page_name, b.id as block_id, b.content
      FROM blocks b
      INNER JOIN pages p ON p.id = b.page_id
      WHERE $condition
      ORDER BY p.name, b.created_at
    ''', ['%$searchQuery%']);

    final resultMap = <String, List<String>>{};
    for (final row in results) {
      final pageName = row['page_name'] as String;
      final blockId = row['block_id'] as String;

      if (!resultMap.containsKey(pageName)) {
        resultMap[pageName] = [];
      }
      resultMap[pageName]!.add(blockId);
    }

    return resultMap;
  }

  /// Get all namespaces
  Future<List<String>> getAllNamespaces() async {
    final db = await database.database;

    final results = await db.rawQuery('''
      SELECT DISTINCT namespace
      FROM pages
      WHERE namespace IS NOT NULL
      ORDER BY namespace
    ''');

    return results.map((row) => row['namespace'] as String).toList();
  }

  /// Get backlinks for a page
  Future<Set<String>> getBacklinks(String pageName) async {
    final db = await database.database;

    final results = await db.rawQuery('''
      SELECT DISTINCT source_id
      FROM links
      WHERE target_page = ?
    ''', [pageName]);

    return results.map((row) => row['source_id'] as String).toSet();
  }
}
