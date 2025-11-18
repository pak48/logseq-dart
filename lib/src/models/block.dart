/// Block model for Logseq
library;

import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import 'enums.dart';
import 'advanced_models.dart';

/// Represents a single block in Logseq
class Block extends Equatable {
  final String id;
  String content;
  final int level; // Indentation level (0 = top-level)
  String? parentId;
  final List<String> childrenIds;
  final Map<String, dynamic> properties;
  final Set<String> tags;
  String? pageName;
  DateTime? createdAt;
  DateTime? updatedAt;

  // Advanced Logseq features
  TaskState? taskState;
  Priority? priority;
  ScheduledDate? scheduled;
  ScheduledDate? deadline;
  BlockType blockType;
  bool collapsed;
  int? headingLevel; // 1-6 for headings

  // Block references and embeds
  final Set<String> referencedBlocks;
  final List<BlockEmbed> embeddedBlocks;

  // Advanced content types
  LogseqQuery? query;
  String? latexContent;
  String? codeLanguage;

  // Drawing and whiteboard
  Map<String, dynamic>? drawingData;
  final List<WhiteboardElement> whiteboardElements;

  // Annotations and highlights
  final List<Annotation> annotations;

  // Plugin data
  final Map<String, dynamic> pluginData;

  Block({
    String? id,
    this.content = '',
    this.level = 0,
    this.parentId,
    List<String>? childrenIds,
    Map<String, dynamic>? properties,
    Set<String>? tags,
    this.pageName,
    this.createdAt,
    this.updatedAt,
    this.taskState,
    this.priority,
    this.scheduled,
    this.deadline,
    this.blockType = BlockType.bullet,
    this.collapsed = false,
    this.headingLevel,
    Set<String>? referencedBlocks,
    List<BlockEmbed>? embeddedBlocks,
    this.query,
    this.latexContent,
    this.codeLanguage,
    this.drawingData,
    List<WhiteboardElement>? whiteboardElements,
    List<Annotation>? annotations,
    Map<String, dynamic>? pluginData,
  })  : id = id ?? const Uuid().v4(),
        childrenIds = childrenIds ?? [],
        properties = properties ?? {},
        tags = tags ?? {},
        referencedBlocks = referencedBlocks ?? {},
        embeddedBlocks = embeddedBlocks ?? [],
        whiteboardElements = whiteboardElements ?? [],
        annotations = annotations ?? [],
        pluginData = pluginData ?? {} {
    _extractTags();
    _extractProperties();
    _extractTaskInfo();
    _extractScheduledDates();
    _extractBlockReferences();
    _detectContentType();
  }

  @override
  List<Object?> get props => [
        id,
        content,
        level,
        parentId,
        childrenIds,
        properties,
        tags,
        pageName,
        createdAt,
        updatedAt,
        taskState,
        priority,
        scheduled,
        deadline,
        blockType,
        collapsed,
        headingLevel,
        referencedBlocks,
        embeddedBlocks,
        query,
        latexContent,
        codeLanguage,
        drawingData,
        whiteboardElements,
        annotations,
        pluginData,
      ];

  /// Extract tags from content
  void _extractTags() {
    final tagPattern = RegExp(r'(?:^|\s)#([a-zA-Z0-9_-]+)(?:\s|$|[.,;!?])');
    final matches = tagPattern.allMatches(content);
    tags.addAll(matches.map((m) => m.group(1)!));
  }

  /// Extract properties from content (key:: value format)
  void _extractProperties() {
    final propPattern = RegExp(r'^([a-zA-Z0-9_-]+)::\s*(.+)$', multiLine: true);
    final matches = propPattern.allMatches(content);

    for (final match in matches) {
      final key = match.group(1)!.toLowerCase();
      final value = match.group(2)!.trim();
      properties[key] = value;
    }
  }

  /// Add a child block
  void addChild(Block childBlock) {
    if (!childrenIds.contains(childBlock.id)) {
      childrenIds.add(childBlock.id);
      childBlock.parentId = id;
    }
  }

  /// Extract page links from content
  Set<String> getLinks() {
    final linkPattern = RegExp(r'\[\[([^\]]+)\]\]');
    final matches = linkPattern.allMatches(content);
    return matches.map((m) => m.group(1)!).toSet();
  }

  /// Extract block references from content
  Set<String> getBlockReferences() {
    final refPattern = RegExp(r'\(\(([^)]+)\)\)');
    final matches = refPattern.allMatches(content);
    return matches.map((m) => m.group(1)!).toSet();
  }

