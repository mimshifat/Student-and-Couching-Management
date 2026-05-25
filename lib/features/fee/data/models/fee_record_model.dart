import '../../domain/entities/fee_record.dart';
import '../../../../core/utils/date_utils.dart';

class FeeRecordModel extends FeeRecord {
  FeeRecordModel({
    super.id,
    required super.studentId,
    required super.month,
    required super.year,
    required super.totalAmount,
    super.paidAmount = 0.0,
    super.studentClass,
    required super.createdAt,
    required super.updatedAt,
    super.studentName,
  });

  factory FeeRecordModel.fromEntity(FeeRecord entity) {
    return FeeRecordModel(
      id: entity.id,
      studentId: entity.studentId,
      month: entity.month,
      year: entity.year,
      totalAmount: entity.totalAmount,
      paidAmount: entity.paidAmount,
      studentClass: entity.studentClass,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      studentName: entity.studentName,
    );
  }

  factory FeeRecordModel.fromMap(Map<String, dynamic> map) {
    return FeeRecordModel(
      id: map['id'],
      studentId: map['student_id'],
      month: map['month'],
      year: map['year'],
      totalAmount: (map['total_amount'] as num).toDouble(),
      paidAmount: (map['paid_amount'] as num).toDouble(),
      studentClass: map['student_class'],
      createdAt: DateUtilsHelper.parseFromDb(map['created_at']),
      updatedAt: DateUtilsHelper.parseFromDb(map['updated_at']),
      studentName: map['student_name'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'month': month,
      'year': year,
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'student_class': studentClass,
      'created_at': DateUtilsHelper.formatForDb(createdAt),
      'updated_at': DateUtilsHelper.formatForDb(updatedAt),
    };
  }
}
