class DetailedResult {
  final int? id;
  final int examId;
  final int studentId;
  final int batchId;
  final double? obtainedMarks;
  final bool isAbsent;
  final DateTime createdAt;

  // From exams table
  final String examTitle;
  final String examType;
  final DateTime examDate;
  final double totalMarks;

  // Snapshot of batch info at the time of exam creation (preferred)
  final Map<String, dynamic>? batchSnapshot;

  // From batches table (LEFT JOIN — fallback when snapshot is null or batch renamed)
  final String? batchName;

  // From students table
  final String? studentName;
  final String? studentClass;

  DetailedResult({
    this.id,
    required this.examId,
    required this.studentId,
    required this.batchId,
    this.obtainedMarks,
    this.isAbsent = false,
    required this.createdAt,
    required this.examTitle,
    required this.examType,
    required this.examDate,
    required this.totalMarks,
    this.batchSnapshot,
    this.batchName,
    this.studentName,
    this.studentClass,
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

  /// Snapshot name takes priority; falls back to live-joined name.
  String get displayBatchName => snapshotBatchName ?? batchName ?? 'Unknown Batch';

  double? get percentage {
    if (isAbsent || obtainedMarks == null || totalMarks <= 0) return null;
    return (obtainedMarks! / totalMarks) * 100;
  }
}
