# Storage Architecture Design

## Overview

This document describes the database-backed storage architecture for logseq-dart. The architecture uses SQLite for persistent storage while maintaining automatic synchronization with markdown files, providing fast data access without holding the entire graph in memory.

## Architecture Principles

1. **SQLite as Source of Truth**: Database serves as the primary data store
2. **Automatic File Sync**: File system watcher maintains bi-directional sync with markdown files
3. **Lazy Loading**: Data loaded from database on-demand instead of keeping everything in memory
4. **API Compatibility**: Existing API remains unchanged for backward compatibility
5. **Write-Through**: Changes written to both DB and markdown files immediately

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     Application Layer                       │
│                      (LogseqClient)                         │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    Repository Layer                         │
│              (Database Access & Caching)                    │
│  - GraphRepository                                          │
│  - PageRepository                                           │
│  - BlockRepository                                          │
│  - LRU Cache for recently accessed items                   │
└────────┬─────────────────────────────────┬──────────────────┘
         │                                 │
         ▼                                 ▼
┌─────────────────────┐         ┌──────────────────────────┐
│   SQLite Database   │◄────────┤  File System Watcher    │
│   (logseq.db)       │         │  (Markdown Sync)        │
└─────────────────────┘         └────────┬─────────────────┘
         ▲                                │
         │                                ▼
         └────────────────────┬───────────────────────┐
                              │  Markdown Files      │
                              │  - pages/*.md        │
                              │  - journals/*.md     │
                              └──────────────────────┘
```

## Database Schema

### Core Tables

#### pages
```sql
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
);
CREATE INDEX idx_pages_name ON pages(name);
CREATE INDEX idx_pages_journal ON pages(is_journal, journal_date);
CREATE INDEX idx_pages_namespace ON pages(namespace);
```

#### blocks
```sql
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
);
CREATE INDEX idx_blocks_page ON blocks(page_id);
CREATE INDEX idx_blocks_parent ON blocks(parent_id);
CREATE INDEX idx_blocks_task ON blocks(task_state) WHERE task_state IS NOT NULL;
CREATE INDEX idx_blocks_scheduled ON blocks(scheduled_date) WHERE scheduled_date IS NOT NULL;
CREATE INDEX idx_blocks_deadline ON blocks(deadline_date) WHERE deadline_date IS NOT NULL;
CREATE INDEX idx_blocks_content_fts ON blocks(content);
```

#### block_children
```sql
CREATE TABLE block_children (
    parent_block_id TEXT NOT NULL,
    child_block_id TEXT NOT NULL,
    position INTEGER NOT NULL,
    PRIMARY KEY (parent_block_id, child_block_id),
    FOREIGN KEY (parent_block_id) REFERENCES blocks(id) ON DELETE CASCADE,
    FOREIGN KEY (child_block_id) REFERENCES blocks(id) ON DELETE CASCADE
);
CREATE INDEX idx_block_children_parent ON block_children(parent_block_id);
```

#### properties
```sql
CREATE TABLE properties (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    entity_type TEXT NOT NULL, -- 'page' or 'block'
    entity_id TEXT NOT NULL, -- page_id or block_id
    key TEXT NOT NULL,
    value TEXT NOT NULL,
    UNIQUE(entity_type, entity_id, key)
);
CREATE INDEX idx_properties_entity ON properties(entity_type, entity_id);
CREATE INDEX idx_properties_key ON properties(key);
```

#### tags
```sql
CREATE TABLE tags (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    entity_type TEXT NOT NULL, -- 'page' or 'block'
    entity_id TEXT NOT NULL, -- page_id or block_id
    tag TEXT NOT NULL,
    UNIQUE(entity_type, entity_id, tag)
);
CREATE INDEX idx_tags_entity ON tags(entity_type, entity_id);
CREATE INDEX idx_tags_tag ON tags(tag);
```

#### links
```sql
CREATE TABLE links (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_type TEXT NOT NULL, -- 'page' or 'block'
    source_id TEXT NOT NULL,
    target_page TEXT NOT NULL,
    link_type TEXT DEFAULT 'reference', -- 'reference' or 'embed'
    UNIQUE(source_type, source_id, target_page, link_type)
);
CREATE INDEX idx_links_source ON links(source_type, source_id);
CREATE INDEX idx_links_target ON links(target_page);
```

#### aliases
```sql
CREATE TABLE aliases (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    page_id INTEGER NOT NULL,
    alias TEXT NOT NULL UNIQUE,
    FOREIGN KEY (page_id) REFERENCES pages(id) ON DELETE CASCADE
);
CREATE INDEX idx_aliases_page ON aliases(page_id);
```

#### templates
```sql
CREATE TABLE templates (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    page_id INTEGER NOT NULL,
    content TEXT NOT NULL,
    template_type TEXT DEFAULT 'page',
    variables TEXT, -- JSON array
    FOREIGN KEY (page_id) REFERENCES pages(id) ON DELETE CASCADE
);
```

#### block_references
```sql
CREATE TABLE block_references (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_block_id TEXT NOT NULL,
    referenced_block_id TEXT NOT NULL,
    UNIQUE(source_block_id, referenced_block_id),
    FOREIGN KEY (source_block_id) REFERENCES blocks(id) ON DELETE CASCADE
);
CREATE INDEX idx_block_refs_source ON block_references(source_block_id);
CREATE INDEX idx_block_refs_target ON block_references(referenced_block_id);
```

#### queries
```sql
CREATE TABLE queries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    block_id TEXT NOT NULL UNIQUE,
    query_string TEXT NOT NULL,
    query_type TEXT NOT NULL, -- 'simple' or 'advanced'
    FOREIGN KEY (block_id) REFERENCES blocks(id) ON DELETE CASCADE
);
```

#### file_sync_state
```sql
CREATE TABLE file_sync_state (
    file_path TEXT PRIMARY KEY,
    last_modified TEXT NOT NULL,
    last_synced TEXT NOT NULL,
    checksum TEXT
);
```

## Component Architecture

### 1. Database Layer (`storage/database.dart`)

**LogseqDatabase** - Main database connection and schema management
- Initialize database connection
- Create and upgrade schema
- Transaction management
- Query execution

### 2. Repository Layer (`storage/repositories/`)

#### **GraphRepository**
- Get graph statistics
- Get graph insights
- Full-text search across graph
- Index management

#### **PageRepository**
- CRUD operations for pages
- Get pages by namespace, tag, type
- Get journal pages
- Lazy load page details

#### **BlockRepository**
- CRUD operations for blocks
- Get blocks by page, parent, task state
- Query scheduled/deadline blocks
- Full-text search in blocks

#### **PropertyRepository**
- Get/set properties for pages and blocks
- Query entities by property values

#### **TagRepository**
- Get/set tags for pages and blocks
- Get all entities with a tag

#### **LinkRepository**
- Create/remove links
- Get backlinks for a page
- Get forward links

### 3. File Sync Layer (`storage/file_watcher.dart`)

**FileWatcher** - Monitors markdown files and syncs with database
- Watch markdown directory for changes
- Detect file create/update/delete
- Parse changed files and update database
- Handle bidirectional sync (markdown ↔ database)
- Debounce rapid changes

### 4. Caching Layer (`storage/cache.dart`)

**LRUCache** - Least Recently Used cache for hot data
- Cache recently accessed pages
- Cache recently accessed blocks
- Configurable size limit
- Automatic eviction

### 5. Modified Client Layer (`client/logseq_client.dart`)

**LogseqClient** - Updated to use database storage
- Initialize database and file watcher
- Delegate operations to repositories
- Maintain same API surface
- Handle cache warming

## Data Flow

### Read Operation (e.g., `getPage()`)
```
1. Client calls getPage(name)
2. Check LRU cache → return if hit
3. PageRepository.getPage(name)
4. Query database for page
5. Lazy load blocks if needed
6. Add to cache
7. Return Page object
```

### Write Operation (e.g., `updateBlock()`)
```
1. Client calls updateBlock(id, content)
2. BlockRepository.updateBlock(id, content)
3. Start database transaction
   a. Update blocks table
   b. Update properties table
   c. Update tags table
   d. Update links table
4. Commit transaction
5. Generate markdown for parent page
6. Write markdown to file
7. Invalidate cache
8. File watcher detects change (ignores own writes)
```

### File Change (external edit)
```
1. File watcher detects markdown file change
2. Parse markdown file
3. Start database transaction
   a. Update/insert page
   b. Update/insert blocks
   c. Update properties, tags, links
4. Commit transaction
5. Invalidate cache for affected entities
6. Emit change event (optional)
```

## Memory Management

### Before (In-Memory)
- Entire graph loaded in memory
- Memory usage: O(n) where n = total blocks/pages
- Fast access but high memory for large graphs

### After (Database-Backed)
- Only cache stores recently accessed data
- Memory usage: O(k) where k = cache size (configurable)
- Fast access via indexes, minimal memory usage

### Cache Strategy
- LRU cache with configurable size (default: 100 pages, 1000 blocks)
- Cache warmup for common queries (journal pages, recent pages)
- Cache invalidation on writes
- Per-entity caching (pages and blocks cached separately)

## Migration Strategy

### Initialization
1. Check if database exists
2. If not, create schema
3. Scan markdown files
4. Parse and import into database
5. Start file watcher

### Existing Graph
```dart
// First time initialization
final client = LogseqClient('/path/to/graph');
await client.initialize(); // Scans markdown files → populates DB

// Subsequent uses
final client = LogseqClient('/path/to/graph');
await client.initialize(); // Fast - just opens DB connection
```

## Performance Considerations

### Indexes
- All foreign keys indexed
- Common query patterns indexed
- Full-text search index on block content
- Composite indexes for multi-column queries

### Transactions
- Batch operations in transactions
- Write operations atomic
- Read operations use read-only transactions

### Query Optimization
- Lazy loading for large collections
- Pagination support for queries
- Efficient backlink calculation
- Prepared statements for common queries

## API Compatibility

All existing APIs remain unchanged:

```dart
// These continue to work identically
final page = client.getPage('My Page');
final block = client.getBlock('block-id');
final results = client.search('query');
await client.createPage('New Page', content: 'Hello');
await client.updateBlock('block-id', 'New content');
```

Under the hood:
- Queries hit database instead of in-memory structures
- Results cached for performance
- Same return types and behaviors

## Configuration

```dart
class LogseqClientConfig {
  // Cache configuration
  int maxCachedPages = 100;
  int maxCachedBlocks = 1000;

  // File watcher configuration
  bool enableFileWatcher = true;
  Duration fileWatchDebounce = Duration(milliseconds: 500);

  // Database configuration
  String? databasePath; // Default: graphPath/.logseq/logseq.db
  bool enableWAL = true; // SQLite WAL mode for better concurrency
}
```

## Benefits

1. **Memory Efficiency**: Only cache hot data, not entire graph
2. **Fast Queries**: Database indexes provide O(log n) lookups
3. **Scalability**: Works with graphs of any size
4. **Durability**: Database transactions ensure data consistency
5. **Interoperability**: Markdown files remain the portable format
6. **Real-time Sync**: File watcher keeps DB and files in sync
7. **Backward Compatible**: Existing code continues to work

## Future Enhancements

1. **Multi-device Sync**: Database easier to sync than files
2. **Query Language**: Rich query capabilities via SQL
3. **Analytics**: Complex graph analytics on database
4. **Incremental Backups**: Database backup strategies
5. **Conflict Resolution**: Handle concurrent edits
6. **Change Notifications**: Reactive updates via streams
