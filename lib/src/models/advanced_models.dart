/// Advanced Logseq models for specialized features
library;

import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

/// Represents an embedded block reference
class BlockEmbed extends Equatable {
  final String blockId;
  final String? contentPreview;
  final String embedType; // "block", "page", "query"

  const BlockEmbed({
    required this.blockId,
    this.contentPreview,
    this.embedType = 'block',
  });

  @override
  List<Object?> get props => [blockId, contentPreview, embedType];

  Map<String, dynamic> toJson() => {
        'blockId': blockId,
        'contentPreview': contentPreview,
        'embedType': embedType,
      };

  factory BlockEmbed.fromJson(Map<String, dynamic> json) => BlockEmbed(
        blockId: json['blockId'] as String,
        contentPreview: json['contentPreview'] as String?,
        embedType: json['embedType'] as String? ?? 'block',
      );
}

/// Represents scheduled/deadline dates in Logseq
class ScheduledDate extends Equatable {
  final DateTime date;
  final String? time;
  final String? repeater; // e.g., "+1w", "+3d"
  final String? delay;

  const ScheduledDate({
    required this.date,
    this.time,
    this.repeater,
    this.delay,
  });

  @override
  List<Object?> get props => [date, time, repeater, delay];

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'time': time,
        'repeater': repeater,
        'delay': delay,
      };

  factory ScheduledDate.fromJson(Map<String, dynamic> json) => ScheduledDate(
        date: DateTime.parse(json['date'] as String),
        time: json['time'] as String?,
        repeater: json['repeater'] as String?,
        delay: json['delay'] as String?,
      );
}

/// Represents a Logseq query block
class LogseqQuery extends Equatable {
  final String queryString;
  final String queryType; // "simple", "advanced", "custom"
  final List<Map<String, dynamic>> results;
  final bool live;
  final bool collapsed;

  const LogseqQuery({
    required this.queryString,
    this.queryType = 'simple',
    this.results = const [],
    this.live = true,
    this.collapsed = false,
  });

  @override
  List<Object?> get props =>
      [queryString, queryType, results, live, collapsed];

  Map<String, dynamic> toJson() => {
        'queryString': queryString,
        'queryType': queryType,
        'results': results,
        'live': live,
        'collapsed': collapsed,
      };

  factory LogseqQuery.fromJson(Map<String, dynamic> json) => LogseqQuery(
        queryString: json['queryString'] as String,
        queryType: json['queryType'] as String? ?? 'simple',
        results: (json['results'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [],
        live: json['live'] as bool? ?? true,
        collapsed: json['collapsed'] as bool? ?? false,
      );
}

/// Represents a Logseq template
class Template extends Equatable {
  final String name;
  final String content;
  final List<String> variables;
  final int usageCount;
  final String templateType; // "block", "page"

  const Template({
    required this.name,
    required this.content,
    this.variables = const [],
    this.usageCount = 0,
    this.templateType = 'block',
  });

  @override
  List<Object?> get props =>
      [name, content, variables, usageCount, templateType];

  Map<String, dynamic> toJson() => {
        'name': name,
        'content': content,
        'variables': variables,
        'usageCount': usageCount,
        'templateType': templateType,
      };

  factory Template.fromJson(Map<String, dynamic> json) => Template(
        name: json['name'] as String,
        content: json['content'] as String,
        variables:
            (json['variables'] as List<dynamic>?)?.cast<String>() ?? [],
        usageCount: json['usageCount'] as int? ?? 0,
        templateType: json['templateType'] as String? ?? 'block',
      );
}

/// Represents PDF annotations or highlights
class Annotation extends Equatable {
  final String id;
  final String content;
  final int? pageNumber;
  final String? highlightText;
  final String annotationType; // "highlight", "note", "underline"
  final String? color;
  final String? pdfPath;
  final Map<String, double>? coordinates;

  Annotation({
    String? id,
    this.content = '',
    this.pageNumber,
    this.highlightText,
    this.annotationType = 'highlight',
    this.color,
    this.pdfPath,
    this.coordinates,
  }) : id = id ?? const Uuid().v4();

  @override
  List<Object?> get props => [
        id,
        content,
        pageNumber,
        highlightText,
        annotationType,
        color,
        pdfPath,
        coordinates
      ];

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'pageNumber': pageNumber,
        'highlightText': highlightText,
        'annotationType': annotationType,
        'color': color,
        'pdfPath': pdfPath,
        'coordinates': coordinates,
      };

  factory Annotation.fromJson(Map<String, dynamic> json) => Annotation(
        id: json['id'] as String?,
        content: json['content'] as String? ?? '',
        pageNumber: json['pageNumber'] as int?,
        highlightText: json['highlightText'] as String?,
        annotationType: json['annotationType'] as String? ?? 'highlight',
        color: json['color'] as String?,
        pdfPath: json['pdfPath'] as String?,
        coordinates: (json['coordinates'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, (v as num).toDouble())),
      );
}

/// Represents elements on a Logseq whiteboard
class WhiteboardElement extends Equatable {
  final String id;
  final String elementType; // "shape", "text", "block", "page", "image"
  final String content;
  final Map<String, double> position; // x, y coordinates
  final Map<String, double> size; // width, height
  final Map<String, dynamic> style; // color, stroke, etc.
  final String? blockId;

  WhiteboardElement({
    String? id,
    this.elementType = 'shape',
    this.content = '',
    this.position = const {},
    this.size = const {},
    this.style = const {},
    this.blockId,
  }) : id = id ?? const Uuid().v4();

  @override
  List<Object?> get props =>
      [id, elementType, content, position, size, style, blockId];

  Map<String, dynamic> toJson() => {
        'id': id,
        'elementType': elementType,
        'content': content,
        'position': position,
        'size': size,
        'style': style,
        'blockId': blockId,
      };

  factory WhiteboardElement.fromJson(Map<String, dynamic> json) =>
      WhiteboardElement(
        id: json['id'] as String?,
        elementType: json['elementType'] as String? ?? 'shape',
        content: json['content'] as String? ?? '',
        position: (json['position'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
            {},
        size: (json['size'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
            {},
        style: (json['style'] as Map<String, dynamic>?) ?? {},
        blockId: json['blockId'] as String?,
      );
}
