import '../../domain/entities/batch.dart';
import '../../../../core/utils/date_utils.dart';

class BatchModel extends Batch {
  BatchModel({
    super.id,
    required super.name,
    super.description,
    super.startTime,
    super.endTime,
    super.scheduleDays,
    super.timeSlot,
    super.monthlyFee = 0.0,
    super.isActive = true,
    super.isDeleted = false,
    super.studentCount = 0,
    required super.createdAt,
  });

  factory BatchModel.fromEntity(Batch entity) {
    return BatchModel(
      id: entity.id,
      name: entity.name,
      description: entity.description,
      startTime: entity.startTime,
      endTime: entity.endTime,
      scheduleDays: entity.scheduleDays,
      timeSlot: entity.timeSlot,
      monthlyFee: entity.monthlyFee,
      isActive: entity.isActive,
      isDeleted: entity.isDeleted,
      studentCount: entity.studentCount,
      createdAt: entity.createdAt,
    );
  }

  factory BatchModel.fromMap(Map<String, dynamic> map) {
    return BatchModel(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      startTime: map['start_time'],
      endTime: map['end_time'],
      scheduleDays: map['schedule_days'],
      timeSlot: map['time_slot'],
      monthlyFee: (map['monthly_fee'] as num?)?.toDouble() ?? 0.0,
      isActive: map['is_active'] == 1,
      isDeleted: map['is_deleted'] == 1,
      studentCount: map['student_count'] ?? 0,
      createdAt: DateUtilsHelper.parseFromDb(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'start_time': startTime,
      'end_time': endTime,
      'schedule_days': scheduleDays,
      'time_slot': timeSlot,
      'monthly_fee': monthlyFee,
      'is_active': isActive ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': DateUtilsHelper.formatForDb(createdAt),
    };
  }
}
