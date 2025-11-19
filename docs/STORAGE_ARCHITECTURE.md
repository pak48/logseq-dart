# Storage Architecture

## Overview

Logseq Dart uses a **database-backed storage architecture** with automatic file synchronization. This provides the best of both worlds: the performance and query capabilities of a database, while maintaining compatibility with Logseq's markdown-based format.

## Key Benefits

### 1. Memory Efficiency
- **Before**: Entire graph loaded in memory (O(n) memory usage)
- **After**: Only recently accessed data cached (O(k) memory usage where k = cache size)
- **Result**: Works with graphs of any size without memory issues

### 2. Fast Data Access
- Database indexes provide O(log n) lookups
- LRU cache for hot data provides O(1) access
- Complex queries executed efficiently via SQL

### 3. Files as Ground Truth
- **Markdown files are always the source of truth**
- Database is a cache/index for performance
- All writes go to files first, then database
- File watcher syncs database FROM files
- External edits are automatically reflected

### 4. Automatic Synchronization
- File watcher monitors markdown files for changes
- Changes automatically synced to database
- Database always reflects file state
- No manual sync required

### 5. Data Durability
- Markdown files are the persistent storage
- SQLite transactions ensure database consistency
- Database serves as cache/index
- Files remain portable and editable in any editor

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                  LogseqClient (API Layer)                   │
│                                                             │
│  WRITE PATH: File First → Database Second                  │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                  Repository Layer                           │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────┐  │
│  │ Page         │  │ Block        │  │ Graph           │  │
│  │ Repository   │  │ Repository   │  │ Repository      │  │
│  └──────────────┘  └──────────────┘  └─────────────────┘  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │          LRU Cache (Recently Accessed Data)          │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────────────┬─────────────────┬──────────────────────┘
                     │                 │
                     ▼                 ▼
       ┌──────────────────────┐   ┌──────────────────────────┐
       │  SQLite Database     │   │  File System Watcher     │
       │  (Cache/Index)       │◄──│  (Syncs FROM Files)      │
       └──────────────────────┘   └──────────────────────────┘
                ▲                              │
                │                              ▼
                │                     ┌────────────────────┐
                └─────────────────────│ Markdown Files     │ ◄─ GROUND TRUTH
                      Updates cache   │ - pages/*.md       │
                                      │ - journals/*.md    │
                                      └────────────────────┘
```

## Components

### 1. LogseqClient (API Layer)

The client maintains the same API as the legacy version, ensuring backward compatibility.

**Key Methods:**
- `initialize()` - Initialize database and file watcher
- `getPageAsync(name)` - Get page from database
- `getBlockAsync(id)` - Get block from database
- `createPage()`, `updateBlock()`, etc. - Write operations
- `close()` - Cleanup resources

### 2. Repository Layer

Handles all database operations with caching.

**PageRepository:**
- CRUD operations for pages
- Query pages by namespace, tag, type
- Get journal pages
- Search pages

**BlockRepository:**
- CRUD operations for blocks
- Query blocks by task state, priority
- Get scheduled/deadline blocks
- Search block content

**GraphRepository:**
- Graph-level statistics
- Search across entire graph
- Get backlinks
- Graph insights

### 3. Database Layer

SQLite database with optimized schema.

**Key Tables:**
- `pages` - Page metadata
- `blocks` - Block content and metadata
- `properties` - Page and block properties
- `tags` - Page and block tags
- `links` - Page and block links
- `aliases` - Page aliases
- `block_children` - Block hierarchy
- `queries` - Query blocks
- `file_sync_state` - File synchronization tracking

**Indexes:**
- Primary keys and foreign keys
- Task state, scheduled date, deadline
- Content search
- Tag and property lookups

### 4. File Watcher

Monitors markdown files and syncs with database.

**Features:**
- Watches for file create/modify/delete events
- Debounces rapid changes (500ms)
- Parses markdown and updates database
- Ignores own writes to prevent loops
- Tracks file checksums to detect changes

### 5. Cache Layer

LRU (Least Recently Used) cache for hot data.

**Characteristics:**
- Configurable size (default: 100 pages, 1000 blocks)
- Automatic eviction of least used items
- Separate caches for pages and blocks
- Cache invalidation on writes

## Data Flow

### Read Operation

```
1. Client calls getPageAsync('My Page')
2. Check if in loaded graph → return if found
3. PageRepository.getPage('My Page')
4. Query database
5. Construct Page object with blocks
6. Return to client
```

### Write Operation

```
1. Client calls updateBlock(id, content)
2. Get block from database
3. Update block content
4. Get parent page
5. Start database transaction
   a. Update block in database
   b. Update properties, tags, links
6. Commit transaction
7. Generate markdown for page
8. Write markdown to file (ignoring this write in watcher)
9. Return updated block
```

### External File Change

```
1. User edits markdown file in external editor
2. File watcher detects change
3. Debounce timer waits 500ms
4. Parse markdown file
5. Start database transaction
   a. Update/insert page
   b. Update/insert blocks
   c. Update properties, tags, links
6. Commit transaction
7. Invalidate cache
```

## Database Schema

### Core Tables

```sql
-- Pages table
CREATE TABLE pages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    title TEXT NOT NULL,
    file_path TEXT,
    is_journal INTEGER DEFAULT 0,
    journal_date TEXT,
    namespace TEXT,
    ...
);

-- Blocks table
CREATE TABLE blocks (
    id TEXT PRIMARY KEY,
    page_id INTEGER NOT NULL,
    content TEXT NOT NULL,
    level INTEGER DEFAULT 0,
    parent_id TEXT,
    task_state TEXT,
    priority TEXT,
    scheduled_date TEXT,
    deadline_date TEXT,
    ...
    FOREIGN KEY (page_id) REFERENCES pages(id) ON DELETE CASCADE
);

-- Properties (for both pages and blocks)
CREATE TABLE properties (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    entity_type TEXT NOT NULL,  -- 'page' or 'block'
    entity_id TEXT NOT NULL,
    key TEXT NOT NULL,
    value TEXT NOT NULL,
    UNIQUE(entity_type, entity_id, key)
);

-- Tags (for both pages and blocks)
CREATE TABLE tags (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    entity_type TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    tag TEXT NOT NULL,
    UNIQUE(entity_type, entity_id, tag)
);
```

See `STORAGE_ARCHITECTURE.md` in the root directory for complete schema documentation.

## Configuration

### Client Configuration

```dart
final config = LogseqClientConfig(
  // Cache settings
  maxCachedPages: 100,      // Number of pages to cache (default: 100)
  maxCachedBlocks: 1000,    // Number of blocks to cache (default: 1000)

  // File watcher
  enableFileWatcher: true,  // Enable automatic file sync (default: true)

  // Database path (optional)
  databasePath: null,       // Default: graphPath/.logseq/logseq.db
);

final client = LogseqClient('/path/to/graph', config: config);
await client.initialize();
```

### Database Configuration

The database uses SQLite with:
- **WAL mode**: Better concurrency
- **Foreign keys**: Enabled for referential integrity
- **Auto-vacuum**: Keeps database size optimized

## Performance Characteristics

### Memory Usage

| Operation | In-Memory | Database-Backed |
|-----------|-----------|-----------------|
| Small graph (100 pages) | ~10 MB | ~2 MB |
| Medium graph (1000 pages) | ~100 MB | ~2 MB |
| Large graph (10000 pages) | ~1 GB | ~2 MB |

*Note: Cache size affects memory usage but is configurable*

### Query Performance

| Query Type | In-Memory | Database-Backed |
|------------|-----------|-----------------|
| Get page by name | O(1) | O(log n) |
| Get block by ID | O(1) | O(log n) |
| Search content | O(n) | O(n) with index |
| Filter by tag | O(n) | O(log n) |
| Filter by task state | O(n) | O(log n) |

*Database indexes significantly improve query performance*

### Initialization Time

| Graph Size | First Time | Subsequent |
|------------|-----------|------------|
| 100 pages | ~1 second | ~50 ms |
| 1000 pages | ~10 seconds | ~50 ms |
| 10000 pages | ~100 seconds | ~50 ms |

*First time includes parsing all markdown files*

## Migration Guide

### From Legacy Client

```dart
// Old code (in-memory)
final client = LogseqClient('/path/to/graph');
final graph = client.loadGraphSync();
final page = client.getPage('My Page');

// New code (database-backed)
final client = LogseqClient('/path/to/graph');
await client.initialize();  // Add initialization
final page = await client.getPageAsync('My Page');  // Use async methods

// Or load entire graph if needed
final graph = await client.loadGraph();
final page = client.getPage('My Page');  // Works after loading
```

### Key Changes

1. **Async Initialization**: Must call `await client.initialize()`
2. **Async Methods**: Use `getPageAsync()` and `getBlockAsync()` for database access
3. **Resource Cleanup**: Call `await client.close()` when done
4. **Legacy Available**: `LogseqClientLegacy` still available if needed

### Gradual Migration

You can use both versions side-by-side:

```dart
import 'package:logseq_dart/logseq_dart.dart';

// New database-backed client
final client = LogseqClient('/path/to/graph');
await client.initialize();

// Legacy in-memory client
final legacyClient = LogseqClientLegacy('/path/to/graph');
legacyClient.loadGraphSync();
```

## Troubleshooting

### Database Locked Error

If you see "database is locked" errors:
- Only one client instance should access a graph
- Call `await client.close()` before creating a new instance
- Check for orphaned database connections

### File Sync Not Working

If file changes aren't syncing:
- Ensure `enableFileWatcher: true` in config
- Check file system permissions
- Verify files are in the graph directory (not `.logseq/`)
- Restart the client to reinitialize the watcher

### Slow First-Time Initialization

First-time initialization parses all markdown files:
- Normal for large graphs
- Subsequent initializations are fast (just opens database)
- Progress messages printed to console

### Memory Still High

If memory usage is higher than expected:
- Reduce cache size in config
- Avoid calling `loadGraph()` unless necessary
- Use `getPageAsync()` instead of loading entire graph

## Best Practices

1. **Initialize Once**: Create one client instance and reuse it
2. **Use Async Methods**: Prefer `getPageAsync()` over `getPage()`
3. **Configure Cache**: Adjust cache size based on your needs
4. **Cleanup**: Always call `close()` when done
5. **Error Handling**: Wrap database operations in try-catch
6. **Large Graphs**: Use query methods instead of loading entire graph

## Future Enhancements

Planned improvements:
- Incremental backups
- Multi-device synchronization
- Advanced query language (SQL-like)
- Real-time change notifications via streams
- Conflict resolution for concurrent edits
- Export/import database directly

## Technical Details

### SQLite Version
- Requires SQLite 3.31.0 or higher
- Uses `sqflite` package for Flutter
- Uses `sqflite_common_ffi` for desktop platforms

### File Watching
- Uses `watcher` package
- Monitors directory recursively
- 500ms debounce to handle rapid changes
- Checksum-based change detection

### Cache Strategy
- LRU (Least Recently Used) eviction
- Separate caches for pages and blocks
- Cache invalidation on writes
- No cache warmup by default

## Related Documentation

- [Quick Start Guide](./QUICK_START.md) - Getting started with Logseq Dart
- [API Reference](./API_REFERENCE.md) - Complete API documentation
- [STORAGE_ARCHITECTURE.md](../STORAGE_ARCHITECTURE.md) - Detailed technical design
- [README.md](../README.md) - Project overview

---

For questions or issues, please [open an issue](https://github.com/pak48/logseq-dart/issues).
