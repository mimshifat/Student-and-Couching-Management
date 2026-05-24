class ExamResult {
  final int? id;
  final int examId;
  final int studentId;
  final int batchId;
  final double? obtainedMarks;
  final bool isAbsent;
  final DateTime createdAt;

  // Transient for UI
  final String? studentName;

  ExamResult({
    this.id,
    required this.examId,
    required this.studentId,
    required this.batchId,
    this.obtainedMarks,
    this.isAbsent = false,
    required this.createdAt,
    this.studentName,
  });

  ExamResult copyWith({
    int? id,
    int? examId,
    int? studentId,
    int? batchId,
    double? obtainedMarks,
    bool? isAbsent,
    DateTime? createdAt,
    String? studentName,
  }) {
    return ExamResult(
      id: id ?? this.id,
      examId: examId ?? this.examId,
      studentId: studentId ?? this.studentId,
      batchId: batchId ?? this.batchId,
      obtainedMarks: obtainedMarks ?? this.obtainedMarks,
      isAbsent: isAbsent ?? this.isAbsent,
      createdAt: createdAt ?? this.createdAt,
      studentName: studentName ?? this.studentName,
    );
  }
}
