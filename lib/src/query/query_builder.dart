/// Query builder for advanced Logseq data queries
library;

import '../models/block.dart';
import '../models/page.dart';
import '../models/graph.dart';
import '../models/enums.dart';

/// Builder class for constructing complex queries against Logseq data
class QueryBuilder {
  final LogseqGraph graph;
  final List<bool Function(dynamic)> _filters = [];
  String _target = 'blocks'; // 'blocks' or 'pages'
  String? _sortBy;
  bool _sortDesc = false;
  int? _limit;

  QueryBuilder(this.graph);

  /// Query pages instead of blocks
  QueryBuilder pages() {
    _target = 'pages';
    return this;
  }

  /// Query blocks (default behavior)
  QueryBuilder blocks() {
    _target = 'blocks';
    return this;
  }

  /// Filter by content containing specific text
  QueryBuilder contentContains(String text, {bool caseSensitive = false}) {
    final searchText = caseSensitive ? text : text.toLowerCase();
    _filters.add((item) {
      if (item is! dynamic) return false;
      final content = _getContent(item);
      final searchContent =
          caseSensitive ? content : content.toLowerCase();
      return searchContent.contains(searchText);
    });
    return this;
  }

  /// Filter by content matching a regex pattern
  QueryBuilder contentMatches(Pattern pattern) {
    _filters.add((item) {
      final content = _getContent(item);
      return pattern.allMatches(content).isNotEmpty;
    });
    return this;
  }

  /// Filter by items containing a specific tag
  QueryBuilder hasTag(String tag) {
    _filters.add((item) {
      final tags = _getTags(item);
      return tags.contains(tag);
    });
    return this;
  }

  /// Filter by items containing any of the specified tags
  QueryBuilder hasAnyTag(List<String> tags) {
    final tagSet = tags.toSet();
    _filters.add((item) {
      final itemTags = _getTags(item);
      return tagSet.intersection(itemTags).isNotEmpty;
    });
    return this;
  }

  /// Filter by items containing all of the specified tags
  QueryBuilder hasAllTags(List<String> tags) {
    final tagSet = tags.toSet();
    _filters.add((item) {
      final itemTags = _getTags(item);
      return tagSet.difference(itemTags).isEmpty;
    });
    return this;
  }

  /// Filter by items having a specific property
  QueryBuilder hasProperty(String key, [String? value]) {
    _filters.add((item) {
      final properties = _getProperties(item);
      if (!properties.containsKey(key.toLowerCase())) return false;
      if (value == null) return true;
      return properties[key.toLowerCase()].toString().toLowerCase() ==
          value.toLowerCase();
    });
    return this;
  }

  /// Filter by items that link to a specific page
  QueryBuilder linksTo(String pageName) {
    _filters.add((item) {
      if (item is Block) {
        return item.getLinks().contains(pageName);
      } else if (item is Page) {
        return item.links.contains(pageName);
      }
      return false;
    });
    return this;
  }

  /// Filter blocks that are in a specific page
  QueryBuilder inPage(String pageName) {
    _filters.add((item) {
      if (item is Block) {
        return item.pageName == pageName;
      }
      return false;
    });
    return this;
  }

  /// Filter by journal pages
  QueryBuilder isJournal([bool isJournal = true]) {
    _filters.add((item) {
      if (item is Page) {
        return item.isJournal == isJournal;
      }
      return false;
    });
    return this;
  }

  /// Filter by items created after a specific date
  QueryBuilder createdAfter(DateTime date) {
    _filters.add((item) {
      final createdAt = _getCreatedAt(item);
      return createdAt != null && createdAt.isAfter(date);
    });
    return this;
  }

  /// Filter by items created before a specific date
  QueryBuilder createdBefore(DateTime date) {
    _filters.add((item) {
      final createdAt = _getCreatedAt(item);
      return createdAt != null && createdAt.isBefore(date);
    });
    return this;
  }

  /// Filter by items updated after a specific date
  QueryBuilder updatedAfter(DateTime date) {
    _filters.add((item) {
      final updatedAt = _getUpdatedAt(item);
      return updatedAt != null && updatedAt.isAfter(date);
    });
    return this;
  }

  /// Filter blocks by indentation level
  QueryBuilder level(int level) {
    _filters.add((item) {
      if (item is Block) {
        return item.level == level;
      }
      return false;
    });
    return this;
  }

  /// Filter blocks by minimum indentation level
  QueryBuilder minLevel(int level) {
    _filters.add((item) {
      if (item is Block) {
        return item.level >= level;
      }
      return false;
    });
    return this;
  }

  /// Filter blocks by maximum indentation level
  QueryBuilder maxLevel(int level) {
    _filters.add((item) {
      if (item is Block) {
        return item.level <= level;
      }
      return false;
    });
    return this;
  }

  /// Filter blocks that have child blocks
  QueryBuilder hasChildren() {
    _filters.add((item) {
      if (item is Block) {
        return item.childrenIds.isNotEmpty;
      }
      return false;
    });
    return this;
  }

