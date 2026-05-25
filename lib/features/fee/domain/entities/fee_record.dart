class FeeRecord {
  final int? id;
  final int studentId;
  final int month;
  final int year;
  final double totalAmount;
  final double paidAmount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? studentClass;
  final int? batchId;
  final String? batchDetailsSnapshot;

  // Transient
  final String? studentName;

  FeeRecord({
    this.id,
    required this.studentId,
    required this.month,
    required this.year,
    required this.totalAmount,
    this.paidAmount = 0.0,
    this.studentClass,
    this.batchId,
    this.batchDetailsSnapshot,
    required this.createdAt,
    required this.updatedAt,
    this.studentName,
  });

  FeeRecord copyWith({
    int? id,
    int? studentId,
    int? month,
    int? year,
    double? totalAmount,
    double? paidAmount,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? studentClass,
    int? batchId,
    String? batchDetailsSnapshot,
    String? studentName,
  }) {
    return FeeRecord(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      month: month ?? this.month,
      year: year ?? this.year,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      studentClass: studentClass ?? this.studentClass,
      batchId: batchId ?? this.batchId,
      batchDetailsSnapshot: batchDetailsSnapshot ?? this.batchDetailsSnapshot,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      studentName: studentName ?? this.studentName,
    );
  }
}
