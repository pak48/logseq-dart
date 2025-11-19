# Logseq Dart - Quick Start Guide

Get up and running with Logseq Dart in 5 minutes.

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  logseq_dart: ^0.1.0
```

Or install from Git:

```yaml
dependencies:
  logseq_dart:
    git:
      url: https://github.com/pak48/logseq-dart.git
```

Run:

```bash
dart pub get
# or
flutter pub get
```

## Basic Usage

### 1. Initialize Client

```dart
import 'package:logseq_dart/logseq_dart.dart';

void main() async {
  // Point to your Logseq graph directory
  final client = LogseqClient('/path/to/your/logseq/graph');

  // Initialize the database (required)
  await client.initialize();

  // The graph is now ready to use
  print('Graph initialized successfully');
}
```

**Important**: The new database-backed storage requires calling `initialize()` before using the client. This:
- Creates/opens the SQLite database
- Performs initial sync of markdown files (if needed)
- Starts the file watcher for automatic synchronization
- Is fast on subsequent runs (only first-time is slower)

### Storage Architecture

Logseq Dart now uses a **database-backed** approach instead of loading the entire graph into memory:

- **Memory Efficient**: Only caches recently accessed data
- **Fast Queries**: Database indexes provide O(log n) lookups
- **Auto-Sync**: File watcher keeps database and markdown files in sync
- **Same API**: Your existing code continues to work

### Configuration

```dart
// Customize cache and file watcher settings
final config = LogseqClientConfig(
  maxCachedPages: 100,      // Default: 100
  maxCachedBlocks: 1000,    // Default: 1000
  enableFileWatcher: true,  // Default: true
);

final client = LogseqClient('/path/to/graph', config: config);
await client.initialize();
```

### 2. Read Data

```dart
// Get a specific page (from database)
final page = await client.getPageAsync('My Page');
if (page != null) {
  print('Page has ${page.blocks.length} blocks');
}

// Get a block by ID
final block = await client.getBlockAsync('block-id-here');

// Get statistics
final stats = await client.getStatistics();
print('Total pages: ${stats['totalPages']}');
print('Total tasks: ${stats['taskBlocks']}');
print('Completed: ${stats['completedTasks']}');
```

**Note**: With database storage, use the async methods (`getPageAsync`, `getBlockAsync`) for reliable data access.

### 3. Query Tasks

```dart
// Find all TODO tasks
final todos = client.query()
    .blocks()
    .hasTaskState(TaskState.todo)
    .execute();

print('You have ${todos.length} TODO items');

// Find high-priority incomplete tasks
final urgent = client.query()
    .blocks()
    .isTask()
    .hasPriority(Priority.a)
    .customFilter((block) {
      final b = block as Block;
      return b.taskState != TaskState.done;
    })
    .execute();

print('${urgent.length} urgent tasks need attention');
```

### 4. Create Content

```dart
// Create a new page
await client.createPage(
  'Shopping List',
  content: '''- Milk
- Bread
- Eggs''',
);

// Add a journal entry
await client.addJournalEntry('TODO Call dentist #health');

// Add a block to existing page
await client.addBlockToPage(
  'Shopping List',
  'Coffee beans',
);
```

### 5. Advanced Queries

```dart
// Find Python code blocks
final pythonCode = client.query()
    .blocks()
    .isCodeBlock('python')
    .execute();

// Find recent journal entries
final weekAgo = DateTime.now().subtract(Duration(days: 7));
final recent = client.query()
    .pages()
    .isJournal()
    .createdAfter(weekAgo)
    .execute();

// Complex query
final results = client.query()
    .blocks()
    .hasTag('project')
    .hasAnyTag(['urgent', 'important'])
    .contentContains('deadline')
    .sortBy('updatedAt', desc: true)
    .limit(20)
    .execute();
```

## Common Patterns

### Task Management

```dart
// Get overdue tasks
final now = DateTime.now();
final overdue = client.query()
    .blocks()
    .hasDeadline()
    .customFilter((block) {
      final b = block as Block;
      return b.deadline != null && b.deadline!.date.isBefore(now);
    })
    .execute();

// Get workflow summary
final workflow = graph.getWorkflowSummary();
print('Completion rate: ${workflow['completionRate']}%');
print('TODO: ${workflow['taskStates']['TODO']}');
print('DONE: ${workflow['taskStates']['DONE']}');
```

### Content Analysis

```dart
// Find all headings
final headings = client.query()
    .blocks()
    .isHeading()
    .execute();

// Get math/LaTeX blocks
final mathBlocks = client.query()
    .blocks()
    .hasMathContent()
    .execute();

// Find blocks with references
final linked = client.query()
    .blocks()
    .hasBlockReferences()
    .execute();
```

### Graph Analytics

```dart
// Get comprehensive insights
final insights = graph.getGraphInsights();

print('Most connected pages:');
final mostConnected = insights['mostConnectedPages'] as List;
for (final entry in mostConnected.take(5)) {
  print('  ${entry[0]}: ${entry[1]} connections');
}

print('\nMost used tags:');
final mostUsedTags = insights['mostUsedTags'] as List;
for (final entry in mostUsedTags.take(5)) {
  print('  #${entry[0]}: ${entry[1]} uses');
}

// Analyze namespaces
print('\nNamespaces:');
for (final ns in graph.getAllNamespaces()) {
  final pages = graph.getPagesByNamespace(ns);
  print('  $ns: ${pages.length} pages');
}
```

### Search

```dart
// Simple search
final results = client.search('important');
results.forEach((pageName, blocks) {
  print('$pageName: ${blocks.length} matches');
});