  /// Filter blocks that have no parent (top-level blocks)
  QueryBuilder isOrphan() {
    _filters.add((item) {
      if (item is Block) {
        return item.parentId == null;
      }
      return false;
    });
    return this;
  }

  /// Add a custom filter function
  QueryBuilder customFilter(bool Function(dynamic) filterFunc) {
    _filters.add(filterFunc);
    return this;
  }

  /// Sort results by a field
  QueryBuilder sortBy(String field, {bool desc = false}) {
    _sortBy = field;
    _sortDesc = desc;
    return this;
  }

  /// Limit the number of results
  QueryBuilder limit(int count) {
    _limit = count;
    return this;
  }

  // Logseq-specific query methods

  /// Filter by task state
  QueryBuilder hasTaskState(TaskState state) {
    _filters.add((item) {
      if (item is Block) {
        return item.taskState == state;
      }
      return false;
    });
    return this;
  }

  /// Filter items that are tasks
  QueryBuilder isTask() {
    _filters.add((item) {
      if (item is Block) {
        return item.isTask();
      }
      return false;
    });
    return this;
  }

  /// Filter completed tasks
  QueryBuilder isCompletedTask() {
    _filters.add((item) {
      if (item is Block) {
        return item.isCompletedTask();
      }
      return false;
    });
    return this;
  }

  /// Filter by priority level
  QueryBuilder hasPriority(Priority priority) {
    _filters.add((item) {
      if (item is Block) {
        return item.priority == priority;
      }
      return false;
    });
    return this;
  }

  /// Filter items that are scheduled
  QueryBuilder hasScheduledDate([DateTime? date]) {
    _filters.add((item) {
      if (item is Block) {
        if (!item.isScheduled()) return false;
        if (date == null) return true;
        return item.scheduled != null &&
            LogseqGraph.isSameDay(item.scheduled!.date, date);
      }
      return false;
    });
    return this;
  }

  /// Filter items that have deadlines
  QueryBuilder hasDeadline([DateTime? date]) {
    _filters.add((item) {
      if (item is Block) {
        if (!item.hasDeadline()) return false;
        if (date == null) return true;
        return item.deadline != null &&
            LogseqGraph.isSameDay(item.deadline!.date, date);
      }
      return false;
    });
    return this;
  }

  /// Filter by block type
  QueryBuilder hasBlockType(BlockType blockType) {
    _filters.add((item) {
      if (item is Block) {
        return item.blockType == blockType;
      }
      return false;
    });
    return this;
  }

  /// Filter heading blocks, optionally by level
  QueryBuilder isHeading([int? level]) {
    _filters.add((item) {
      if (item is Block) {
        if (item.blockType != BlockType.heading) return false;
        if (level == null) return true;
        return item.headingLevel == level;
      }
      return false;
    });
    return this;
  }

  /// Filter code blocks, optionally by programming language
  QueryBuilder isCodeBlock([String? language]) {
    _filters.add((item) {
      if (item is Block) {
        if (item.blockType != BlockType.code) return false;
        if (language == null) return true;
        return item.codeLanguage == language;
      }
      return false;
    });
    return this;
  }

  /// Filter blocks with LaTeX/mathematical content
  QueryBuilder hasMathContent() {
    _filters.add((item) {
      if (item is Block) {
        return item.latexContent != null;
      }
      return false;
    });
    return this;
  }

  /// Filter blocks that contain queries
  QueryBuilder hasQuery() {
    _filters.add((item) {
      if (item is Block) {
        return item.query != null;
      }
      return false;
    });
    return this;
  }

  /// Filter blocks that reference other blocks
  QueryBuilder hasBlockReferences() {
    _filters.add((item) {
      if (item is Block) {
        return item.referencedBlocks.isNotEmpty;
      }
      return false;
    });
    return this;
  }

  /// Filter blocks that embed other content
  QueryBuilder hasEmbeds() {
    _filters.add((item) {
      if (item is Block) {
        return item.embeddedBlocks.isNotEmpty;
      }
      return false;
    });
    return this;
  }

  /// Filter pages in a specific namespace
  QueryBuilder inNamespace(String namespace) {
    _filters.add((item) {
      if (item is Page) {
        return item.namespace == namespace;
      }
      return false;
    });
    return this;
  }

  /// Filter template pages
  QueryBuilder isTemplate() {
    _filters.add((item) {
      if (item is Page) {
        return item.isTemplate;
      }
      return false;
    });
    return this;
  }

  /// Filter whiteboard pages
  QueryBuilder isWhiteboard() {
    _filters.add((item) {
      if (item is Page) {
        return item.isWhiteboard;
      }
      return false;
    });
    return this;
  }

  /// Filter items with PDF annotations
  QueryBuilder hasAnnotations() {
    _filters.add((item) {
      if (item is Block) {
        return item.annotations.isNotEmpty;
      } else if (item is Page) {
        return item.annotations.isNotEmpty;
      }
      return false;
    });
    return this;
  }

  /// Filter collapsed blocks
  QueryBuilder isCollapsed() {
    _filters.add((item) {
      if (item is Block) {
        return item.collapsed;
      }
      return false;
    });
    return this;
  }

