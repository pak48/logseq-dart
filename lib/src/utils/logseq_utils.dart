/// Utility functions for Logseq operations
library;

import 'dart:io';
import 'package:intl/intl.dart';
import '../models/block.dart';
import '../models/page.dart';

/// Utility class for Logseq operations
class LogseqUtils {
  LogseqUtils._();

  /// Check if a page name represents a journal entry
  static bool isJournalPage(String pageName) {
    final datePatterns = [
      RegExp(r'^\d{4}-\d{2}-\d{2}$'), // YYYY-MM-DD
      RegExp(r'^\d{4}_\d{2}_\d{2}$'), // YYYY_MM_DD
      RegExp(r'^[A-Z][a-z]{2} \d{1,2}[a-z]{2}, \d{4}$'), // Jan 1st, 2024
    ];

    return datePatterns.any((pattern) => pattern.hasMatch(pageName));
  }

  /// Parse journal date from page name
  static DateTime? parseJournalDate(String pageName) {
    try {
      // Try YYYY-MM-DD format first
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(pageName)) {
        return DateTime.parse(pageName);
      }

      // Try YYYY_MM_DD format
      if (RegExp(r'^\d{4}_\d{2}_\d{2}$').hasMatch(pageName)) {
        return DateFormat('yyyy_MM_dd').parse(pageName);
      }

      // Add more patterns here if needed
    } catch (_) {
      return null;
    }

