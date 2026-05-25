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
    super.batchNameSnapshot,
    super.batchScheduleDaysSnapshot,
    super.batchTimeSlotSnapshot,
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
      batchNameSnapshot: entity.batchNameSnapshot,
      batchScheduleDaysSnapshot: entity.batchScheduleDaysSnapshot,
      batchTimeSlotSnapshot: entity.batchTimeSlotSnapshot,
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
      feeOverride: (map['fee_override'] as num?)?.toDouble(),
      studentClass: map['student_class'],
      batchNameSnapshot: map['batch_name'],
      batchScheduleDaysSnapshot: map['batch_schedule_days'],
      batchTimeSlotSnapshot: map['batch_time_slot'],
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
      'batch_name': batchNameSnapshot,
      'batch_schedule_days': batchScheduleDaysSnapshot,
      'batch_time_slot': batchTimeSlotSnapshot,
      'created_at': DateUtilsHelper.formatForDb(createdAt),
    };
  }
}