  /// Filter pages that have a specific alias
  QueryBuilder hasAlias(String alias) {
    _filters.add((item) {
      if (item is Page) {
        return item.aliases.contains(alias);
      }
      return false;
    });
    return this;
  }

  /// Execute the query and return results
  List<dynamic> execute() {
    // Get the items to query
    List<dynamic> items;
    if (_target == 'pages') {
      items = graph.pages.values.toList();
    } else {
      items = graph.blocks.values.toList();
    }

    // Apply filters
    for (final filter in _filters) {
      items = items.where(filter).toList();
    }

    // Apply sorting
    if (_sortBy != null) {
      items.sort((a, b) {
        final aValue = _getSortValue(a, _sortBy!);
        final bValue = _getSortValue(b, _sortBy!);

        if (aValue == null && bValue == null) return 0;
        if (aValue == null) return 1;
        if (bValue == null) return -1;

        final comparison = _compareValues(aValue, bValue);
        return _sortDesc ? -comparison : comparison;
      });
    }

    // Apply limit
    if (_limit != null && _limit! > 0) {
      items = items.take(_limit!).toList();
    }

    return items;
  }

  /// Count the number of matching items
  int count() => execute().length;

  /// Get the first matching item
  dynamic first() {
    final results = limit(1).execute();
    return results.isEmpty ? null : results.first;
  }

  /// Check if any items match the query
  bool exists() => count() > 0;

  // Helper methods

  String _getContent(dynamic item) {
    if (item is Block) return item.content;
    if (item is Page) return item.title;
    return '';
  }

  Set<String> _getTags(dynamic item) {
    if (item is Block) return item.tags;
    if (item is Page) return item.tags;
    return {};
  }

  Map<String, dynamic> _getProperties(dynamic item) {
    if (item is Block) return item.properties;
    if (item is Page) return item.properties;
    return {};
  }

  DateTime? _getCreatedAt(dynamic item) {
    if (item is Block) return item.createdAt;
    if (item is Page) return item.createdAt;
    return null;
  }

  DateTime? _getUpdatedAt(dynamic item) {
    if (item is Block) return item.updatedAt;
    if (item is Page) return item.updatedAt;
    return null;
  }

  dynamic _getSortValue(dynamic item, String field) {
    if (item is Block) {
      switch (field) {
        case 'content':
          return item.content;
        case 'level':
          return item.level;
        case 'createdAt':
          return item.createdAt;
        case 'updatedAt':
          return item.updatedAt;
        default:
          return null;
      }
    } else if (item is Page) {
      switch (field) {
        case 'name':
          return item.name;
        case 'title':
          return item.title;
        case 'createdAt':
          return item.createdAt;
        case 'updatedAt':
          return item.updatedAt;
        default:
          return null;
      }
    }
    return null;
  }

  int _compareValues(dynamic a, dynamic b) {
    if (a is String && b is String) {
      return a.toLowerCase().compareTo(b.toLowerCase());
    }
    if (a is num && b is num) {
      return a.compareTo(b);
    }
    if (a is DateTime && b is DateTime) {
      return a.compareTo(b);
    }
    if (a is Comparable && b is Comparable) {
      return a.compareTo(b);
    }
    return 0;
  }
}

/// Helper class for computing statistics on query results
class QueryStats {
  /// Compute tag frequency from a list of items
  static Map<String, int> tagFrequency(List<dynamic> items) {
    final tagCounts = <String, int>{};

    for (final item in items) {
      Set<String> tags = {};
      if (item is Block) tags = item.tags;
      if (item is Page) tags = item.tags;

      for (final tag in tags) {
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
    }

    final sortedEntries = tagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Map.fromEntries(sortedEntries);
  }

  /// Compute page distribution for a list of blocks
  static Map<String, int> pageDistribution(List<Block> blocks) {
    final pageCounts = <String, int>{};

    for (final block in blocks) {
      if (block.pageName != null) {
        pageCounts[block.pageName!] = (pageCounts[block.pageName!] ?? 0) + 1;
      }
    }

    final sortedEntries = pageCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Map.fromEntries(sortedEntries);
  }

  /// Compute level distribution for a list of blocks
  static Map<int, int> levelDistribution(List<Block> blocks) {
    final levelCounts = <int, int>{};

    for (final block in blocks) {
      levelCounts[block.level] = (levelCounts[block.level] ?? 0) + 1;
    }

    final sortedEntries = levelCounts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Map.fromEntries(sortedEntries);
  }

  /// Compute property frequency from a list of items
  static Map<String, int> propertyFrequency(List<dynamic> items) {
    final propCounts = <String, int>{};

    for (final item in items) {
      Map<String, dynamic> properties = {};
      if (item is Block) properties = item.properties;
      if (item is Page) properties = item.properties;

      for (final key in properties.keys) {
        propCounts[key] = (propCounts[key] ?? 0) + 1;
      }
    }

    final sortedEntries = propCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Map.fromEntries(sortedEntries);
  }
}
