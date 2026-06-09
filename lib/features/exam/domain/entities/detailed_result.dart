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

  // From batches table (left join, can be null if batch is hard deleted, but soft deleted ones will have names)
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
    this.batchName,
    this.studentName,
    this.studentClass,
  });

  double? get percentage {
    if (isAbsent || obtainedMarks == null || totalMarks <= 0) return null;
    return (obtainedMarks! / totalMarks) * 100;
  }
}
