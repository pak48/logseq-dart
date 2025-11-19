/// Page repository for database operations
library;

import 'package:sqflite/sqflite.dart';
import '../database.dart';
import '../../models/page.dart';
import '../../models/block.dart';
import 'block_repository.dart';

/// Repository for page-related database operations
class PageRepository {
  final LogseqDatabase database;
  final BlockRepository blockRepository;

  PageRepository(this.database, this.blockRepository);

  /// Insert or update a page
  Future<int> savePage(Page page) async {
    final db = await database.database;

    return await db.transaction((txn) async {
      // Insert or replace page
      final pageId = await txn.insert(
        'pages',
        {
          'name': page.name,
          'title': page.title,
          'file_path': page.filePath,
          'is_journal': page.isJournal ? 1 : 0,
          'journal_date': page.journalDate?.toIso8601String(),
          'namespace': page.namespace,
          'is_whiteboard': page.isWhiteboard ? 1 : 0,
          'is_template': page.isTemplate ? 1 : 0,
          'pdf_path': page.pdfPath,
          'created_at': (page.createdAt ?? DateTime.now()).toIso8601String(),
          'updated_at': (page.updatedAt ?? DateTime.now()).toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Delete existing properties, tags, links, aliases
      await txn.delete('properties', where: 'entity_type = ? AND entity_id = ?', whereArgs: ['page', page.name]);
      await txn.delete('tags', where: 'entity_type = ? AND entity_id = ?', whereArgs: ['page', page.name]);
      await txn.delete('links', where: 'source_type = ? AND source_id = ?', whereArgs: ['page', page.name]);
      await txn.delete('aliases', where: 'page_id = ?', whereArgs: [pageId]);

      // Insert properties
      for (final entry in page.properties.entries) {
        await txn.insert('properties', {
          'entity_type': 'page',
          'entity_id': page.name,
          'key': entry.key,
          'value': entry.value.toString(),
        });
      }

      // Insert tags
      for (final tag in page.tags) {
        await txn.insert('tags', {
          'entity_type': 'page',
          'entity_id': page.name,
          'tag': tag,
        });
      }

      // Insert links
      for (final link in page.links) {
        await txn.insert('links', {
          'source_type': 'page',
          'source_id': page.name,
          'target_page': link,
          'link_type': 'reference',
        });
      }

      // Insert aliases
      for (final alias in page.aliases) {
        await txn.insert('aliases', {
          'page_id': pageId,
          'alias': alias,
        });
      }

      // Save blocks
      for (final block in page.blocks) {
        await blockRepository.saveBlockInTransaction(txn, block, pageId);
      }

      return pageId;
    });
  }

  /// Get a page by name
  Future<Page?> getPage(String name) async {
    final db = await database.database;

    final results = await db.query(
      'pages',
      where: 'name = ?',
      whereArgs: [name],
    );

    if (results.isEmpty) return null;

    return await _pageFromRow(results.first);
  }

  /// Get a page by ID
  Future<Page?> getPageById(int pageId) async {
    final db = await database.database;

    final results = await db.query(
      'pages',
      where: 'id = ?',
      whereArgs: [pageId],
    );

    if (results.isEmpty) return null;

    return await _pageFromRow(results.first);
  }

  /// Get all pages
  Future<List<Page>> getAllPages({int? limit, int? offset}) async {
    final db = await database.database;

    final results = await db.query(
      'pages',
      orderBy: 'name ASC',
      limit: limit,
      offset: offset,
    );

    final pages = <Page>[];
    for (final row in results) {
      final page = await _pageFromRow(row);
      if (page != null) pages.add(page);
    }

    return pages;
  }

  /// Get journal pages
  Future<List<Page>> getJournalPages({int? limit, int? offset}) async {
    final db = await database.database;

    final results = await db.query(
      'pages',
      where: 'is_journal = 1',
      orderBy: 'journal_date DESC',
      limit: limit,
      offset: offset,
    );

    final pages = <Page>[];
    for (final row in results) {
      final page = await _pageFromRow(row);
      if (page != null) pages.add(page);
    }

    return pages;
  }

  /// Get pages by namespace
  Future<List<Page>> getPagesByNamespace(String namespace) async {
    final db = await database.database;

    final results = await db.query(
      'pages',
      where: 'namespace = ?',
      whereArgs: [namespace],
      orderBy: 'name ASC',
    );

    final pages = <Page>[];
    for (final row in results) {
      final page = await _pageFromRow(row);
      if (page != null) pages.add(page);
    }

    return pages;
  }

  /// Get pages by tag
  Future<List<Page>> getPagesByTag(String tag) async {
    final db = await database.database;

    final results = await db.rawQuery('''
      SELECT p.* FROM pages p
      INNER JOIN tags t ON t.entity_id = p.name
      WHERE t.entity_type = 'page' AND t.tag = ?
      ORDER BY p.name ASC
    ''', [tag]);

    final pages = <Page>[];
    for (final row in results) {
      final page = await _pageFromRow(row);
      if (page != null) pages.add(page);
    }

    return pages;
  }

  /// Search pages by content
  Future<List<Page>> searchPages(String query, {bool caseSensitive = false}) async {
    final db = await database.database;

    final searchQuery = caseSensitive ? query : query.toLowerCase();
    final contentCondition = caseSensitive
        ? 'b.content LIKE ?'
        : 'LOWER(b.content) LIKE ?';

    final results = await db.rawQuery('''
      SELECT DISTINCT p.* FROM pages p
      INNER JOIN blocks b ON b.page_id = p.id
      WHERE $contentCondition OR p.name LIKE ? OR p.title LIKE ?
      ORDER BY p.name ASC
    ''', ['%$searchQuery%', '%$searchQuery%', '%$searchQuery%']);

    final pages = <Page>[];
    for (final row in results) {
      final page = await _pageFromRow(row);
      if (page != null) pages.add(page);
    }

    return pages;
  }

  /// Delete a page
  Future<bool> deletePage(String name) async {
    final db = await database.database;

    final count = await db.delete(
      'pages',
      where: 'name = ?',
      whereArgs: [name],
    );

    return count > 0;
  }

  /// Get page by alias
  Future<Page?> getPageByAlias(String alias) async {
    final db = await database.database;

    final results = await db.rawQuery('''
      SELECT p.* FROM pages p
      INNER JOIN aliases a ON a.page_id = p.id
      WHERE a.alias = ?
    ''', [alias]);

    if (results.isEmpty) return null;

    return await _pageFromRow(results.first);
  }

  /// Get page count
  Future<int> getPageCount() async {
    final db = await database.database;

    final result = await db.rawQuery('SELECT COUNT(*) as count FROM pages');
    return result.first['count'] as int;
  }

  /// Convert database row to Page object
  Future<Page?> _pageFromRow(Map<String, dynamic> row) async {
    final db = await database.database;
    final pageName = row['name'] as String;
    final pageId = row['id'] as int;

    // Get properties
    final props = await db.query(
      'properties',
      where: 'entity_type = ? AND entity_id = ?',
      whereArgs: ['page', pageName],
    );
    final properties = <String, dynamic>{};
    for (final prop in props) {
      properties[prop['key'] as String] = prop['value'];
    }

    // Get tags
    final tagRows = await db.query(
      'tags',
      where: 'entity_type = ? AND entity_id = ?',
      whereArgs: ['page', pageName],
    );
    final tags = tagRows.map((t) => t['tag'] as String).toSet();

    // Get links
    final linkRows = await db.query(
      'links',
      where: 'source_type = ? AND source_id = ?',
      whereArgs: ['page', pageName],
    );
    final links = linkRows.map((l) => l['target_page'] as String).toSet();

    // Get backlinks
    final backlinkRows = await db.query(
      'links',
      where: 'target_page = ?',
      whereArgs: [pageName],
    );
    final backlinks = backlinkRows.map((l) => l['source_id'] as String).toSet();

    // Get aliases
    final aliasRows = await db.query(
      'aliases',
      where: 'page_id = ?',
      whereArgs: [pageId],
    );
    final aliases = aliasRows.map((a) => a['alias'] as String).toSet();

    // Get blocks for this page
    final blocks = await blockRepository.getBlocksByPageId(pageId);

    return Page(
      name: pageName,
      title: row['title'] as String,
      filePath: row['file_path'] as String?,
      blocks: blocks,
      properties: properties,
      tags: tags,
      links: links,
      backlinks: backlinks,
      isJournal: (row['is_journal'] as int) == 1,
      journalDate: row['journal_date'] != null
          ? DateTime.parse(row['journal_date'] as String)
          : null,
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : null,
      updatedAt: row['updated_at'] != null
          ? DateTime.parse(row['updated_at'] as String)
          : null,
      namespace: row['namespace'] as String?,
      isWhiteboard: (row['is_whiteboard'] as int) == 1,
      isTemplate: (row['is_template'] as int) == 1,
      pdfPath: row['pdf_path'] as String?,
      aliases: aliases,
    );
  }
}
