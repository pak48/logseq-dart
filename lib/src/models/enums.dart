/// Enums for Logseq entities
library;

/// Task states in Logseq
enum TaskState {
  todo('TODO'),
  doing('DOING'),
  done('DONE'),
  later('LATER'),
  now('NOW'),
  waiting('WAITING'),
  cancelled('CANCELLED'),
  delegated('DELEGATED'),
  inProgress('IN-PROGRESS');

  const TaskState(this.value);
  final String value;

  static TaskState? fromString(String value) {
    try {
      return TaskState.values.firstWhere((e) => e.value == value);
    } catch (_) {
      return null;
    }
  }
}

/// Priority levels in Logseq
enum Priority {
  a('A'),
  b('B'),
  c('C');

  const Priority(this.value);
  final String value;

  static Priority? fromString(String value) {
    try {
      return Priority.values.firstWhere((e) => e.value == value.toUpperCase());
    } catch (_) {
      return null;
    }
  }
}

/// Types of blocks in Logseq
enum BlockType {
  bullet('bullet'),
  numbered('numbered'),
  quote('quote'),
  heading('heading'),
  code('code'),
  math('math'),
  example('example'),
  export('export'),
  verse('verse'),
  drawer('drawer');

  const BlockType(this.value);
  final String value;

  static BlockType? fromString(String value) {
    try {
      return BlockType.values.firstWhere((e) => e.value == value.toLowerCase());
    } catch (_) {
      return null;
    }
  }
}