// Advanced search with query builder
final searchResults = client.query()
    .blocks()
    .contentMatches(RegExp(r'TODO.*urgent', caseSensitive: false))
    .hasTag('project')
    .execute();
```

## Query Builder Cheat Sheet

### Targets
- `.blocks()` - Query blocks (default)
- `.pages()` - Query pages

### Content Filters
- `.contentContains('text')` - Text search
- `.contentMatches(RegExp(...))` - Regex search
- `.hasTag('tag')` - Has specific tag
- `.hasProperty('key', 'value')` - Has property

### Task Filters
- `.isTask()` - Any task
- `.hasTaskState(TaskState.todo)` - Specific state
- `.isCompletedTask()` - Done tasks
- `.hasPriority(Priority.a)` - Priority level
- `.hasScheduledDate()` - Has scheduled date
- `.hasDeadline()` - Has deadline

### Content Type Filters
- `.isHeading(level)` - Heading blocks
- `.isCodeBlock('language')` - Code blocks
- `.hasMathContent()` - LaTeX/math
- `.hasQuery()` - Query blocks
- `.hasBlockReferences()` - Block refs

### Page Filters
- `.isJournal()` - Journal pages
- `.inNamespace('project')` - In namespace
- `.isTemplate()` - Template pages
- `.hasAlias('alias')` - Has alias

### Structure Filters
- `.level(0)` - Indentation level
- `.hasChildren()` - Has child blocks
- `.isOrphan()` - Top-level blocks
- `.inPage('Page Name')` - In specific page

### Date Filters
- `.createdAfter(date)` - Created after
- `.createdBefore(date)` - Created before
- `.updatedAfter(date)` - Updated after

### Execution
- `.execute()` - Get results
- `.count()` - Count results
- `.first()` - Get first result
- `.exists()` - Check if any exist
- `.sortBy('field', desc: true)` - Sort
- `.limit(10)` - Limit results

### Custom Filters
```dart
.customFilter((item) {
  // Your custom logic
  return true;
})
```

## Full Example

```dart
import 'package:logseq_dart/logseq_dart.dart';

void main() async {
  // Initialize
  final client = LogseqClient('/path/to/graph');
  final graph = client.loadGraphSync();

  // Create project page
  await client.createPage(
    'Project: Mobile App',
    content: '''# Overview
- TODO Design mockups [#A]
  SCHEDULED: <2024-01-20 Sat>
- TODO Set up Flutter project [#A]
- Research state management options

# Notes
- Target platforms: iOS, Android
- Launch: Q2 2024''',
  );

  // Track progress
  final projectTasks = client.query()
      .blocks()
      .inPage('Project: Mobile App')
      .isTask()
      .execute();

  print('Project has ${projectTasks.length} tasks');

  // Find blockers
  final blockers = client.query()
      .blocks()
      .hasTag('blocked')
      .customFilter((b) => (b as Block).taskState != TaskState.done)
      .execute();

  if (blockers.isNotEmpty) {
    print('\n⚠️  ${blockers.length} tasks are blocked');
  }

  // Daily summary
  final today = DateTime.now();
  final todaysTasks = client.query()
      .blocks()
      .hasScheduledDate(today)
      .execute();

  print('\n📅 Today\'s schedule:');
  for (final task in todaysTasks) {
    final b = task as Block;
    print('  ${b.taskState?.value ?? ''} ${b.content}');
  }

  // Generate insights
  final insights = graph.getGraphInsights();
  print('\n📊 Graph Stats:');
  print('  Pages: ${insights['totalPages']}');
  print('  Blocks: ${insights['totalBlocks']}');
  print('  Completion rate: ${insights['completionRate']?.toStringAsFixed(1)}%');
}
```

## Next Steps

- **Full API Reference**: See [API_REFERENCE.md](./API_REFERENCE.md) for complete documentation
- **Examples**: Check the `test/` directory for more examples
- **README**: See [README.md](../README.md) for feature overview

## Tips

1. **Initialization**: Always call `await client.initialize()` before using the client
2. **Async Methods**: Use `getPageAsync()` and `getBlockAsync()` for database-backed access
3. **Memory Efficiency**: Database storage works with graphs of any size without memory issues
4. **File Sync**: Changes to markdown files are automatically synced to database
5. **Queries**: Chain filters for powerful searches
6. **Custom Logic**: Use `.customFilter()` for complex conditions
7. **Analytics**: Use `getGraphInsights()` for comprehensive statistics
8. **Export**: Use `exportToJson()` to backup your graph data
9. **Cleanup**: Call `await client.close()` when done to cleanup resources

## Migration from Legacy Version

If you're upgrading from the in-memory version:

```dart
// Old (in-memory)
final client = LogseqClient('/path/to/graph');
final graph = client.loadGraphSync();
final page = client.getPage('My Page');

// New (database-backed)
final client = LogseqClient('/path/to/graph');
await client.initialize();  // Add this
final page = await client.getPageAsync('My Page');  // Use async version

// Or load entire graph if needed
final graph = await client.loadGraph();
final page = client.getPage('My Page');  // Works if graph is loaded
```

The legacy in-memory client is still available as `LogseqClientLegacy` if needed.

## Need Help?

- [Open an issue](https://github.com/pak48/logseq-dart/issues)
- Check the [API Reference](./API_REFERENCE.md)
- Review the [test suite](../test/logseq_dart_test.dart)

---

Happy coding! 🚀
