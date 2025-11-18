/// Page model for Logseq
library;

import 'package:equatable/equatable.dart';
import 'block.dart';
import 'enums.dart';
import 'advanced_models.dart';

/// Represents a page in Logseq
class Page extends Equatable {
  final String name;
  String title;
  String? filePath;
  final List<Block> blocks;
  final Map<String, dynamic> properties;
  final Set<String> tags;
  final Set<String> links;
  final Set<String> backlinks;
  bool isJournal;
  DateTime? journalDate;
  DateTime? createdAt;
  DateTime? updatedAt;

  // Advanced Logseq features
  String? namespace; // e.g., "project/backend" -> namespace="project"
  bool isWhiteboard;
  Map<String, dynamic>? whiteboardData;

  // Templates
  final List<Template> templates;
  bool isTemplate;

  // PDF and annotations
  String? pdfPath;
  final List<Annotation> annotations;

  // Plugin and theme data
  final Map<String, dynamic> pluginData;

  // Page hierarchy and aliases
  final Set<String> aliases;
  final Set<String> parentPages;
  final Set<String> childPages;

  Page({
    required this.name,
    String? title,
    this.filePath,
    List<Block>? blocks,
    Map<String, dynamic>? properties,
    Set<String>? tags,
    Set<String>? links,
    Set<String>? backlinks,
    this.isJournal = false,
    this.journalDate,
    this.createdAt,
    this.updatedAt,
    this.namespace,
    this.isWhiteboard = false,
    this.whiteboardData,
    List<Template>? templates,
    this.isTemplate = false,
    this.pdfPath,
    List<Annotation>? annotations,
    Map<String, dynamic>? pluginData,
    Set<String>? aliases,
    Set<String>? parentPages,
    Set<String>? childPages,
  })  : title = title ?? name,
        blocks = blocks ?? [],
        properties = properties ?? {},
        tags = tags ?? {},
        links = links ?? {},
        backlinks = backlinks ?? {},
        templates = templates ?? [],
        annotations = annotations ?? [],
        pluginData = pluginData ?? {},
        aliases = aliases ?? {},
        parentPages = parentPages ?? {},
        childPages = childPages ?? {} {
    _extractPageData();
    _extractNamespace();
    _extractAliases();
    _detectSpecialPages();
  }

  @override
  List<Object?> get props => [
        name,
        title,
        filePath,
        blocks,
        properties,
        tags,
        links,
        backlinks,
        isJournal,
        journalDate,
        createdAt,
        updatedAt,
        namespace,
        isWhiteboard,
        whiteboardData,
        templates,
        isTemplate,
        pdfPath,
        annotations,
        pluginData,
        aliases,
        parentPages,
        childPages,
      ];

  /// Extract tags and links from all blocks
  void _extractPageData() {
    for (final block in blocks) {
      tags.addAll(block.tags);
      links.addAll(block.getLinks());
    }
  }

  /// Add a block to the page
  void addBlock(Block block) {
    block.pageName = name;
    blocks.add(block);
    tags.addAll(block.tags);
    links.addAll(block.getLinks());
  }

  /// Get a block by its ID
  Block? getBlockById(String blockId) {
    try {
      return blocks.firstWhere((block) => block.id == blockId);
    } catch (_) {
      return null;
    }
  }

  /// Find blocks containing specific text
  List<Block> getBlocksByContent(String searchText,
      {bool caseSensitive = false}) {
    final results = <Block>[];
    final search = caseSensitive ? searchText : searchText.toLowerCase();

    for (final block in blocks) {
      final content =
          caseSensitive ? block.content : block.content.toLowerCase();
      if (content.contains(search)) {
        results.add(block);
      }
    }

    return results;
  }

  /// Find blocks with a specific tag
  List<Block> getBlocksByTag(String tag) {
    return blocks.where((block) => block.tags.contains(tag)).toList();
  }

  /// Extract namespace from page name
  void _extractNamespace() {
    if (name.contains('/')) {
      final parts = name.split('/');
      if (parts.length > 1) {
        namespace = parts[0];
      }
    }
  }

  /// Extract aliases from page properties
  void _extractAliases() {
    if (properties.containsKey('alias')) {
      final aliasValue = properties['alias'];
      if (aliasValue is String) {
        // Handle [[alias1]] [[alias2]] format
        if (aliasValue.contains('[[')) {
          final aliasMatches = RegExp(r'\[\[([^\]]+)\]\]').allMatches(aliasValue);
          aliases.addAll(aliasMatches.map((m) => m.group(1)!));
        } else {
          // Handle comma-separated
          aliases
              .addAll(aliasValue.split(',').map((a) => a.trim()).where((a) => a.isNotEmpty));
        }
      } else if (aliasValue is List) {
        aliases.addAll(aliasValue.cast<String>());
      }
    }
  }

  /// Detect special page types
  void _detectSpecialPages() {
    // Template pages
    if (properties.containsKey('template') ||
        name.toLowerCase().startsWith('template')) {
      isTemplate = true;
      _extractTemplates();
    }

    // Whiteboard pages
    if (name.endsWith('.whiteboard') || properties.containsKey('whiteboard')) {
      isWhiteboard = true;
    }
  }