  /// Extract task state and priority from content
  void _extractTaskInfo() {
    // Extract task state
    final taskPattern = RegExp(
        r'^(TODO|DOING|DONE|LATER|NOW|WAITING|CANCELLED|DELEGATED|IN-PROGRESS)\s+');
    final taskMatch = taskPattern.firstMatch(content);
    if (taskMatch != null) {
      taskState = TaskState.fromString(taskMatch.group(1)!);
      // Remove task state from content for cleaner processing
      content = content.replaceFirst(taskPattern, '');
    }

    // Extract priority [#A], [#B], [#C]
    final priorityPattern = RegExp(r'\[#([ABC])\]');
    final priorityMatch = priorityPattern.firstMatch(content);
    if (priorityMatch != null) {
      priority = Priority.fromString(priorityMatch.group(1)!);
      // Remove priority from content
      content = content.replaceAll(priorityPattern, '').trim();
    }
  }

  /// Extract SCHEDULED and DEADLINE dates
  void _extractScheduledDates() {
    // SCHEDULED: <2024-01-15 Mon 10:00 +1w>
    final scheduledPattern = RegExp(r'SCHEDULED:\s*<([^>]+)>');
    final scheduledMatch = scheduledPattern.firstMatch(content);
    if (scheduledMatch != null) {
      scheduled = _parseLogseqDate(scheduledMatch.group(1)!);
    }

    // DEADLINE: <2024-01-20 Sat>
    final deadlinePattern = RegExp(r'DEADLINE:\s*<([^>]+)>');
    final deadlineMatch = deadlinePattern.firstMatch(content);
    if (deadlineMatch != null) {
      deadline = _parseLogseqDate(deadlineMatch.group(1)!);
    }
  }

  /// Parse Logseq date format
  ScheduledDate? _parseLogseqDate(String dateStr) {
    try {
      final parts = dateStr.split(' ');
      if (parts.isEmpty) return null;

      final datePart = parts[0];
      final parsedDate = DateTime.parse(datePart);

      String? timePart;
      String? repeater;

      if (parts.length > 2) {
        timePart = parts[2];
      }

      // Look for repeater (+1w, +3d, etc.)
      final repeaterMatch = RegExp(r'([+-]\d+[dwmy])').firstMatch(dateStr);
      if (repeaterMatch != null) {
        repeater = repeaterMatch.group(1);
      }

      return ScheduledDate(date: parsedDate, time: timePart, repeater: repeater);
    } catch (_) {
      return null;
    }
  }

  /// Extract block references and embeds
  void _extractBlockReferences() {
    // Block references ((block-id))
    final refPattern = RegExp(r'\(\(([^)]+)\)\)');
    final matches = refPattern.allMatches(content);
    referencedBlocks.addAll(matches.map((m) => m.group(1)!));

    // Block embeds {{embed ((block-id))}}
    final embedPattern = RegExp(r'\{\{embed\s+\(\(([^)]+)\)\)\}\}');
    final embedMatches = embedPattern.allMatches(content);
    for (final match in embedMatches) {
      embeddedBlocks.add(BlockEmbed(blockId: match.group(1)!, embedType: 'block'));
    }

    // Page embeds {{embed [[Page Name]]}}
    final pageEmbedPattern = RegExp(r'\{\{embed\s+\[\[([^\]]+)\]\]\}\}');
    final pageEmbedMatches = pageEmbedPattern.allMatches(content);
    for (final match in pageEmbedMatches) {
      embeddedBlocks.add(BlockEmbed(blockId: match.group(1)!, embedType: 'page'));
    }
  }

  /// Detect special content types
  void _detectContentType() {
    final contentLower = content.toLowerCase().trim();

    // Query blocks
    if (contentLower.startsWith('{{query') ||
        contentLower.startsWith('#+begin_query')) {
      _extractQuery();
    }

    // LaTeX/Math blocks
    if (content.contains(r'$$') || content.contains(r'\(')) {
      latexContent = _extractLatex();
    }

    // Code blocks
    if (content.startsWith('```') || contentLower.startsWith('#+begin_src')) {
      _extractCodeInfo();
    }

    // Heading detection
    if (content.startsWith('#')) {
      final leadingHashes = content.indexOf(RegExp(r'[^#]'));
      if (leadingHashes > 0) {
        headingLevel = leadingHashes;
        blockType = BlockType.heading;
      }
    }
  }

  /// Extract query information from query blocks
  void _extractQuery() {
    // Simple query: {{query "search term"}}
    final simplePattern = RegExp(r'\{\{query\s+"([^"]+)"\s*\}\}');
    final simpleMatch = simplePattern.firstMatch(content);
    if (simpleMatch != null) {
      query = LogseqQuery(
          queryString: simpleMatch.group(1)!, queryType: 'simple');
      return;
    }

    // Advanced query block
    if (content.toLowerCase().contains('#+begin_query')) {
      final queryContent =
          RegExp(r'\+\+begin_query([\s\S]*?)\+\+end_query', caseSensitive: false)
              .firstMatch(content);
      if (queryContent != null) {
        query = LogseqQuery(
            queryString: queryContent.group(1)!.trim(), queryType: 'advanced');
      }
    }
  }

