import '../../domain/entities/fee_transaction.dart';
import '../../../../core/utils/date_utils.dart';

class FeeTransactionModel extends FeeTransaction {
  FeeTransactionModel({
    super.id,
    required super.feeRecordId,
    required super.amount,
    required super.paymentDate,
    super.note,
    required super.createdAt,
    super.studentName,
    super.batchDetailsSnapshot,
    super.feeMonth,
    super.feeYear,
  });

  factory FeeTransactionModel.fromEntity(FeeTransaction entity) {
    return FeeTransactionModel(
      id: entity.id,
      feeRecordId: entity.feeRecordId,
      amount: entity.amount,
      paymentDate: entity.paymentDate,
      note: entity.note,
      createdAt: entity.createdAt,
      studentName: entity.studentName,
      batchDetailsSnapshot: entity.batchDetailsSnapshot,
      feeMonth: entity.feeMonth,
      feeYear: entity.feeYear,
    );
  }

  factory FeeTransactionModel.fromMap(Map<String, dynamic> map) {
    return FeeTransactionModel(
      id: map['id'],
      feeRecordId: map['fee_record_id'],
      amount: (map['amount'] as num).toDouble(),
      paymentDate: DateUtilsHelper.parseFromDb(map['payment_date']),
      note: map['note'],
      createdAt: DateUtilsHelper.parseFromDb(map['created_at']),
      studentName: map['student_name'],
      batchDetailsSnapshot: map['batch_details_snapshot'],
      feeMonth: map['month'],
      feeYear: map['year'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fee_record_id': feeRecordId,
      'amount': amount,
      'payment_date': DateUtilsHelper.formatForDb(paymentDate),
      'note': note,
      'created_at': DateUtilsHelper.formatForDb(createdAt),
    };
  }
}
