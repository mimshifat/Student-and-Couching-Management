class Payment {
  final int? id;
  final int feeRecordId;
  final int studentId;
  final double amount;
  final DateTime paymentDate;
  final String? note;
  final DateTime createdAt;

  Payment({
    this.id,
    required this.feeRecordId,
    required this.studentId,
    required this.amount,
    required this.paymentDate,
    this.note,
    required this.createdAt,
  });
}
