
import '../../../../core/utils/grade_utils.dart';

class DetailedResult {
  final int? id;
  final int examId;
  final int studentId;
  final int batchId;
  final double? obtainedMarks;
  final bool isAbsent;
  final bool hasPaid;
  final DateTime createdAt;

  // From exams table
  final String examTitle;
  final String examType;
  final DateTime examDate;
  final double totalMarks;
  final double? examFee;

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
    this.hasPaid = false,
    required this.createdAt,
    required this.examTitle,
    required this.examType,
    required this.examDate,
    required this.totalMarks,
    this.examFee,
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

  /// Letter grade based on BD GPA 5.0 scale (A+, A, A-, B, C, D, F).
  /// Returns '-' if absent.
  String get grade => GradeUtils.getGrade(percentage);

  /// Grade point (0.00 – 5.00). Returns null if absent.
  double? get gradePoint => GradeUtils.getGradePoint(percentage);

  /// Whether the student passed this exam (>= 33%).
  bool get isPassing => GradeUtils.isPassing(percentage);
}
