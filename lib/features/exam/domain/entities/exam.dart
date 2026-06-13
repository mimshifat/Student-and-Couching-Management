class Exam {
  final int? id;
  final int batchId;
  final String title;
  final String examType;
  final DateTime examDate;
  final double totalMarks;
  final DateTime createdAt;

  // For UI display (live join — fallback when snapshot is null)
  final String? batchName;

  // Snapshot of batch details at the time of exam creation/update
  final Map<String, dynamic>? batchSnapshot;

  Exam({
    this.id,
    required this.batchId,
    required this.title,
    required this.examType,
    required this.examDate,
    required this.totalMarks,
    required this.createdAt,
    this.batchName,
    this.batchSnapshot,
  });

  // --- Snapshot getters ---
  String? get snapshotBatchName => batchSnapshot?['name'] as String?;
  String? get snapshotScheduleDays => batchSnapshot?['schedule_days'] as String?;
  String? get snapshotTimeSlot => batchSnapshot?['time_slot'] as String?;
  double? get snapshotMonthlyFee {
    final v = batchSnapshot?['monthly_fee'];
    if (v == null) return null;
    return (v as num).toDouble();
  }
  String? get snapshotDescription => batchSnapshot?['description'] as String?;

  /// Always prefer the snapshot name; fall back to the live-joined batchName.
  String get displayBatchName => snapshotBatchName ?? batchName ?? 'Unknown Batch';

  /// Full display detail: "Name (Days | Time)"
  String get displayBatchDetail {
    final name = displayBatchName;
    final days = snapshotScheduleDays ?? '';
    final time = snapshotTimeSlot ?? '';
    if (days.isNotEmpty && time.isNotEmpty) return '$name ($days | $time)';
    if (days.isNotEmpty) return '$name ($days)';
    if (time.isNotEmpty) return '$name ($time)';
    return name;
  }

  Exam copyWith({
    int? id,
    int? batchId,
    String? title,
    String? examType,
    DateTime? examDate,
    double? totalMarks,
    DateTime? createdAt,
    String? batchName,
    Map<String, dynamic>? batchSnapshot,
  }) {
    return Exam(
      id: id ?? this.id,
      batchId: batchId ?? this.batchId,
      title: title ?? this.title,
      examType: examType ?? this.examType,
      examDate: examDate ?? this.examDate,
      totalMarks: totalMarks ?? this.totalMarks,
      createdAt: createdAt ?? this.createdAt,
      batchName: batchName ?? this.batchName,
      batchSnapshot: batchSnapshot ?? this.batchSnapshot,
    );
  }
}
