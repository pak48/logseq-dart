/// SQLite database layer for Logseq graph storage
library;

import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

/// Main database class for Logseq graph storage
class LogseqDatabase {
  static const int _databaseVersion = 1;
  static const String _databaseName = 'logseq.db';

  final String graphPath;
  Database? _database;

  LogseqDatabase(this.graphPath);

  /// Get the database instance, initializing if necessary
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize the database
  Future<Database> _initDatabase() async {
    // Initialize FFI for desktop platforms
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    // Create .logseq directory if it doesn't exist
    final logseqDir = Directory(p.join(graphPath, '.logseq'));
    if (!logseqDir.existsSync()) {
      logseqDir.createSync(recursive: true);
    }

    final dbPath = p.join(logseqDir.path, _databaseName);

    return await openDatabase(
      dbPath,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  /// Configure database settings
  Future<void> _onConfigure(Database db) async {
    // Enable foreign keys
    await db.execute('PRAGMA foreign_keys = ON');
    // Enable WAL mode for better concurrency
    await db.execute('PRAGMA journal_mode = WAL');
  }

  /// Create database schema
  Future<void> _onCreate(Database db, int version) async {
    await db.transaction((txn) async {
      // Pages table
      await txn.execute('''
        CREATE TABLE pages (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          title TEXT NOT NULL,
          file_path TEXT,
          is_journal INTEGER DEFAULT 0,
          journal_date TEXT,
          namespace TEXT,
          is_whiteboard INTEGER DEFAULT 0,
          is_template INTEGER DEFAULT 0,
          pdf_path TEXT,
          created_at TEXT,
          updated_at TEXT
        )
      ''');

      await txn.execute('CREATE INDEX idx_pages_name ON pages(name)');
      await txn.execute('CREATE INDEX idx_pages_journal ON pages(is_journal, journal_date)');
      await txn.execute('CREATE INDEX idx_pages_namespace ON pages(namespace)');

      // Blocks table
      await txn.execute('''
        CREATE TABLE blocks (
          id TEXT PRIMARY KEY,
          page_id INTEGER NOT NULL,
          content TEXT NOT NULL,
          level INTEGER DEFAULT 0,
          parent_id TEXT,
          task_state TEXT,
          priority TEXT,
          scheduled_date TEXT,
          scheduled_time TEXT,
          scheduled_repeater TEXT,
          deadline_date TEXT,
          deadline_time TEXT,
          deadline_repeater TEXT,
          block_type TEXT DEFAULT 'bullet',
          collapsed INTEGER DEFAULT 0,
          heading_level INTEGER,
          code_language TEXT,
          latex_content TEXT,
          created_at TEXT,
          updated_at TEXT,
          FOREIGN KEY (page_id) REFERENCES pages(id) ON DELETE CASCADE
        )
      ''');

      await txn.execute('CREATE INDEX idx_blocks_page ON blocks(page_id)');
      await txn.execute('CREATE INDEX idx_blocks_parent ON blocks(parent_id)');
      await txn.execute('CREATE INDEX idx_blocks_task ON blocks(task_state) WHERE task_state IS NOT NULL');
      await txn.execute('CREATE INDEX idx_blocks_scheduled ON blocks(scheduled_date) WHERE scheduled_date IS NOT NULL');
      await txn.execute('CREATE INDEX idx_blocks_deadline ON blocks(deadline_date) WHERE deadline_date IS NOT NULL');

      // Block children junction table
      await txn.execute('''
        CREATE TABLE block_children (
          parent_block_id TEXT NOT NULL,
          child_block_id TEXT NOT NULL,
          position INTEGER NOT NULL,
          PRIMARY KEY (parent_block_id, child_block_id),
          FOREIGN KEY (parent_block_id) REFERENCES blocks(id) ON DELETE CASCADE,
          FOREIGN KEY (child_block_id) REFERENCES blocks(id) ON DELETE CASCADE
        )
      ''');

      await txn.execute('CREATE INDEX idx_block_children_parent ON block_children(parent_block_id)');

      // Properties table
      await txn.execute('''
        CREATE TABLE properties (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          entity_type TEXT NOT NULL,
          entity_id TEXT NOT NULL,
          key TEXT NOT NULL,
          value TEXT NOT NULL,
          UNIQUE(entity_type, entity_id, key)
        )
      ''');

      await txn.execute('CREATE INDEX idx_properties_entity ON properties(entity_type, entity_id)');
      await txn.execute('CREATE INDEX idx_properties_key ON properties(key)');

      // Tags table
      await txn.execute('''
        CREATE TABLE tags (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          entity_type TEXT NOT NULL,
          entity_id TEXT NOT NULL,
          tag TEXT NOT NULL,
          UNIQUE(entity_type, entity_id, tag)
        )
      ''');

      await txn.execute('CREATE INDEX idx_tags_entity ON tags(entity_type, entity_id)');
      await txn.execute('CREATE INDEX idx_tags_tag ON tags(tag)');

      // Links table
      await txn.execute('''
        CREATE TABLE links (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          source_type TEXT NOT NULL,
          source_id TEXT NOT NULL,
          target_page TEXT NOT NULL,
          link_type TEXT DEFAULT 'reference',
          UNIQUE(source_type, source_id, target_page, link_type)
        )
      ''');

      await txn.execute('CREATE INDEX idx_links_source ON links(source_type, source_id)');
      await txn.execute('CREATE INDEX idx_links_target ON links(target_page)');

      // Aliases table
      await txn.execute('''
        CREATE TABLE aliases (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          page_id INTEGER NOT NULL,
          alias TEXT NOT NULL UNIQUE,
          FOREIGN KEY (page_id) REFERENCES pages(id) ON DELETE CASCADE
        )
      ''');

      await txn.execute('CREATE INDEX idx_aliases_page ON aliases(page_id)');

      // Templates table
      await txn.execute('''
        CREATE TABLE templates (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          page_id INTEGER NOT NULL,
          content TEXT NOT NULL,
          template_type TEXT DEFAULT 'page',
          variables TEXT,
          FOREIGN KEY (page_id) REFERENCES pages(id) ON DELETE CASCADE
        )
      ''');

      // Block references table
      await txn.execute('''
        CREATE TABLE block_references (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          source_block_id TEXT NOT NULL,
          referenced_block_id TEXT NOT NULL,
          UNIQUE(source_block_id, referenced_block_id),
          FOREIGN KEY (source_block_id) REFERENCES blocks(id) ON DELETE CASCADE
        )
      ''');

      await txn.execute('CREATE INDEX idx_block_refs_source ON block_references(source_block_id)');
      await txn.execute('CREATE INDEX idx_block_refs_target ON block_references(referenced_block_id)');

      // Queries table
      await txn.execute('''
        CREATE TABLE queries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          block_id TEXT NOT NULL UNIQUE,
          query_string TEXT NOT NULL,
          query_type TEXT NOT NULL,
          FOREIGN KEY (block_id) REFERENCES blocks(id) ON DELETE CASCADE
        )
      ''');

      // File sync state table
      await txn.execute('''
        CREATE TABLE file_sync_state (
          file_path TEXT PRIMARY KEY,
          last_modified TEXT NOT NULL,
          last_synced TEXT NOT NULL,
          checksum TEXT
        )
      ''');
    });
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future schema migrations will go here
  }

  /// Close the database
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  /// Execute a raw query
  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawQuery(sql, arguments);
  }

  /// Execute a raw insert/update/delete
  Future<int> rawExecute(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawUpdate(sql, arguments);
  }

  /// Begin a transaction
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return await db.transaction(action);
  }
}
