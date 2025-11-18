import 'package:flutter_test/flutter_test.dart';
import 'package:logseq_dart/logseq_dart.dart';

void main() {
  group('Enums', () {
    test('TaskState fromString works correctly', () {
      expect(TaskState.fromString('TODO'), TaskState.todo);
      expect(TaskState.fromString('DONE'), TaskState.done);
      expect(TaskState.fromString('INVALID'), null);
    });

    test('Priority fromString works correctly', () {
      expect(Priority.fromString('A'), Priority.a);
      expect(Priority.fromString('B'), Priority.b);
      expect(Priority.fromString('C'), Priority.c);
      expect(Priority.fromString('D'), null);
    });

    test('BlockType fromString works correctly', () {
      expect(BlockType.fromString('bullet'), BlockType.bullet);
      expect(BlockType.fromString('code'), BlockType.code);
      expect(BlockType.fromString('heading'), BlockType.heading);
    });
  });

  group('Block', () {
    test('creates block with default values', () {
      final block = Block();
      expect(block.content, '');
      expect(block.level, 0);
      expect(block.blockType, BlockType.bullet);
      expect(block.tags.isEmpty, true);
    });

    test('extracts tags from content', () {
      final block = Block(content: 'This is a #test with #multiple tags');
      expect(block.tags.contains('test'), true);
      expect(block.tags.contains('multiple'), true);
    });

    test('extracts task state from content', () {
      final block = Block(content: 'TODO Write tests');
      expect(block.taskState, TaskState.todo);
      expect(block.isTask(), true);
    });

    test('extracts priority from content', () {
      final block = Block(content: '[#A] High priority task');
      expect(block.priority, Priority.a);
    });

    test('extracts links from content', () {
      final block = Block(content: 'Link to [[Page Name]] here');
      final links = block.getLinks();
      expect(links.contains('Page Name'), true);
    });

    test('extracts block references', () {
      final block =
          Block(content: 'Reference to ((block-id-123))');
      final refs = block.getBlockReferences();
      expect(refs.contains('block-id-123'), true);
    });

    test('handles parent-child relationships', () {
      final parent = Block(content: 'Parent block');
      final child = Block(content: 'Child block');

      parent.addChild(child);

      expect(parent.childrenIds.contains(child.id), true);
      expect(child.parentId, parent.id);
    });

    test('converts to markdown correctly', () {
      final block = Block(
        content: 'Test content',
        level: 0,
        taskState: TaskState.todo,
        priority: Priority.a,
      );

      final markdown = block.toMarkdown();
      expect(markdown.contains('- '), true);
      expect(markdown.contains('TODO'), true);
      expect(markdown.contains('[#A]'), true);
    });

    test('detects code blocks', () {
      final block = Block(content: '```dart\nvoid main() {}\n```');
      expect(block.blockType, BlockType.code);
      expect(block.codeLanguage, 'dart');
    });

    test('detects headings', () {
      final block = Block(content: '### Heading Level 3');
      expect(block.blockType, BlockType.heading);
      expect(block.headingLevel, 3);
    });
  });

  group('Page', () {
    test('creates page with default values', () {
      final page = Page(name: 'Test Page');
      expect(page.name, 'Test Page');
      expect(page.title, 'Test Page');
      expect(page.blocks.isEmpty, true);
    });

    test('adds blocks to page', () {
      final page = Page(name: 'Test Page');
      final block = Block(content: 'Test block');

      page.addBlock(block);

      expect(page.blocks.length, 1);
      expect(block.pageName, 'Test Page');
    });

    test('extracts namespace from page name', () {
      final page = Page(name: 'project/backend/api');
      expect(page.namespace, 'project');
    });

    test('identifies journal pages', () {
      final page = Page(name: '2024-01-15', isJournal: true);
      expect(page.isJournal, true);
    });

    test('gets task blocks', () {
      final page = Page(name: 'Tasks');
      page.addBlock(Block(content: 'TODO Task 1'));
      page.addBlock(Block(content: 'Regular block'));
      page.addBlock(Block(content: 'DONE Task 2'));

      final tasks = page.getTaskBlocks();
      expect(tasks.length, 2);
    });

    test('gets completed tasks', () {
      final page = Page(name: 'Tasks');
      page.addBlock(Block(content: 'TODO Task 1'));
      page.addBlock(Block(content: 'DONE Task 2'));

      final completed = page.getCompletedTasks();
      expect(completed.length, 1);
      expect(completed.first.taskState, TaskState.done);
    });

    test('gets code blocks by language', () {
      final page = Page(name: 'Code');
      page.addBlock(Block(content: '```dart\ncode\n```'));
      page.addBlock(Block(content: '```python\ncode\n```'));
      page.addBlock(Block(content: '```dart\nmore code\n```'));

      final dartBlocks = page.getCodeBlocks(language: 'dart');
      expect(dartBlocks.length, 2);
    });

    test('converts to markdown correctly', () {
      final page = Page(
        name: 'Test',
        properties: {'title': 'Test Page'},
        aliases: {'Alias1', 'Alias2'},
      );
      page.addBlock(Block(content: 'Block 1'));
      page.addBlock(Block(content: 'Block 2'));

      final markdown = page.toMarkdown();
      expect(markdown.contains('title::'), true);
      expect(markdown.contains('alias::'), true);
      expect(markdown.contains('Block 1'), true);
    });
  });

  group('LogseqGraph', () {
    test('creates graph with default values', () {
      final graph = LogseqGraph(rootPath: '/path/to/graph');
      expect(graph.rootPath, '/path/to/graph');
      expect(graph.pages.isEmpty, true);
      expect(graph.blocks.isEmpty, true);
    });

    test('adds page to graph', () {
      final graph = LogseqGraph(rootPath: '/path/to/graph');
      final page = Page(name: 'Test');
      page.addBlock(Block(content: 'Test block'));

      graph.addPage(page);

      expect(graph.pages.length, 1);
      expect(graph.blocks.length, 1);
    });

    test('gets page by name', () {
      final graph = LogseqGraph(rootPath: '/path/to/graph');
      final page = Page(name: 'Test');
      graph.addPage(page);

      final retrieved = graph.getPage('Test');
      expect(retrieved, isNotNull);
      expect(retrieved!.name, 'Test');
    });

    test('gets backlinks', () {
      final graph = LogseqGraph(rootPath: '/path/to/graph');

      final page1 = Page(name: 'Page1');
      page1.addBlock(Block(content: 'Link to [[Page2]]'));

      final page2 = Page(name: 'Page2');

      graph.addPage(page1);
      graph.addPage(page2);

      final backlinks = graph.getBacklinks('Page2');
      expect(backlinks.contains('Page1'), true);
    });

    test('searches content across pages', () {
      final graph = LogseqGraph(rootPath: '/path/to/graph');

      final page1 = Page(name: 'Page1');
      page1.addBlock(Block(content: 'Important information'));

      final page2 = Page(name: 'Page2');
      page2.addBlock(Block(content: 'Other content'));
      page2.addBlock(Block(content: 'More important info'));

      graph.addPage(page1);
      graph.addPage(page2);

      final results = graph.searchContent('important');
      expect(results.length, 2);
    });

    test('gets statistics', () {
      final graph = LogseqGraph(rootPath: '/path/to/graph');

      final page = Page(name: 'Test');
      page.addBlock(Block(content: 'TODO Task'));
      page.addBlock(Block(content: 'DONE Task'));
      page.addBlock(Block(content: '```dart\ncode\n```'));

      graph.addPage(page);

      final stats = graph.getStatistics();
      expect(stats['totalPages'], 1);
      expect(stats['totalBlocks'], 3);
      expect(stats['taskBlocks'], 2);
      expect(stats['completedTasks'], 1);
      expect(stats['codeBlocks'], 1);
    });

    test('gets workflow summary', () {
      final graph = LogseqGraph(rootPath: '/path/to/graph');

      final page = Page(name: 'Tasks');
      page.addBlock(Block(content: 'TODO Task 1'));
      page.addBlock(Block(content: 'DONE Task 2'));
      page.addBlock(Block(content: 'DOING Task 3'));

      graph.addPage(page);

      final workflow = graph.getWorkflowSummary();
      expect(workflow['totalTasks'], 3);
      expect(workflow['taskStates']['TODO'], 1);
      expect(workflow['taskStates']['DONE'], 1);
      expect(workflow['taskStates']['DOING'], 1);
    });
  });

  group('LogseqUtils', () {
    test('identifies journal pages', () {
      expect(LogseqUtils.isJournalPage('2024-01-15'), true);
      expect(LogseqUtils.isJournalPage('2024_01_15'), true);
      expect(LogseqUtils.isJournalPage('Regular Page'), false);
    });

    test('formats date for journal', () {
      final date = DateTime(2024, 1, 15);
      final formatted = LogseqUtils.formatDateForJournal(date);
      expect(formatted, '2024-01-15');
    });

    test('cleans block content', () {
      expect(LogseqUtils.cleanBlockContent('- Test'), 'Test');
      expect(LogseqUtils.cleanBlockContent('* Test'), 'Test');
      expect(LogseqUtils.cleanBlockContent('+ Test'), 'Test');
      expect(LogseqUtils.cleanBlockContent('1. Test'), 'Test');
    });

    test('gets block level', () {
      expect(LogseqUtils.getBlockLevel('- Test'), 0);
      expect(LogseqUtils.getBlockLevel('  - Test'), 1);
      expect(LogseqUtils.getBlockLevel('    - Test'), 2);
    });

    test('ensures valid page name', () {
      expect(LogseqUtils.ensureValidPageName('Valid Name'), 'Valid Name');
      expect(LogseqUtils.ensureValidPageName('Invalid:Name'), 'Invalid_Name');
      expect(LogseqUtils.ensureValidPageName(''), 'Untitled');
    });

    test('extracts video URLs', () {
      final text = '''
        Check out https://www.youtube.com/watch?v=dQw4w9WgXcQ
        and https://vimeo.com/123456789
        also regular https://example.com
      ''';

      final urls = LogseqUtils.extractVideoUrls(text);
      expect(urls.length, 2);
      expect(urls.any((url) => url.contains('youtube')), true);
      expect(urls.any((url) => url.contains('vimeo')), true);
      expect(urls.any((url) => url.contains('example.com')), false);
    });
  });

  group('QueryBuilder', () {
    late LogseqGraph graph;

    setUp(() {
      graph = LogseqGraph(rootPath: '/test');

      final page1 = Page(name: 'Page1');
      page1.addBlock(Block(content: 'TODO High priority task [#A]'));
      page1.addBlock(Block(content: 'Regular content #tag1'));
      page1.addBlock(Block(content: 'DONE Completed task'));

      final page2 = Page(name: 'Page2');
      page2.addBlock(Block(content: '```dart\ncode\n```'));
      page2.addBlock(Block(content: 'TODO Another task #tag2'));

      graph.addPage(page1);
      graph.addPage(page2);
    });

    test('filters by content', () {
      final results = QueryBuilder(graph)
          .blocks()
          .contentContains('task')
          .execute();

      expect(results.length, 3);
    });

    test('filters by tag', () {
      final results = QueryBuilder(graph)
          .blocks()
          .hasTag('tag1')
          .execute();

      expect(results.length, 1);
    });

    test('filters by task state', () {
      final results = QueryBuilder(graph)
          .blocks()
          .hasTaskState(TaskState.todo)
          .execute();

      expect(results.length, 2);
    });

    test('filters completed tasks', () {
      final results = QueryBuilder(graph)
          .blocks()
          .isCompletedTask()
          .execute();

      expect(results.length, 1);
    });

    test('filters code blocks', () {
      final results = QueryBuilder(graph)
          .blocks()
          .isCodeBlock()
          .execute();

      expect(results.length, 1);
    });

    test('filters by priority', () {
      final results = QueryBuilder(graph)
          .blocks()
          .hasPriority(Priority.a)
          .execute();

      expect(results.length, 1);
    });

    test('chains multiple filters', () {
      final results = QueryBuilder(graph)
          .blocks()
          .isTask()
          .hasTaskState(TaskState.todo)
          .execute();

      expect(results.length, 2);
    });

    test('limits results', () {
      final results = QueryBuilder(graph)
          .blocks()
          .limit(2)
          .execute();

      expect(results.length, 2);
    });

    test('counts results', () {
      final count = QueryBuilder(graph)
          .blocks()
          .isTask()
          .count();

      expect(count, 3);
    });

    test('gets first result', () {
      final result = QueryBuilder(graph)
          .blocks()
          .hasTag('tag1')
          .first();

      expect(result, isNotNull);
      expect((result as Block).tags.contains('tag1'), true);
    });

    test('checks if results exist', () {
      final exists1 = QueryBuilder(graph)
          .blocks()
          .hasTag('tag1')
          .exists();

      final exists2 = QueryBuilder(graph)
          .blocks()
          .hasTag('nonexistent')
          .exists();

      expect(exists1, true);
      expect(exists2, false);
    });

    test('queries pages instead of blocks', () {
      final results = QueryBuilder(graph)
          .pages()
          .execute();

      expect(results.length, 2);
      expect(results.every((r) => r is Page), true);
    });
  });

  group('AdvancedModels', () {
    test('BlockEmbed creation and JSON', () {
      final embed = BlockEmbed(
        blockId: 'test-id',
        contentPreview: 'Preview',
        embedType: 'block',
      );

      final json = embed.toJson();
      final restored = BlockEmbed.fromJson(json);

      expect(restored.blockId, embed.blockId);
      expect(restored.contentPreview, embed.contentPreview);
      expect(restored.embedType, embed.embedType);
    });

    test('ScheduledDate creation and JSON', () {
      final scheduled = ScheduledDate(
        date: DateTime(2024, 1, 15),
        time: '10:00',
        repeater: '+1w',
      );

      final json = scheduled.toJson();
      final restored = ScheduledDate.fromJson(json);

      expect(restored.time, scheduled.time);
      expect(restored.repeater, scheduled.repeater);
    });

    test('Template creation and JSON', () {
      final template = Template(
        name: 'Test Template',
        content: 'Content with {{variable}}',
        variables: ['variable'],
        templateType: 'page',
      );

      final json = template.toJson();
      final restored = Template.fromJson(json);

      expect(restored.name, template.name);
      expect(restored.variables, template.variables);
    });
  });

  group('Integration', () {
    test('complete workflow example', () {
      // Create a graph
      final graph = LogseqGraph(rootPath: '/test');

      // Create pages with various content
      final tasksPage = Page(name: 'Tasks');
      tasksPage.addBlock(Block(content: 'TODO Review PR [#A]'));
      tasksPage.addBlock(Block(content: 'DOING Write tests [#B]'));
      tasksPage.addBlock(Block(content: 'DONE Deploy app [#C]'));

      final notesPage = Page(name: 'Notes');
      notesPage.addBlock(Block(content: 'Important #meeting notes'));
      notesPage.addBlock(Block(content: 'Link to [[Tasks]]'));

      graph.addPage(tasksPage);
      graph.addPage(notesPage);

      // Query high-priority incomplete tasks
      final urgentTasks = QueryBuilder(graph)
          .blocks()
          .isTask()
          .hasPriority(Priority.a)
          .customFilter((block) => (block as Block).taskState != TaskState.done)
          .execute();

      expect(urgentTasks.length, 1);

      // Get all tasks
      final allTasks = graph.getTaskBlocks();
      expect(allTasks.length, 3);

      // Get statistics
      final stats = graph.getStatistics();
      expect(stats['taskBlocks'], 3);
      expect(stats['completedTasks'], 1);

      // Search across pages
      final searchResults = graph.searchContent('tests');
      expect(searchResults.containsKey('Tasks'), true);
    });
  });
}