  /// Extract LaTeX content
  String? _extractLatex() {
    // Extract content between $$ or \( \)
    final latexPatterns = [
      RegExp(r'\$\$([^$]+)\$\$'),
      RegExp(r'\\\(([^)]+)\\\)')
    ];

    for (final pattern in latexPatterns) {
      final match = pattern.firstMatch(content);
      if (match != null) {
        return match.group(1)!.trim();
      }
    }
    return null;
  }

  /// Extract code language from code blocks
  void _extractCodeInfo() {
    // ```python or #+begin_src python
    final patterns = [
      RegExp(r'```(\w+)'),
      RegExp(r'\+\+begin_src\s+(\w+)', caseSensitive: false)
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(content);
      if (match != null) {
        codeLanguage = match.group(1);
        blockType = BlockType.code;
        break;
      }
    }
  }

  /// Check if this block is a task
  bool isTask() => taskState != null;

  /// Check if this is a completed task
  bool isCompletedTask() => taskState == TaskState.done;

  /// Check if this block is scheduled
  bool isScheduled() => scheduled != null;

  /// Check if this block has a deadline
  bool hasDeadline() => deadline != null;

  /// Get all dates associated with this block
  List<DateTime> getAllDates() {
    final dates = <DateTime>[];
    if (scheduled != null) dates.add(scheduled!.date);
    if (deadline != null) dates.add(deadline!.date);
    return dates;
  }

  /// Convert block to Logseq markdown format
  String toMarkdown() {
    final indent = '  ' * level;
    final prefix = '- ';

    var blockContent = content;
    if (taskState != null) {
      blockContent = '${taskState!.value} $blockContent';
    }

    if (priority != null) {
      blockContent = '[#${priority!.value}] $blockContent';
    }

    return '$indent$prefix$blockContent';
  }

  /// Create a copy of this block with updated fields
  Block copyWith({
    String? id,
    String? content,
    int? level,
    String? parentId,
    List<String>? childrenIds,
    Map<String, dynamic>? properties,
    Set<String>? tags,
    String? pageName,
    DateTime? createdAt,
    DateTime? updatedAt,
    TaskState? taskState,
    Priority? priority,
    ScheduledDate? scheduled,
    ScheduledDate? deadline,
    BlockType? blockType,
    bool? collapsed,
    int? headingLevel,
  }) {
    return Block(
      id: id ?? this.id,
      content: content ?? this.content,
      level: level ?? this.level,
      parentId: parentId ?? this.parentId,
      childrenIds: childrenIds ?? List.from(this.childrenIds),
      properties: properties ?? Map.from(this.properties),
      tags: tags ?? Set.from(this.tags),
      pageName: pageName ?? this.pageName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      taskState: taskState ?? this.taskState,
      priority: priority ?? this.priority,
      scheduled: scheduled ?? this.scheduled,
      deadline: deadline ?? this.deadline,
      blockType: blockType ?? this.blockType,
      collapsed: collapsed ?? this.collapsed,
      headingLevel: headingLevel ?? this.headingLevel,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'level': level,
        'parentId': parentId,
        'childrenIds': childrenIds,
        'properties': properties,
        'tags': tags.toList(),
        'pageName': pageName,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'taskState': taskState?.value,
        'priority': priority?.value,
        'scheduled': scheduled?.toJson(),
        'deadline': deadline?.toJson(),
        'blockType': blockType.value,
        'collapsed': collapsed,
        'headingLevel': headingLevel,
      };

  factory Block.fromJson(Map<String, dynamic> json) => Block(
        id: json['id'] as String?,
        content: json['content'] as String? ?? '',
        level: json['level'] as int? ?? 0,
        parentId: json['parentId'] as String?,
        childrenIds:
            (json['childrenIds'] as List<dynamic>?)?.cast<String>() ?? [],
        properties: (json['properties'] as Map<String, dynamic>?) ?? {},
        tags: (json['tags'] as List<dynamic>?)?.cast<String>().toSet() ?? {},
        pageName: json['pageName'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : null,
        taskState: json['taskState'] != null
            ? TaskState.fromString(json['taskState'] as String)
            : null,
        priority: json['priority'] != null
            ? Priority.fromString(json['priority'] as String)
            : null,
        scheduled: json['scheduled'] != null
            ? ScheduledDate.fromJson(json['scheduled'] as Map<String, dynamic>)
            : null,
        deadline: json['deadline'] != null
            ? ScheduledDate.fromJson(json['deadline'] as Map<String, dynamic>)
            : null,
        blockType: BlockType.fromString(json['blockType'] as String? ?? 'bullet') ??
            BlockType.bullet,
        collapsed: json['collapsed'] as bool? ?? false,
        headingLevel: json['headingLevel'] as int?,
      );
}
