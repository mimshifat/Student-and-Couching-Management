/// Static description of every SQLite table that is synchronised to the cloud.
///
/// The order of [SyncTables.all] is the foreign-key dependency order: a table
/// only references tables that appear *before* it. Restore and bootstrap code
/// rely on this order so that parents always exist before their children.
library;

/// A foreign-key column that points at another synced table.
class SyncParentRef {
  /// Column in the child table, e.g. `student_id`.
  final String column;

  /// Parent table name, e.g. `students`.
  final String parentTable;

  const SyncParentRef(this.column, this.parentTable);
}

class SyncTableSpec {
  final String name;
  final List<SyncParentRef> parents;

  /// SQL expression template that produces a deterministic sync_id for rows of
  /// this table, or `null` if rows get a random UUID.
  ///
  /// The placeholder `{R}` is replaced with the row reference (`NEW`, `OLD`
  /// or a table alias). Deterministic IDs guarantee that the *same logical
  /// record* created independently on two devices (or deleted and re-inserted
  /// locally) maps to the *same* cloud document, which prevents duplicates.
  final String? deterministicIdTemplate;

  const SyncTableSpec(
    this.name, {
    this.parents = const [],
    this.deterministicIdTemplate,
  });

  String? deterministicIdFor(String rowRef) =>
      deterministicIdTemplate?.replaceAll('{R}', rowRef);
}

/// Sub-query returning the sync_id of a parent row.
String _parentSid(String parentTable, String fkExpr) =>
    "(SELECT sync_id FROM sync_map WHERE tbl = '$parentTable' AND local_id = $fkExpr)";

class SyncTables {
  SyncTables._();

  static final List<SyncTableSpec> all = [
    const SyncTableSpec('students'),
    const SyncTableSpec('batches'),
    const SyncTableSpec('notes'),
    const SyncTableSpec(
      'batch_inactive_periods',
      parents: [SyncParentRef('batch_id', 'batches')],
    ),
    const SyncTableSpec(
      'enrollments',
      parents: [
        SyncParentRef('student_id', 'students'),
        SyncParentRef('batch_id', 'batches'),
      ],
    ),
    const SyncTableSpec(
      'exams',
      parents: [SyncParentRef('batch_id', 'batches')],
    ),
    const SyncTableSpec(
      'routines',
      parents: [SyncParentRef('batch_id', 'batches')],
    ),
    SyncTableSpec(
      'results',
      parents: const [
        SyncParentRef('exam_id', 'exams'),
        SyncParentRef('student_id', 'students'),
        SyncParentRef('batch_id', 'batches'),
      ],
      // One result per (exam, student). The exam screen deletes and re-inserts
      // results on every save; this keeps the cloud document stable.
      deterministicIdTemplate: "'rs_' || ${_parentSid('exams', '{R}.exam_id')}"
          " || '_' || ${_parentSid('students', '{R}.student_id')}",
    ),
    SyncTableSpec(
      'fee_records',
      parents: const [
        SyncParentRef('student_id', 'students'),
        SyncParentRef('batch_id', 'batches'),
      ],
      // One fee record per (student, batch, year, month). generateFeeRecords()
      // runs on every device, so both devices must produce the same document.
      deterministicIdTemplate: "'fr_' || ${_parentSid('students', '{R}.student_id')}"
          " || '_' || COALESCE(${_parentSid('batches', '{R}.batch_id')}, 'none')"
          " || '_' || {R}.year || '_' || {R}.month",
    ),
    const SyncTableSpec(
      'fee_transactions',
      parents: [SyncParentRef('fee_record_id', 'fee_records')],
    ),
  ];

  static final Set<String> names = all.map((t) => t.name).toSet();

  static SyncTableSpec byName(String name) =>
      all.firstWhere((t) => t.name == name);
}
