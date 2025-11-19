/// A comprehensive Dart/Flutter library for Logseq knowledge graph interaction.
///
/// Provides programmatic access to every major Logseq feature including:
/// - Task management with TODO states, priorities, scheduling, and deadlines
/// - Advanced content types (code blocks, LaTeX, queries, headings, references)
/// - Organization features (namespaces, templates, aliases, whiteboards)
/// - Knowledge graph analytics and insights
/// - Powerful query system with 25+ methods
/// - Database-backed storage with automatic file sync
/// - Memory-efficient lazy loading
library logseq_dart;

// Core client (database-backed)
export 'src/client/logseq_client.dart';

// Models
export 'src/models/block.dart';
export 'src/models/page.dart';
export 'src/models/graph.dart';
export 'src/models/enums.dart';
export 'src/models/advanced_models.dart';

// Query
export 'src/query/query_builder.dart';

// Utils
export 'src/utils/logseq_utils.dart';

// Storage (for advanced usage)
export 'src/storage/database.dart';
export 'src/storage/cache.dart';
