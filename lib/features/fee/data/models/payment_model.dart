import '../../domain/entities/payment.dart';
import '../../../../core/utils/date_utils.dart';

class PaymentModel extends Payment {
  PaymentModel({
    super.id,
    required super.feeRecordId,
    required super.studentId,
    required super.amount,
    required super.paymentDate,
    super.note,
    required super.createdAt,
  });

  factory PaymentModel.fromEntity(Payment entity) {
    return PaymentModel(
      id: entity.id,
      feeRecordId: entity.feeRecordId,
      studentId: entity.studentId,
      amount: entity.amount,
      paymentDate: entity.paymentDate,
      note: entity.note,
      createdAt: entity.createdAt,
    );
  }

  factory PaymentModel.fromMap(Map<String, dynamic> map) {
    return PaymentModel(
      id: map['id'],
      feeRecordId: map['fee_record_id'],
      studentId: map['student_id'],
      amount: (map['amount'] as num).toDouble(),
      paymentDate: DateUtilsHelper.parseFromDb(map['payment_date']),
      note: map['note'],
      createdAt: DateUtilsHelper.parseFromDb(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fee_record_id': feeRecordId,
      'student_id': studentId,
      'amount': amount,
      'payment_date': DateUtilsHelper.formatForDb(paymentDate),
      'note': note,
      'created_at': DateUtilsHelper.formatForDb(createdAt),
    };
  }
}
