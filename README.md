# 📚 Logseq Dart

**The most comprehensive Dart/Flutter library for Logseq knowledge graph interaction**

Transform your Logseq workflow with programmatic access to every major feature. From basic note-taking to advanced task management, knowledge graph analytics, and more - this library supports it all, reimplemented from the excellent [logseq-python-library](https://github.com/thinmanj/logseq-python-library).

[![Dart](https://img.shields.io/badge/Dart-3.9.2+-blue.svg)](https://dart.dev)
[![Flutter](https://img.shields.io/badge/Flutter-3.35.7+-blue.svg)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## ✨ Comprehensive Feature Support

### 🎯 Task Management & Workflows
- ✅ **Complete Task System**: TODO, DOING, DONE, LATER, NOW, WAITING, CANCELLED, DELEGATED, IN-PROGRESS
- ✅ **Priority Levels**: A, B, C with full parsing and filtering
- ✅ **Scheduling**: SCHEDULED dates with time and repeaters (+1w, +3d)
- ✅ **Deadlines**: DEADLINE tracking with date comparisons
- ✅ **Workflow Analytics**: Completion rates, productivity metrics

### 📝 Advanced Content Types
- ✅ **Code Blocks**: Language detection (```dart, ```python, etc.)
- ✅ **Mathematics**: LaTeX/Math parsing ($$math$$, \\(inline\\))
- ✅ **Queries**: {{query}} and #+begin_query support
- ✅ **Headings**: H1-H6 hierarchical structure
- ✅ **References**: ((block-id)) linking and {{embed}} support
- ✅ **Properties**: Advanced property parsing and querying

### 🗂️ Organization & Structure
- ✅ **Namespaces**: project/backend hierarchical organization
- ✅ **Templates**: Template variables {{variable}} parsing
- ✅ **Aliases**: Page alias system with [[link]] support
- ✅ **Whiteboards**: .whiteboard file detection
- ✅ **Hierarchies**: Parent/child page relationships

### 📊 Knowledge Graph Analytics
- ✅ **Graph Insights**: Connection analysis, relationship mapping
- ✅ **Content Statistics**: Block type distribution, tag usage
- ✅ **Productivity Metrics**: Task completion trends
- ✅ **Workflow Summaries**: Advanced task analytics

### 🔍 Powerful Query System
- ✅ **25+ Query Methods**: Task states, priorities, content types
- ✅ **Date Filtering**: Scheduled, deadline, creation date queries
- ✅ **Content Filtering**: Code language, math content, headings
- ✅ **Relationship Queries**: Block references, embeds, backlinks
- ✅ **Advanced Combinations**: Chain multiple filters fluently

### 💾 Database-Backed Storage (New!)
- ✅ **Memory Efficient**: Only caches recently accessed data, not entire graph
- ✅ **Fast Queries**: SQLite indexes provide O(log n) lookups
- ✅ **Files as Ground Truth**: Markdown files are always the source of truth
- ✅ **Auto-Sync**: File watcher keeps database synchronized with file changes
- ✅ **Scalable**: Works with graphs of any size without memory issues
- ✅ **Same API**: Existing code continues to work with minimal changes

## 🚀 Quick Start

### Installation

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

### Basic Usage

```dart
import 'package:logseq_dart/logseq_dart.dart';

void main() async {
  // Initialize client with your Logseq graph directory
  final client = LogseqClient('/path/to/your/logseq/graph');

  // Initialize database (required)
  await client.initialize();

  // Get statistics
  final stats = await client.getStatistics();
  print('Total pages: ${stats['totalPages']}');
  print('Total blocks: ${stats['totalBlocks']}');
  print('Tasks: ${stats['taskBlocks']}');

  // Get a specific page
  final page = await client.getPageAsync('My Page');
  if (page != null) {
    print('Page has ${page.blocks.length} blocks');
  }

  // Cleanup when done
  await client.close();
}
```

**Important**: The new database-backed storage requires calling `await client.initialize()` before use. See the [Storage Architecture docs](docs/STORAGE_ARCHITECTURE.md) for details.

## 📋 Task Management Examples

```dart
import 'package:logseq_dart/logseq_dart.dart';

void main() {
  final client = LogseqClient('/path/to/graph');
  final graph = client.graph;

  // Find all high-priority tasks
  final urgentTasks = client
      .query()
      .blocks()
      .hasPriority(Priority.a)
      .execute();

  print('High priority tasks: ${urgentTasks.length}');

  // Get overdue tasks
  final now = DateTime.now();
  final overdue = client
      .query()
      .blocks()
      .hasDeadline()
      .customFilter((block) {
        final b = block as Block;
        return b.deadline != null && b.deadline!.date.isBefore(now);
      })
      .execute();

  print('Overdue tasks: ${overdue.length}');

  // Get workflow summary
  final workflow = graph.getWorkflowSummary();
  print('Total tasks: ${workflow['totalTasks']}');
  print('Completed: ${workflow['taskStates']['DONE']}');
  print('In progress: ${workflow['taskStates']['DOING']}');
}
```

## 💻 Code & Content Analysis

```dart
import 'package:logseq_dart/logseq_dart.dart';

void main() {
  final client = LogseqClient('/path/to/graph');

  // Find all Python code blocks
  final pythonCode = client
      .query()
      .blocks()
      .isCodeBlock('python')
      .execute();

  print('Python code blocks: ${pythonCode.length}');

  // Get all math/LaTeX content
  final mathBlocks = client
      .query()
      .blocks()
      .hasMathContent()
      .execute();

  print('Math blocks: ${mathBlocks.length}');

  // Find all headings
  final headings = client
      .query()
      .blocks()
      .isHeading()
      .execute();

  print('Total headings: ${headings.length}');

  // Get blocks with references
  final linkedBlocks = client
      .query()
      .blocks()
      .hasBlockReferences()
      .execute();

  print('Blocks with references: ${linkedBlocks.length}');
}
```

## 📊 Advanced Analytics

```dart
import 'package:logseq_dart/logseq_dart.dart';

void main() {
  final client = LogseqClient('/path/to/graph');
  final graph = client.graph;

  // Get comprehensive graph insights
  final insights = graph.getGraphInsights();

  print('\n=== Graph Statistics ===');
  print('Pages: ${insights['totalPages']}');
  print('Blocks: ${insights['totalBlocks']}');
  print('Tags: ${insights['totalTags']}');

  // Analyze namespaces
  print('\n=== Namespaces ===');
  for (final namespace in graph.getAllNamespaces()) {
    final pages = graph.getPagesByNamespace(namespace);
    print('$namespace: ${pages.length} pages');
  }

  // Most connected pages
  print('\n=== Most Connected Pages ===');
  final mostConnected = insights['mostConnectedPages'] as List;
  for (final entry in mostConnected.take(5)) {
    print('${entry[0]}: ${entry[1]} connections');
  }

  // Most used tags
  print('\n=== Most Used Tags ===');
  final mostUsedTags = insights['mostUsedTags'] as List;
  for (final entry in mostUsedTags.take(5)) {
    print('#${entry[0]}: ${entry[1]} uses');
  }
}
```

## ✍️ Content Creation

```dart
import 'package:logseq_dart/logseq_dart.dart';

Future<void> main() async {
  final client = LogseqClient('/path/to/graph');

  // Add journal entry with task
  await client.addJournalEntry('TODO Review project documentation #urgent');

  // Create a structured page
  final content = '''# Project Planning
- TODO Set up initial framework [#A]
  SCHEDULED: <2024-01-15 Mon>
- Code review checklist
  - Security audit
  - Performance testing''';

  await client.createPage('Project Alpha', content: content);

  print('Page created successfully!');
}
```

## 🔍 Advanced Query Examples

```dart
import 'package:logseq_dart/logseq_dart.dart';

void main() {
  final client = LogseqClient('/path/to/graph');

  // Complex query with multiple filters
  final results = client
      .query()
      .blocks()
      .isTask()
      .hasPriority(Priority.a)
      .hasTag('urgent')
      .customFilter((block) {
        final b = block as Block;
        return b.taskState != TaskState.done;
      })
      .sortBy('updatedAt', desc: true)
      .limit(10)
      .execute();

  print('Top 10 urgent incomplete high-priority tasks:');
  for (final block in results) {
    final b = block as Block;
    print('- ${b.content}');
  }

  // Query pages by namespace
  final projectPages = client
      .query()
      .pages()
      .inNamespace('project')
      .execute();

  print('\nProject pages: ${projectPages.length}');

  // Find pages with aliases
  final pagesWithAliases = client
      .query()
      .pages()
      .customFilter((page) => (page as Page).aliases.isNotEmpty)
      .execute();

  print('Pages with aliases: ${pagesWithAliases.length}');
}
```

## 📖 Documentation

**📚 [Quick Start Guide](docs/QUICK_START.md)** - Get up and running in 5 minutes

**📘 [Complete API Reference](docs/API_REFERENCE.md)** - Full documentation of all classes and methods

### Core Classes

#### LogseqClient
Main interface for interacting with Logseq graphs.

```dart
final client = LogseqClient('/path/to/graph');
final graph = client.loadGraphSync(); // Synchronous load
final graph2 = await client.loadGraph(); // Async load

// Query builder
final query = client.query();

// CRUD operations
await client.createPage('New Page', content: 'Content');
await client.addJournalEntry('Entry content');
await client.addBlockToPage('Page Name', 'Block content');
await client.updateBlock('block-id', 'New content');
await client.deleteBlock('block-id');

// Search and statistics
final results = client.search('search term');
final stats = client.getStatistics();
```

#### LogseqGraph
Container for the entire graph data.

```dart
// Access pages and blocks
final page = graph.getPage('Page Name');
final block = graph.getBlock('block-id');

// Search and filter
final backlinks = graph.getBacklinks('Page Name');
final searchResults = graph.searchContent('query');
final journalPages = graph.getJournalPages();

// Get specific content
final taskBlocks = graph.getTaskBlocks();
final completedTasks = graph.getCompletedTasks();
final codeBlocks = graph.getCodeBlocks(language: 'dart');

// Analytics
final stats = graph.getStatistics();
final workflow = graph.getWorkflowSummary();
final insights = graph.getGraphInsights();
```

#### QueryBuilder
Fluent query interface with 25+ methods.

```dart
final results = client
    .query()
    .blocks() // or .pages()
    .contentContains('text')
    .hasTag('tag')
    .hasTaskState(TaskState.todo)
    .hasPriority(Priority.a)
    .isCodeBlock('dart')
    .hasScheduledDate()
    .sortBy('content')
    .limit(10)
    .execute();
```

### Models

#### Block
Represents a single block with full Logseq features.

```dart
final block = Block(
  content: 'TODO Task content',
  level: 0,
  taskState: TaskState.todo,
  priority: Priority.a,
);

// Properties
block.tags; // Set<String>
block.properties; // Map<String, dynamic>
block.getLinks(); // Set<String>
block.getBlockReferences(); // Set<String>

// Helpers
block.isTask();
block.isCompletedTask();
block.isScheduled();
block.hasDeadline();
```

#### Page
Represents a Logseq page.

```dart
final page = Page(name: 'Page Name');
page.addBlock(block);

// Query blocks
page.getTaskBlocks();
page.getCompletedTasks();
page.getCodeBlocks(language: 'dart');
page.getBlocksByTag('tag');

// Outline
final outline = page.getPageOutline();
```

## 🧪 Testing

Run the comprehensive test suite:

```bash
flutter test
```

All 50 tests cover:
- Enums and type conversions
- Block parsing and manipulation
- Page operations
- Graph operations
- Query builder functionality
- Advanced models
- Integration workflows

## 🎯 Real-World Use Cases

### 📈 Project Management
Track tasks across multiple projects with priorities and deadlines. Generate productivity reports and analyze workflow patterns.

### 🔬 Academic Research
Parse and analyze LaTeX mathematical content. Extract and organize research notes with citations.

### 💻 Software Development
Document code examples with syntax highlighting. Track bugs and features by priority. Organize documentation by namespace.

### 📚 Knowledge Management
Build comprehensive knowledge graphs with relationships. Track learning progress and generate insights.

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

The MIT License allows for commercial use, modification, distribution, and private use, with the only requirement being that the license and copyright notice must be included.

## 🙏 Acknowledgments

This library is a complete reimplementation of the excellent [logseq-python-library](https://github.com/thinmanj/logseq-python-library) by [Julio Ona](https://github.com/thinmanj). All core functionality, features, and design patterns have been faithfully ported to Dart/Flutter.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📧 Support

For issues, questions, or feature requests, please [open an issue](https://github.com/pak48/logseq-dart/issues) on GitHub.