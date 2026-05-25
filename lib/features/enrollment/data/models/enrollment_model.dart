import '../../domain/entities/enrollment.dart';
import '../../../../core/utils/date_utils.dart';

class EnrollmentModel extends Enrollment {
  EnrollmentModel({
    super.id,
    required super.studentId,
    required super.batchId,
    required super.joinDate,
    super.leaveDate,
    super.feeOverride,
    super.studentClass,
    required super.createdAt,
    super.batchName,
    super.studentName,
  });

  factory EnrollmentModel.fromEntity(Enrollment entity) {
    return EnrollmentModel(
      id: entity.id,
      studentId: entity.studentId,
      batchId: entity.batchId,
      joinDate: entity.joinDate,
      leaveDate: entity.leaveDate,
      feeOverride: entity.feeOverride,
      studentClass: entity.studentClass,
      createdAt: entity.createdAt,
      batchName: entity.batchName,
      studentName: entity.studentName,
    );
  }

  factory EnrollmentModel.fromMap(Map<String, dynamic> map) {
    return EnrollmentModel(
      id: map['id'],
      studentId: map['student_id'],
      batchId: map['batch_id'],
      joinDate: DateUtilsHelper.parseFromDb(map['join_date']),
      leaveDate: map['leave_date'] != null ? DateUtilsHelper.parseFromDb(map['leave_date']) : null,
      feeOverride: map['fee_override'] != null ? (map['fee_override'] as num).toDouble() : null,
      studentClass: map['student_class'],
      createdAt: DateUtilsHelper.parseFromDb(map['created_at']),
      batchName: map['batch_name'], // joined field
      studentName: map['student_name'], // joined field
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'batch_id': batchId,
      'join_date': DateUtilsHelper.formatForDb(joinDate),
      'leave_date': leaveDate != null ? DateUtilsHelper.formatForDb(leaveDate!) : null,
      'fee_override': feeOverride,
      'student_class': studentClass,
      'created_at': DateUtilsHelper.formatForDb(createdAt),
    };
  }
}