  /// Extract template information from template pages
  void _extractTemplates() {
    if (!isTemplate) return;

    final templateContent = blocks.map((block) => block.content).join('\n');

    // Extract template variables {{variable}}
    final variables =
        RegExp(r'\{\{([^}]+)\}\}').allMatches(templateContent).map((m) => m.group(1)!).toSet().toList();

    final template = Template(
      name: name,
      content: templateContent,
      variables: variables,
      templateType: 'page',
    );
    templates.add(template);
  }

  /// Get all task blocks in this page
  List<Block> getTaskBlocks() {
    return blocks.where((block) => block.isTask()).toList();
  }

  /// Get all completed task blocks
  List<Block> getCompletedTasks() {
    return blocks.where((block) => block.isCompletedTask()).toList();
  }

  /// Get all scheduled blocks
  List<Block> getScheduledBlocks() {
    return blocks.where((block) => block.isScheduled()).toList();
  }

  /// Get all blocks with deadlines
  List<Block> getBlocksWithDeadline() {
    return blocks.where((block) => block.hasDeadline()).toList();
  }

  /// Get blocks with specific priority
  List<Block> getBlocksByPriority(Priority priority) {
    return blocks.where((block) => block.priority == priority).toList();
  }

  /// Get all query blocks
  List<Block> getQueryBlocks() {
    return blocks.where((block) => block.query != null).toList();
  }

  /// Get code blocks, optionally filtered by language
  List<Block> getCodeBlocks({String? language}) {
    var codeBlocks =
        blocks.where((block) => block.blockType == BlockType.code).toList();
    if (language != null) {
      return codeBlocks
          .where((block) => block.codeLanguage == language)
          .toList();
    }
    return codeBlocks;
  }

  /// Get blocks containing LaTeX/math content
  List<Block> getMathBlocks() {
    return blocks.where((block) => block.latexContent != null).toList();
  }

  /// Get heading blocks, optionally filtered by level
  List<Block> getHeadingBlocks({int? level}) {
    var headingBlocks =
        blocks.where((block) => block.blockType == BlockType.heading).toList();
    if (level != null) {
      return headingBlocks
          .where((block) => block.headingLevel == level)
          .toList();
    }
    return headingBlocks;
  }

  /// Generate a hierarchical outline of the page
  Map<String, dynamic> getPageOutline() {
    return {
      'title': title,
      'headings': getHeadingBlocks()
          .map((block) => {
                'level': block.headingLevel,
                'text': block.content,
                'id': block.id,
              })
          .toList(),
      'tasks': {
        'total': getTaskBlocks().length,
        'completed': getCompletedTasks().length,
        'scheduled': getScheduledBlocks().length,
      },
      'blocks': {
        'total': blocks.length,
        'code': getCodeBlocks().length,
        'queries': getQueryBlocks().length,
        'math': getMathBlocks().length,
      }
    };
  }

  /// Check if this page is a namespace root
  bool isNamespaceRoot() {
    return namespace == null && !name.contains('/');
  }

  /// Convert page to Logseq markdown format
  String toMarkdown() {
    final lines = <String>[];

    // Add page properties if any
    if (properties.isNotEmpty) {
      for (final entry in properties.entries) {
        lines.add('${entry.key}:: ${entry.value}');
      }
      lines.add(''); // Empty line after properties
    }

    // Add aliases if any
    if (aliases.isNotEmpty) {
      final aliasStr = aliases.map((alias) => '[[$alias]]').join(', ');
      lines.add('alias:: $aliasStr');
      lines.add('');
    }

    // Add blocks
    for (final block in blocks) {
      lines.add(block.toMarkdown());
    }

    return lines.join('\n');
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'title': title,
        'filePath': filePath,
        'blocks': blocks.map((b) => b.toJson()).toList(),
        'properties': properties,
        'tags': tags.toList(),
        'links': links.toList(),
        'backlinks': backlinks.toList(),
        'isJournal': isJournal,
        'journalDate': journalDate?.toIso8601String(),
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'namespace': namespace,
        'isWhiteboard': isWhiteboard,
        'whiteboardData': whiteboardData,
        'isTemplate': isTemplate,
        'pdfPath': pdfPath,
        'aliases': aliases.toList(),
      };

  factory Page.fromJson(Map<String, dynamic> json) => Page(
        name: json['name'] as String,
        title: json['title'] as String?,
        filePath: json['filePath'] as String?,
        blocks: (json['blocks'] as List<dynamic>?)
                ?.map((b) => Block.fromJson(b as Map<String, dynamic>))
                .toList() ??
            [],
        properties: (json['properties'] as Map<String, dynamic>?) ?? {},
        tags: (json['tags'] as List<dynamic>?)?.cast<String>().toSet() ?? {},
        links: (json['links'] as List<dynamic>?)?.cast<String>().toSet() ?? {},
        backlinks:
            (json['backlinks'] as List<dynamic>?)?.cast<String>().toSet() ?? {},
        isJournal: json['isJournal'] as bool? ?? false,
        journalDate: json['journalDate'] != null
            ? DateTime.parse(json['journalDate'] as String)
            : null,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : null,
        namespace: json['namespace'] as String?,
        isWhiteboard: json['isWhiteboard'] as bool? ?? false,
        whiteboardData: json['whiteboardData'] as Map<String, dynamic>?,
        isTemplate: json['isTemplate'] as bool? ?? false,
        pdfPath: json['pdfPath'] as String?,
        aliases:
            (json['aliases'] as List<dynamic>?)?.cast<String>().toSet() ?? {},
      );
}
