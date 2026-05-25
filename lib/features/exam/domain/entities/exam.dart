class Exam {
  final int? id;
  final int batchId;
  final String title;
  final String examType;
  final DateTime examDate;
  final double totalMarks;
  final DateTime createdAt;

  // For UI display
  final String? batchName;

  Exam({
    this.id,
    required this.batchId,
    required this.title,
    required this.examType,
    required this.examDate,
    required this.totalMarks,
    required this.createdAt,
    this.batchName,
  });

  Exam copyWith({
    int? id,
    int? batchId,
    String? title,
    String? examType,
    DateTime? examDate,
    double? totalMarks,
    DateTime? createdAt,
    String? batchName,
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
    );
  }
}
