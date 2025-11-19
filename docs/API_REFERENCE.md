# Logseq Dart - API Reference

Complete API reference for the Logseq Dart library. This document covers all public classes, methods, and types.

## Table of Contents

- [Installation](#installation)
- [Core Classes](#core-classes)
  - [LogseqClient](#logseqclient)
  - [LogseqGraph](#logseqgraph)
  - [QueryBuilder](#querybuilder)
- [Models](#models)
  - [Page](#page)
  - [Block](#block)
  - [Enums](#enums)
  - [Advanced Models](#advanced-models)
- [Utilities](#utilities)

---

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  logseq_dart: ^0.1.0
```

Or from Git:

```yaml
dependencies:
  logseq_dart:
    git:
      url: https://github.com/pak48/logseq-dart.git
```

Then import:

```dart
import 'package:logseq_dart/logseq_dart.dart';
```

---

## Core Classes

### LogseqClient

Main interface for interacting with Logseq graphs. Handles loading, parsing, and CRUD operations.

#### Constructor

```dart
LogseqClient(String graphPath)
```

Creates a client instance pointing to a Logseq graph directory.

**Parameters:**
- `graphPath` - Absolute path to the Logseq graph directory

**Throws:** `FileSystemException` if the directory doesn't exist

**Example:**
```dart
final client = LogseqClient('/path/to/logseq/graph');
```

#### Properties

##### `graph` → `LogseqGraph`

Returns the loaded graph. Loads automatically if not already loaded.

```dart
final graph = client.graph; // Loads if needed
```

#### Methods

##### Loading & Reloading

**`loadGraph({bool forceReload = false})` → `Future<LogseqGraph>`**

Asynchronously loads the graph from disk.

**Parameters:**
- `forceReload` - If true, reloads even if already loaded

**Returns:** The loaded `LogseqGraph`

**Example:**
```dart
final graph = await client.loadGraph();
final reloaded = await client.loadGraph(forceReload: true);
```

---

**`loadGraphSync({bool forceReload = false})` → `LogseqGraph`**

Synchronously loads the graph from disk.

**Parameters:**
- `forceReload` - If true, reloads even if already loaded

**Returns:** The loaded `LogseqGraph`

**Example:**
```dart
final graph = client.loadGraphSync();
```

---

**`reloadGraph()` → `Future<LogseqGraph>`**

Convenience method to reload the graph from disk.

**Example:**
```dart
await client.reloadGraph();
```

##### Querying

**`query()` → `QueryBuilder`**

Creates a new query builder for advanced searches.

**Returns:** A fresh `QueryBuilder` instance

**Example:**
```dart
final results = client.query()
    .blocks()
    .hasTag('important')
    .execute();
```

---

**`getPage(String pageName)` → `Page?`**

Retrieves a page by name.

**Parameters:**
- `pageName` - Name of the page to retrieve

**Returns:** The `Page` or null if not found

**Example:**
```dart
final page = client.getPage('My Page');
```

---

**`getBlock(String blockId)` → `Block?`**

Retrieves a block by ID.

**Parameters:**
- `blockId` - UUID of the block

**Returns:** The `Block` or null if not found

**Example:**
```dart
final block = client.getBlock('abc123...');
```

---

**`search(String query, {bool caseSensitive = false})` → `Map<String, List<Block>>`**

Searches for text across all pages.

**Parameters:**
- `query` - Search string
- `caseSensitive` - Whether search is case-sensitive (default: false)

**Returns:** Map of page names to matching blocks

**Example:**
```dart
final results = client.search('important task');
```

##### CRUD Operations

**`createPage(String name, {String? content, Map<String, dynamic>? properties})` → `Future<Page>`**

Creates a new page.

**Parameters:**
- `name` - Page name
- `content` - Optional markdown content
- `properties` - Optional page properties

**Returns:** The created `Page`

**Throws:** `StateError` if page already exists

**Example:**
```dart
final page = await client.createPage(
  'Project Plan',
  content: '- TODO Initial setup\n- Research phase',
  properties: {'type': 'project'},
);
```

---

**`addJournalEntry(String content, {DateTime? date})` → `Future<Page>`**

Adds an entry to a journal page.

**Parameters:**
- `content` - Entry content
- `date` - Optional date (defaults to today)

**Returns:** The journal `Page`

**Example:**
```dart
await client.addJournalEntry('TODO Review documentation');
await client.addJournalEntry('Meeting notes', date: DateTime(2024, 1, 15));
```

---

**`createJournalPage(DateTime date)` → `Future<Page>`**

Creates a new journal page for a specific date.

**Parameters:**
- `date` - Date for the journal page

**Returns:** The created journal `Page`

**Example:**
```dart
final journal = await client.createJournalPage(DateTime(2024, 1, 15));
```

---

**`addBlockToPage(String pageName, String content, {String? parentBlockId})` → `Future<Block>`**

Adds a new block to a page.

**Parameters:**
- `pageName` - Name of the target page
- `content` - Block content
- `parentBlockId` - Optional parent block ID for nesting

**Returns:** The created `Block`

**Throws:** `StateError` if page not found

**Example:**
```dart
final block = await client.addBlockToPage('My Page', 'New task item');
final nested = await client.addBlockToPage(
  'My Page',
  'Nested item',
  parentBlockId: block.id,
);
```

---

**`updateBlock(String blockId, String content)` → `Future<Block?>`**

Updates a block's content.

**Parameters:**
- `blockId` - ID of block to update
- `content` - New content

**Returns:** Updated `Block` or null if not found

**Example:**
```dart
await client.updateBlock('block-id', 'DONE Task completed');
```

---

**`deleteBlock(String blockId)` → `Future<bool>`**

Deletes a block. Children are promoted to parent level.

**Parameters:**
- `blockId` - ID of block to delete

**Returns:** `true` if deleted, `false` if not found

**Example:**
```dart
final deleted = await client.deleteBlock('block-id');
```

##### Analytics & Export

**`getStatistics()` → `Map<String, dynamic>`**

Returns comprehensive graph statistics.

**Returns:** Map containing statistics like total pages, blocks, tasks, etc.

**Example:**
```dart
final stats = client.getStatistics();
print('Pages: ${stats['totalPages']}');
print('Tasks: ${stats['taskBlocks']}');
```

---

**`exportToJson(String outputPath)` → `Future<void>`**

Exports the entire graph to JSON format.

**Parameters:**
- `outputPath` - Path to save JSON file

**Example:**
```dart
await client.exportToJson('/path/to/export.json');
```

---

**`saveAll()` → `Future<int>`**

Saves all modified pages to disk.

**Returns:** Number of pages saved

**Example:**
```dart
final count = await client.saveAll();
print('Saved $count pages');
```

---

### LogseqGraph

Container for the entire graph data. Accessed via `LogseqClient.graph`.

#### Properties

- `rootPath` → `String` - Root directory of the graph
- `pages` → `Map<String, Page>` - All pages indexed by name
- `blocks` → `Map<String, Block>` - All blocks indexed by ID
- `config` → `Map<String, dynamic>` - Graph configuration
- `createdAt` → `DateTime` - When graph was loaded
- `updatedAt` → `DateTime` - Last update timestamp

#### Methods

##### Page Access

**`getPage(String pageName)` → `Page?`**

**`getAllPages()` → `List<Page>`**

**`getJournalPages()` → `List<Page>`**

Returns all journal pages sorted by date.

**`getPagesByNamespace(String namespace)` → `List<Page>`**

Returns pages in a specific namespace (e.g., "project/backend").

**`getAllNamespaces()` → `Set<String>`**

Returns all unique namespaces in the graph.

**`getBacklinks(String pageName)` → `Set<String>`**

Returns names of pages that link to the specified page.

##### Block Access

**`getBlock(String blockId)` → `Block?`**

**`getAllBlocks()` → `List<Block>`**

**`getTaskBlocks()` → `List<Block>`**

Returns all task blocks (TODO, DOING, etc.).

**`getCompletedTasks()` → `List<Block>`**

Returns only completed (DONE) tasks.

**`getCodeBlocks({String? language})` → `List<Block>`**

Returns code blocks, optionally filtered by language.

**`getBlocksByTag(String tag)` → `List<Block>`**

Returns blocks containing a specific tag.

##### Search

**`searchContent(String query, {bool caseSensitive = false})` → `Map<String, List<Block>>`**

Searches for text across all content.

##### Analytics

**`getStatistics()` → `Map<String, dynamic>`**

Returns statistics including:
- `totalPages`, `totalBlocks`, `totalTags`
- `journalPages`, `taskBlocks`, `completedTasks`
- `codeBlocks`, `headingBlocks`, `mathBlocks`
- `totalProperties`, `avgBlocksPerPage`

**`getWorkflowSummary()` → `Map<String, dynamic>`**

Returns task workflow statistics:
- `totalTasks` - Total task count
- `taskStates` - Map of state → count
- `priorities` - Map of priority → count
- `completionRate` - Percentage of completed tasks
- `scheduledCount`, `overdueCount`

**`getGraphInsights()` → `Map<String, dynamic>`**

Returns comprehensive insights:
- All statistics from `getStatistics()`
- `mostConnectedPages` - List of [page, connection_count]
- `mostUsedTags` - List of [tag, usage_count]
- `blockTypeDistribution` - Map of type → count
- `namespaceDistribution` - Map of namespace → page_count

**`static isSameDay(DateTime a, DateTime b)` → `bool`**

Utility to check if two dates are the same day.

---

### QueryBuilder

Fluent interface for building complex queries. Created via `LogseqClient.query()`.

#### Target Selection

**`blocks()` → `QueryBuilder`**

Query blocks (default).

**`pages()` → `QueryBuilder`**

Query pages instead of blocks.

#### Content Filters

**`contentContains(String text, {bool caseSensitive = false})` → `QueryBuilder`**

Filter by content containing text.

**`contentMatches(Pattern pattern)` → `QueryBuilder`**

Filter by regex pattern match.

#### Tag & Property Filters

**`hasTag(String tag)` → `QueryBuilder`**

Filter items with a specific tag.

**`hasAnyTag(List<String> tags)` → `QueryBuilder`**

Filter items with any of the tags.

**`hasAllTags(List<String> tags)` → `QueryBuilder`**

Filter items with all the tags.

**`hasProperty(String key, [String? value])` → `QueryBuilder`**

Filter items with a property. If value is provided, must match exactly.

#### Link Filters

**`linksTo(String pageName)` → `QueryBuilder`**

Filter items linking to a specific page.

**`inPage(String pageName)` → `QueryBuilder`**

Filter blocks in a specific page.

#### Page-Specific Filters

**`isJournal([bool isJournal = true])` → `QueryBuilder`**

Filter journal pages.

**`inNamespace(String namespace)` → `QueryBuilder`**

Filter pages in a namespace.

**`isTemplate()` → `QueryBuilder`**

Filter template pages.

**`isWhiteboard()` → `QueryBuilder`**

Filter whiteboard pages.

**`hasAlias(String alias)` → `QueryBuilder`**

Filter pages with a specific alias.

#### Date Filters

**`createdAfter(DateTime date)` → `QueryBuilder`**

**`createdBefore(DateTime date)` → `QueryBuilder`**

**`updatedAfter(DateTime date)` → `QueryBuilder`**

#### Block Structure Filters

**`level(int level)` → `QueryBuilder`**

Filter blocks at exact indentation level.

**`minLevel(int level)` → `QueryBuilder`**

Filter blocks at or above indentation level.

**`maxLevel(int level)` → `QueryBuilder`**

Filter blocks at or below indentation level.

**`hasChildren()` → `QueryBuilder`**

Filter blocks with child blocks.

**`isOrphan()` → `QueryBuilder`**

Filter top-level blocks (no parent).

#### Task Filters

**`isTask()` → `QueryBuilder`**

Filter task blocks (any TODO state).

**`hasTaskState(TaskState state)` → `QueryBuilder`**

Filter by specific task state.

**`isCompletedTask()` → `QueryBuilder`**

Filter completed tasks (DONE).

**`hasPriority(Priority priority)` → `QueryBuilder`**

Filter by priority level (A, B, C).

**`hasScheduledDate([DateTime? date])` → `QueryBuilder`**

Filter scheduled items. If date provided, matches that specific date.

**`hasDeadline([DateTime? date])` → `QueryBuilder`**

Filter items with deadlines. If date provided, matches that specific date.

#### Content Type Filters

**`hasBlockType(BlockType blockType)` → `QueryBuilder`**

Filter by block type.

**`isHeading([int? level])` → `QueryBuilder`**

Filter heading blocks. Optionally by level (1-6).

**`isCodeBlock([String? language])` → `QueryBuilder`**

Filter code blocks. Optionally by programming language.

**`hasMathContent()` → `QueryBuilder`**

Filter blocks with LaTeX/math content.

**`hasQuery()` → `QueryBuilder`**

Filter blocks containing Logseq queries.

**`hasBlockReferences()` → `QueryBuilder`**

Filter blocks referencing other blocks.

**`hasEmbeds()` → `QueryBuilder`**

Filter blocks with embedded content.

**`hasAnnotations()` → `QueryBuilder`**

Filter items with PDF annotations.

**`isCollapsed()` → `QueryBuilder`**

Filter collapsed blocks.

#### Custom & Execution

**`customFilter(bool Function(dynamic) filterFunc)` → `QueryBuilder`**

Add a custom filter function.

**`sortBy(String field, {bool desc = false})` → `QueryBuilder`**

Sort results by field. Available fields:
- Blocks: `content`, `level`, `createdAt`, `updatedAt`
- Pages: `name`, `title`, `createdAt`, `updatedAt`

**`limit(int count)` → `QueryBuilder`**

Limit number of results.

**`execute()` → `List<dynamic>`**

Execute query and return results.

**`count()` → `int`**

Count matching items without returning them.

**`first()` → `dynamic`**

Get first matching item or null.

**`exists()` → `bool`**

Check if any items match.

#### Example

```dart
final results = client.query()
    .blocks()
    .isTask()
    .hasPriority(Priority.a)
    .hasTag('urgent')
    .customFilter((block) => (block as Block).taskState != TaskState.done)
    .sortBy('updatedAt', desc: true)
    .limit(10)
    .execute();
```

---

## Models

### Page

Represents a Logseq page.

#### Properties

- `name` → `String` - Page name
- `title` → `String` - Display title (derived from name)
- `filePath` → `String?` - Path to markdown file
- `blocks` → `List<Block>` - All blocks in page
- `properties` → `Map<String, dynamic>` - Page properties
- `tags` → `Set<String>` - All tags in page
- `links` → `Set<String>` - Pages this page links to
- `backlinks` → `Set<String>` - Pages linking to this page
- `aliases` → `Set<String>` - Page aliases
- `namespace` → `String?` - Namespace (e.g., "project")
- `isJournal` → `bool` - Whether it's a journal page
- `journalDate` → `DateTime?` - Journal date if applicable
- `isTemplate` → `bool` - Whether it's a template
- `isWhiteboard` → `bool` - Whether it's a whiteboard
- `annotations` → `List<Annotation>` - PDF annotations
- `createdAt` → `DateTime` - Creation timestamp
- `updatedAt` → `DateTime` - Last update timestamp

#### Methods

**`addBlock(Block block)` → `void`**

Add a block to the page.

**`getTaskBlocks()` → `List<Block>`**

Get all task blocks in page.

**`getCompletedTasks()` → `List<Block>`**

Get completed tasks in page.

**`getCodeBlocks({String? language})` → `List<Block>`**

Get code blocks, optionally filtered by language.

**`getBlocksByTag(String tag)` → `List<Block>`**

Get blocks with a specific tag.

**`getBlocksByLevel(int level)` → `List<Block>`**

Get blocks at a specific indentation level.

**`getTopLevelBlocks()` → `List<Block>`**

Get root-level blocks (level 0).

**`getPageOutline()` → `List<Map<String, dynamic>>`**

Get hierarchical outline of page structure.

**`toMarkdown()` → `String`**

Convert page to markdown format.

**`toJson()` → `Map<String, dynamic>`**

Convert to JSON representation.

---

### Block

Represents a Logseq block.

#### Properties

- `id` → `String` - Unique UUID
- `content` → `String` - Block content
- `pageName` → `String?` - Parent page name
- `level` → `int` - Indentation level (0 = top)
- `parentId` → `String?` - Parent block ID
- `childrenIds` → `List<String>` - Child block IDs
- `taskState` → `TaskState?` - TODO state
- `priority` → `Priority?` - Priority level (A/B/C)
- `scheduled` → `ScheduledDate?` - Scheduled date
- `deadline` → `ScheduledDate?` - Deadline date
- `blockType` → `BlockType` - Type of block
- `headingLevel` → `int?` - Heading level (1-6)
- `codeLanguage` → `String?` - Programming language for code blocks
- `latexContent` → `String?` - LaTeX/math content
- `query` → `LogseqQuery?` - Embedded query
- `tags` → `Set<String>` - Tags in block
- `properties` → `Map<String, dynamic>` - Block properties
- `collapsed` → `bool` - Whether block is collapsed
- `referencedBlocks` → `Set<String>` - Referenced block IDs
- `embeddedBlocks` → `List<BlockEmbed>` - Embedded blocks
- `annotations` → `List<Annotation>` - PDF annotations
- `createdAt` → `DateTime` - Creation timestamp
- `updatedAt` → `DateTime` - Last update timestamp

#### Methods

**`isTask()` → `bool`**

Check if block is a task.

**`isCompletedTask()` → `bool`**

Check if task is completed (DONE).

**`isScheduled()` → `bool`**

Check if block has a scheduled date.

**`hasDeadline()` → `bool`**

Check if block has a deadline.

**`getLinks()` → `Set<String>`**

Extract all page links from content.

**`getBlockReferences()` → `Set<String>`**

Extract all block references.

**`addChild(Block child)` → `void`**

Add a child block.

**`toMarkdown()` → `String`**

Convert to markdown format.

**`toJson()` → `Map<String, dynamic>`**

Convert to JSON representation.

---

### Enums

#### TaskState

Task states in Logseq.

**Values:**
- `TaskState.todo` - 'TODO'
- `TaskState.doing` - 'DOING'
- `TaskState.done` - 'DONE'
- `TaskState.later` - 'LATER'
- `TaskState.now` - 'NOW'
- `TaskState.waiting` - 'WAITING'
- `TaskState.cancelled` - 'CANCELLED'
- `TaskState.delegated` - 'DELEGATED'
- `TaskState.inProgress` - 'IN-PROGRESS'

**Methods:**
- `static fromString(String value)` → `TaskState?`

**Example:**
```dart
final state = TaskState.fromString('TODO'); // TaskState.todo
```

#### Priority

Priority levels.

**Values:**
- `Priority.a` - 'A' (highest)
- `Priority.b` - 'B'
- `Priority.c` - 'C' (lowest)

**Methods:**
- `static fromString(String value)` → `Priority?`

#### BlockType

Types of blocks.

**Values:**
- `BlockType.bullet` - Regular bullet point
- `BlockType.numbered` - Numbered list
- `BlockType.quote` - Quote block
- `BlockType.heading` - Heading (H1-H6)
- `BlockType.code` - Code block
- `BlockType.math` - Math/LaTeX block
- `BlockType.example` - Example block
- `BlockType.export` - Export block
- `BlockType.verse` - Verse block
- `BlockType.drawer` - Drawer block

**Methods:**
- `static fromString(String value)` → `BlockType?`

---

### Advanced Models

#### ScheduledDate

Represents scheduled/deadline dates with Logseq-specific features.

**Properties:**
- `date` → `DateTime` - The date
- `time` → `String?` - Optional time (e.g., "14:30")
- `repeater` → `String?` - Repeater pattern (e.g., "+1w", "+3d")
- `delay` → `String?` - Delay pattern

**Methods:**
- `toJson()` → `Map<String, dynamic>`
- `static fromJson(Map<String, dynamic>)` → `ScheduledDate`

#### BlockEmbed

Represents embedded block references.

**Properties:**
- `blockId` → `String` - Referenced block ID
- `contentPreview` → `String?` - Preview text
- `embedType` → `String` - "block", "page", or "query"

#### LogseqQuery

Represents a Logseq query block.

**Properties:**
- `queryString` → `String` - Query text
- `queryType` → `String` - "simple", "advanced", or "custom"
- `results` → `List<Map<String, dynamic>>` - Query results
- `live` → `bool` - Whether query is live
- `collapsed` → `bool` - Whether query results are collapsed

#### Template

Represents a Logseq template.

**Properties:**
- `name` → `String` - Template name
- `content` → `String` - Template content
- `variables` → `List<String>` - Template variables
- `usageCount` → `int` - Usage count
- `templateType` → `String` - "block" or "page"

#### Annotation

Represents PDF annotations.

**Properties:**
- `id` → `String` - Unique ID
- `content` → `String` - Annotation text
- `pageNumber` → `int?` - PDF page number
- `highlightText` → `String?` - Highlighted text
- `annotationType` → `String` - "highlight", "note", "underline"
- `color` → `String?` - Highlight color
- `pdfPath` → `String?` - Path to PDF
- `coordinates` → `Map<String, double>?` - Position data

#### WhiteboardElement

Represents elements on a Logseq whiteboard.

**Properties:**
- `id` → `String` - Unique ID
- `elementType` → `String` - "shape", "text", "block", "page", "image"
- `content` → `String` - Element content
- `position` → `Map<String, double>` - x, y coordinates
- `size` → `Map<String, double>` - width, height
- `style` → `Map<String, dynamic>` - Styling data
- `blockId` → `String?` - Linked block ID

---

## Utilities

### QueryStats

Helper class for computing statistics on query results.

**`static tagFrequency(List<dynamic> items)` → `Map<String, int>`**

Compute tag usage frequency from a list of items.

**`static pageDistribution(List<Block> blocks)` → `Map<String, int>`**

Compute page distribution for blocks.

**`static levelDistribution(List<Block> blocks)` → `Map<int, int>`**

Compute indentation level distribution.

**`static propertyFrequency(List<dynamic> items)` → `Map<String, int>`**

Compute property usage frequency.

**Example:**
```dart
final results = client.query().blocks().execute();
final tagFreq = QueryStats.tagFrequency(results);
print('Most used tag: ${tagFreq.entries.first.key}');
```

---

## Complete Example

```dart
import 'package:logseq_dart/logseq_dart.dart';

void main() async {
  // Initialize client
  final client = LogseqClient('/path/to/logseq/graph');

  // Load graph
  final graph = client.loadGraphSync();

  // Create a new project page
  await client.createPage(
    'Project Alpha',
    content: '''# Project Overview
- TODO Set up repository [#A]
  SCHEDULED: <2024-01-15 Mon>
- Research competitors
- Define MVP features''',
  );

  // Query high-priority tasks
  final urgentTasks = client.query()
      .blocks()
      .isTask()
      .hasPriority(Priority.a)
      .customFilter((b) => (b as Block).taskState != TaskState.done)
      .sortBy('updatedAt', desc: true)
      .execute();

  print('${urgentTasks.length} urgent tasks');

  // Add journal entry
  await client.addJournalEntry('TODO Review project documentation #urgent');

  // Get analytics
  final insights = graph.getGraphInsights();
  print('Total pages: ${insights['totalPages']}');
  print('Completion rate: ${insights['completionRate']}%');

  // Search content
  final results = client.search('documentation');
  results.forEach((page, blocks) {
    print('$page: ${blocks.length} matches');
  });

  // Export to JSON
  await client.exportToJson('/path/to/backup.json');
}
```

---

## License

MIT License - See LICENSE file for details.
