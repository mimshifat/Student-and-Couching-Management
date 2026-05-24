import '../../domain/entities/student.dart';
import '../../../../core/utils/date_utils.dart';

class StudentModel extends Student {
  StudentModel({
    super.id,
    required super.name,
    super.phone,
    super.guardianName,
    super.guardianPhone,
    super.guardianRelation,
    super.schoolCollege,
    super.className,
    super.rollNumber,
    required super.createdAt,
    required super.updatedAt,
  });

  factory StudentModel.fromEntity(Student entity) {
    return StudentModel(
      id: entity.id,
      name: entity.name,
      phone: entity.phone,
      guardianName: entity.guardianName,
      guardianPhone: entity.guardianPhone,
      guardianRelation: entity.guardianRelation,
      schoolCollege: entity.schoolCollege,
      className: entity.className,
      rollNumber: entity.rollNumber,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  factory StudentModel.fromMap(Map<String, dynamic> map) {
    return StudentModel(
      id: map['id'],
      name: map['name'],
      phone: map['phone'],
      guardianName: map['guardian_name'],
      guardianPhone: map['guardian_phone'],
      guardianRelation: map['guardian_relation'],
      schoolCollege: map['school_college'],
      className: map['class_name'],
      rollNumber: map['roll_number'],
      createdAt: DateUtilsHelper.parseFromDb(map['created_at']),
      updatedAt: DateUtilsHelper.parseFromDb(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'guardian_name': guardianName,
      'guardian_phone': guardianPhone,
      'guardian_relation': guardianRelation,
      'school_college': schoolCollege,
      'class_name': className,
      'roll_number': rollNumber,
      'created_at': DateUtilsHelper.formatForDb(createdAt),
      'updated_at': DateUtilsHelper.formatForDb(updatedAt),
    };
  }
}
