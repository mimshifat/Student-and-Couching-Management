class FeeTransaction {
  final int? id;
  final int feeRecordId;
  final double amount;
  final DateTime paymentDate;
  final String? note;
  final DateTime createdAt;

  // Additional UI-friendly fields when joining with fee_records and students
  final String? studentName;
  final String? batchDetailsSnapshot;
  final int? feeMonth;
  final int? feeYear;

  FeeTransaction({
    this.id,
    required this.feeRecordId,
    required this.amount,
    required this.paymentDate,
    this.note,
    required this.createdAt,
    this.studentName,
    this.batchDetailsSnapshot,
    this.feeMonth,
    this.feeYear,
  });
}
