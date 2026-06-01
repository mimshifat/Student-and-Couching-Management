class FeeRecord {
  final int? id;
  final int studentId;
  final int month;
  final int year;
  final double totalAmount;
  final double paidAmount;
  final bool isSettled;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? studentClass;
  final int? batchId;
  final String? batchDetailsSnapshot;
  final String? note;
  final DateTime? paymentDate;

  // Transient
  final String? studentName;

  FeeRecord({
    this.id,
    required this.studentId,
    required this.month,
    required this.year,
    required this.totalAmount,
    this.paidAmount = 0.0,
    this.isSettled = false,
    this.studentClass,
    this.batchId,
    this.batchDetailsSnapshot,
    this.note,
    this.paymentDate,
    required this.createdAt,
    required this.updatedAt,
    this.studentName,
  });

  static const Object _sentinel = Object();

  FeeRecord copyWith({
    int? id,
    int? studentId,
    int? month,
    int? year,
    double? totalAmount,
    double? paidAmount,
    bool? isSettled,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? studentClass = _sentinel,
    Object? batchId = _sentinel,
    Object? batchDetailsSnapshot = _sentinel,
    Object? note = _sentinel,
    Object? paymentDate = _sentinel,
    Object? studentName = _sentinel,
  }) {
    return FeeRecord(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      month: month ?? this.month,
      year: year ?? this.year,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      isSettled: isSettled ?? this.isSettled,
      studentClass: studentClass == _sentinel ? this.studentClass : studentClass as String?,
      batchId: batchId == _sentinel ? this.batchId : batchId as int?,
      batchDetailsSnapshot: batchDetailsSnapshot == _sentinel ? this.batchDetailsSnapshot : batchDetailsSnapshot as String?,
      note: note == _sentinel ? this.note : note as String?,
      paymentDate: paymentDate == _sentinel ? this.paymentDate : paymentDate as DateTime?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      studentName: studentName == _sentinel ? this.studentName : studentName as String?,
    );
  }
}