    return null;
  }

  /// Parse a Logseq markdown file into a Page object
  static Future<Page> parseMarkdownFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    final content = await file.readAsString();
    final pageName =
        filePath.split('/').last.replaceAll('.md', '');

    final page = Page(name: pageName, filePath: filePath);

    // Check if it's a journal page
    page.isJournal = isJournalPage(pageName);
    if (page.isJournal) {
      page.journalDate = parseJournalDate(pageName);
    }

    // Parse blocks from content
    final blocks = parseBlocksFromContent(content, pageName);
    for (final block in blocks) {
      page.addBlock(block);
    }

    // Extract page-level properties
    final properties = extractPageProperties(content);
    page.properties.addAll(properties);

    return page;
  }

  /// Parse blocks from markdown content
  static List<Block> parseBlocksFromContent(String content, String pageName) {
    final lines = content.split('\n');
    final blocks = <Block>[];
    final blockStack = <Block>[];
    var i = 0;

    while (i < lines.length) {
      final line = lines[i];
      final strippedLine = line.trim();

      // Skip empty lines and page properties
      if (strippedLine.isEmpty || strippedLine.contains('::')) {
        i++;
        continue;
      }

      // Handle code blocks (multi-line)
      if (strippedLine.startsWith('```')) {
        final codeLines = [line];
        i++;
        // Continue reading until closing ```
        while (i < lines.length) {
          codeLines.add(lines[i]);
          if (lines[i].trim() == '```') {
            break;
          }
          i++;
        }

        // Create single block with all code content
        final level = getBlockLevel(line);
        final blockContent = codeLines.join('\n');

        final block = Block(
          content: blockContent,
          level: level,
          pageName: pageName,
        );

        // Handle parent-child relationships
        _handleBlockHierarchy(block, blockStack, blocks);

        i++;
        continue;
      }

      // Handle math blocks ($$...$$)
      if (strippedLine.startsWith(r'$$')) {
        final mathLines = [line];
        i++;
        // Continue reading until closing $$
        while (i < lines.length) {
          mathLines.add(lines[i]);
          if (lines[i].trim() == r'$$') {
            break;
          }
          i++;
        }

        final level = getBlockLevel(line);
        final blockContent = mathLines.join('\n');

        final block = Block(
          content: blockContent,
          level: level,
          pageName: pageName,
        );

        _handleBlockHierarchy(block, blockStack, blocks);

        i++;
        continue;
      }

      // Regular single-line block processing
      final level = getBlockLevel(line);

      // Remove markdown list markers
      final blockContent = cleanBlockContent(strippedLine);

      if (blockContent.isEmpty) {
        i++;
        continue;
      }

      // Create new block
      final block = Block(
        content: blockContent,
        level: level,
        pageName: pageName,
      );

      _handleBlockHierarchy(block, blockStack, blocks);

      i++;
    }

    return blocks;
  }

  /// Handle block hierarchy (parent-child relationships)
  static void _handleBlockHierarchy(
      Block block, List<Block> blockStack, List<Block> blocks) {
    if (block.level == 0) {
      blockStack.clear();
      blockStack.add(block);
    } else {
      // Find the appropriate parent
      while (blockStack.length > block.level) {
        blockStack.removeLast();
      }

      if (blockStack.isNotEmpty) {
        final parent = blockStack.last;
        parent.addChild(block);
      }

      blockStack.add(block);
    }

    blocks.add(block);
  }

  /// Determine the indentation level of a block
  static int getBlockLevel(String line) {
    var level = 0;

    // Count leading tabs
    for (final char in line.runes) {
      if (char == 9) {
        // Tab character
        level++;
      } else if (char != 32) {
        // Not a space
        break;
      }
    }

    // If no tabs, count spaces (assuming 2 spaces = 1 level)
    if (level == 0) {
      final leadingSpaces = line.length - line.trimLeft().length;
      level = leadingSpaces ~/ 2;
    }

    return level;
  }

  /// Clean block content by removing markdown list markers
  static String cleanBlockContent(String content) {
    // Remove leading list markers (-, *, +)
    var cleaned = content.replaceFirst(RegExp(r'^[\-\*\+]\s+'), '');

    // Remove leading numbers for ordered lists
    cleaned = cleaned.replaceFirst(RegExp(r'^\d+\.\s+'), '');

    return cleaned.trim();
  }

  /// Extract page-level properties from content
  static Map<String, dynamic> extractPageProperties(String content) {
    final properties = <String, dynamic>{};
    final lines = content.split('\n');

    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) {
        continue;
      }

      // Stop when we hit the first block (starting with -)
      if (trimmedLine.startsWith('-')) {
        break;
      }

      // Match property format: key:: value
      final match = RegExp(r'^([a-zA-Z0-9_-]+)::\s*(.+)$').firstMatch(trimmedLine);
      if (match != null) {
        final key = match.group(1)!.toLowerCase();
        final value = match.group(2)!.trim();
        properties[key] = value;
      }
    }

    return properties;
  }

  /// Format a date object for Logseq journal page naming
  static String formatDateForJournal(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /// Ensure a page name is valid for Logseq
  static String ensureValidPageName(String name) {
    // Remove or replace invalid characters
    final invalidChars = ['/', '\\', ':', '*', '?', '"', '<', '>', '|'];

    var validName = name;
    for (final char in invalidChars) {
      validName = validName.replaceAll(char, '_');
    }

    // Trim whitespace
    validName = validName.trim();

    // Ensure it's not empty
    if (validName.isEmpty) {
      validName = 'Untitled';
    }

    return validName;
  }

  /// Get the last modification time of a file
  static DateTime? getFileModificationTime(String filePath) {
    try {
      final file = File(filePath);
      final stat = file.statSync();
      return stat.modified;
    } catch (_) {
      return null;
    }
  }

  /// Extract video URLs from text
  static List<String> extractVideoUrls(String text) {
    final videoPatterns = [
      // YouTube patterns
      RegExp(
          r'(?:youtube\.com/watch\?v=|youtu\.be/|youtube\.com/embed/|youtube\.com/v/|youtube\.com/shorts/)([a-zA-Z0-9_-]{11})'),
      // Vimeo patterns
      RegExp(r'vimeo\.com/(\d+)'),
      RegExp(r'vimeo\.com/channels/[^/]+/(\d+)'),
      RegExp(r'vimeo\.com/groups/[^/]+/videos/(\d+)'),
      // TikTok patterns
      RegExp(r'tiktok\.com/@[^/]+/video/(\d+)'),
      RegExp(r'vm\.tiktok\.com/([^/\s]+)'),
      // Twitch patterns
      RegExp(r'twitch\.tv/videos/(\d+)'),
      RegExp(r'twitch\.tv/[^/]+/clip/([^/?\s]+)'),
      RegExp(r'clips\.twitch\.tv/([^/?\s]+)'),
      // Dailymotion patterns
      RegExp(r'dailymotion\.com/video/([^/?\s]+)'),
      RegExp(r'dai\.ly/([^/?\s]+)'),
    ];

    final foundUrls = <String>[];

    // General URL pattern to capture full URLs
    final urlPattern = RegExp(
        r'https?://(?:[-\w.])+(?:[:\d]+)?(?:/(?:[\w/_.])*(?:\?(?:[\w&=%.])*)?(?:#(?:[\w.])*)?)?',
        caseSensitive: false);
    final urls = urlPattern.allMatches(text);

    for (final url in urls) {
      final urlString = url.group(0)!;
      // Check if it matches any video platform pattern
      for (final pattern in videoPatterns) {
        if (pattern.hasMatch(urlString)) {
          foundUrls.add(urlString);
          break;
        }
      }
    }

    return foundUrls;
  }
}
