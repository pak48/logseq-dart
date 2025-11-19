/// Block repository for database operations
library;

import 'package:sqflite/sqflite.dart';
import '../database.dart';
import '../../models/block.dart';
import '../../models/enums.dart';
import '../../models/advanced_models.dart';

/// Repository for block-related database operations
class BlockRepository {
  final LogseqDatabase database;

  BlockRepository(this.database);

  /// Save a block (called within a transaction)
  Future<void> saveBlockInTransaction(
    Transaction txn,
    Block block,
    int pageId,
  ) async {
    // Insert or replace block
    await txn.insert(
      'blocks',
      {
        'id': block.id,
        'page_id': pageId,
        'content': block.content,
        'level': block.level,
        'parent_id': block.parentId,
        'task_state': block.taskState?.value,
        'priority': block.priority?.value,
        'scheduled_date': block.scheduled?.date.toIso8601String(),
        'scheduled_time': block.scheduled?.time,
        'scheduled_repeater': block.scheduled?.repeater,
        'deadline_date': block.deadline?.date.toIso8601String(),
        'deadline_time': block.deadline?.time,
        'deadline_repeater': block.deadline?.repeater,
        'block_type': block.blockType.value,
        'collapsed': block.collapsed ? 1 : 0,
        'heading_level': block.headingLevel,
        'code_language': block.codeLanguage,
        'latex_content': block.latexContent,
        'created_at': (block.createdAt ?? DateTime.now()).toIso8601String(),
        'updated_at': (block.updatedAt ?? DateTime.now()).toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Delete existing properties, tags, links
    await txn.delete('properties', where: 'entity_type = ? AND entity_id = ?', whereArgs: ['block', block.id]);
    await txn.delete('tags', where: 'entity_type = ? AND entity_id = ?', whereArgs: ['block', block.id]);
    await txn.delete('links', where: 'source_type = ? AND source_id = ?', whereArgs: ['block', block.id]);
    await txn.delete('block_children', where: 'parent_block_id = ?', whereArgs: [block.id]);
    await txn.delete('block_references', where: 'source_block_id = ?', whereArgs: [block.id]);

    // Insert properties
    for (final entry in block.properties.entries) {
      await txn.insert('properties', {
        'entity_type': 'block',
        'entity_id': block.id,
        'key': entry.key,
        'value': entry.value.toString(),
      });
    }

    // Insert tags
    for (final tag in block.tags) {
      await txn.insert('tags', {
        'entity_type': 'block',
        'entity_id': block.id,
        'tag': tag,
      });
    }

    // Insert links
    for (final link in block.getLinks()) {
      await txn.insert('links', {
        'source_type': 'block',
        'source_id': block.id,
        'target_page': link,
        'link_type': 'reference',
      });
    }

    // Insert children relationships
    for (int i = 0; i < block.childrenIds.length; i++) {
      await txn.insert('block_children', {
        'parent_block_id': block.id,
        'child_block_id': block.childrenIds[i],
        'position': i,
      });
    }

    // Insert block references
    for (final refId in block.referencedBlocks) {
      await txn.insert('block_references', {
        'source_block_id': block.id,
        'referenced_block_id': refId,
      });
    }

    // Insert query if exists
    if (block.query != null) {
      await txn.insert('queries', {
        'block_id': block.id,
        'query_string': block.query!.queryString,
        'query_type': block.query!.queryType,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  /// Get blocks by page ID
  Future<List<Block>> getBlocksByPageId(int pageId) async {
    final db = await database.database;

    final results = await db.query(
      'blocks',
      where: 'page_id = ?',
      whereArgs: [pageId],
      orderBy: 'created_at ASC',
    );

    final blocks = <Block>[];
    for (final row in results) {
      final block = await _blockFromRow(row);
      if (block != null) blocks.add(block);
    }

    return blocks;
  }

  /// Get a block by ID
  Future<Block?> getBlock(String blockId) async {
    final db = await database.database;

    final results = await db.query(
      'blocks',
      where: 'id = ?',
      whereArgs: [blockId],
    );

    if (results.isEmpty) return null;

    return await _blockFromRow(results.first);
  }

  /// Get blocks by task state
  Future<List<Block>> getBlocksByTaskState(TaskState state) async {
    final db = await database.database;

    final results = await db.query(
      'blocks',
      where: 'task_state = ?',
      whereArgs: [state.value],
    );

    final blocks = <Block>[];
    for (final row in results) {
      final block = await _blockFromRow(row);
      if (block != null) blocks.add(block);
    }

    return blocks;
  }

  /// Get scheduled blocks
  Future<List<Block>> getScheduledBlocks({DateTime? date}) async {
    final db = await database.database;

    String? whereClause = 'scheduled_date IS NOT NULL';
    List<dynamic>? whereArgs;

    if (date != null) {
      final dateStr = date.toIso8601String().split('T')[0];
      whereClause = 'scheduled_date LIKE ?';
      whereArgs = ['$dateStr%'];
    }

    final results = await db.query(
      'blocks',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'scheduled_date ASC',
    );

    final blocks = <Block>[];
    for (final row in results) {
      final block = await _blockFromRow(row);
      if (block != null) blocks.add(block);
    }

    return blocks;
  }

  /// Get blocks with deadline
  Future<List<Block>> getBlocksWithDeadline({DateTime? date}) async {
    final db = await database.database;

    String? whereClause = 'deadline_date IS NOT NULL';
    List<dynamic>? whereArgs;

    if (date != null) {
      final dateStr = date.toIso8601String().split('T')[0];
      whereClause = 'deadline_date LIKE ?';
      whereArgs = ['$dateStr%'];
    }

    final results = await db.query(
      'blocks',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'deadline_date ASC',
    );

    final blocks = <Block>[];
    for (final row in results) {
      final block = await _blockFromRow(row);
      if (block != null) blocks.add(block);
    }

    return blocks;
  }

  /// Get blocks by priority
  Future<List<Block>> getBlocksByPriority(Priority priority) async {
    final db = await database.database;

    final results = await db.query(
      'blocks',
      where: 'priority = ?',
      whereArgs: [priority.value],
    );

    final blocks = <Block>[];
    for (final row in results) {
      final block = await _blockFromRow(row);
      if (block != null) blocks.add(block);
    }

    return blocks;
  }

  /// Search blocks by content
  Future<List<Block>> searchBlocks(String query, {bool caseSensitive = false}) async {
    final db = await database.database;

    final searchQuery = caseSensitive ? query : query.toLowerCase();
    final condition = caseSensitive ? 'content LIKE ?' : 'LOWER(content) LIKE ?';

    final results = await db.query(
      'blocks',
      where: condition,
      whereArgs: ['%$searchQuery%'],
    );

    final blocks = <Block>[];
    for (final row in results) {
      final block = await _blockFromRow(row);
      if (block != null) blocks.add(block);
    }

    return blocks;
  }

  /// Get all task blocks
  Future<List<Block>> getTaskBlocks() async {
    final db = await database.database;

    final results = await db.query(
      'blocks',
      where: 'task_state IS NOT NULL',
    );

    final blocks = <Block>[];
    for (final row in results) {
      final block = await _blockFromRow(row);
      if (block != null) blocks.add(block);
    }

    return blocks;
  }

  /// Delete a block
  Future<bool> deleteBlock(String blockId) async {
    final db = await database.database;

    final count = await db.delete(
      'blocks',
      where: 'id = ?',
      whereArgs: [blockId],
    );

    return count > 0;
  }

  /// Convert database row to Block object
  Future<Block?> _blockFromRow(Map<String, dynamic> row) async {
    final db = await database.database;
    final blockId = row['id'] as String;

    // Get properties
    final props = await db.query(
      'properties',
      where: 'entity_type = ? AND entity_id = ?',
      whereArgs: ['block', blockId],
    );
    final properties = <String, dynamic>{};
    for (final prop in props) {
      properties[prop['key'] as String] = prop['value'];
    }

    // Get tags
    final tagRows = await db.query(
      'tags',
      where: 'entity_type = ? AND entity_id = ?',
      whereArgs: ['block', blockId],
    );
    final tags = tagRows.map((t) => t['tag'] as String).toSet();

    // Get children IDs
    final childrenRows = await db.query(
      'block_children',
      where: 'parent_block_id = ?',
      whereArgs: [blockId],
      orderBy: 'position ASC',
    );
    final childrenIds = childrenRows.map((c) => c['child_block_id'] as String).toList();

    // Get referenced blocks
    final refRows = await db.query(
      'block_references',
      where: 'source_block_id = ?',
      whereArgs: [blockId],
    );
    final referencedBlocks = refRows.map((r) => r['referenced_block_id'] as String).toSet();

    // Get query if exists
    LogseqQuery? query;
    final queryRows = await db.query(
      'queries',
      where: 'block_id = ?',
      whereArgs: [blockId],
    );
    if (queryRows.isNotEmpty) {
      query = LogseqQuery(
        queryString: queryRows.first['query_string'] as String,
        queryType: queryRows.first['query_type'] as String,
      );
    }

    // Parse scheduled date
    ScheduledDate? scheduled;
    if (row['scheduled_date'] != null) {
      scheduled = ScheduledDate(
        date: DateTime.parse(row['scheduled_date'] as String),
        time: row['scheduled_time'] as String?,
        repeater: row['scheduled_repeater'] as String?,
      );
    }

    // Parse deadline date
    ScheduledDate? deadline;
    if (row['deadline_date'] != null) {
      deadline = ScheduledDate(
        date: DateTime.parse(row['deadline_date'] as String),
        time: row['deadline_time'] as String?,
        repeater: row['deadline_repeater'] as String?,
      );
    }

    // Get page name
    final pageRows = await db.query(
      'pages',
      columns: ['name'],
      where: 'id = ?',
      whereArgs: [row['page_id']],
    );
    final pageName = pageRows.isNotEmpty ? pageRows.first['name'] as String? : null;

    return Block(
      id: blockId,
      content: row['content'] as String,
      level: row['level'] as int,
      parentId: row['parent_id'] as String?,
      childrenIds: childrenIds,
      properties: properties,
      tags: tags,
      pageName: pageName,
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : null,
      updatedAt: row['updated_at'] != null
          ? DateTime.parse(row['updated_at'] as String)
          : null,
      taskState: row['task_state'] != null
          ? TaskState.fromString(row['task_state'] as String)
          : null,
      priority: row['priority'] != null
          ? Priority.fromString(row['priority'] as String)
          : null,
      scheduled: scheduled,
      deadline: deadline,
      blockType: BlockType.fromString(row['block_type'] as String) ?? BlockType.bullet,
      collapsed: (row['collapsed'] as int) == 1,
      headingLevel: row['heading_level'] as int?,
      codeLanguage: row['code_language'] as String?,
      latexContent: row['latex_content'] as String?,
      referencedBlocks: referencedBlocks,
      query: query,
    );
  }
}
