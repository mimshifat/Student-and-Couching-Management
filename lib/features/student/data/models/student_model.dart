import '../../domain/entities/student.dart';
import '../../../../core/utils/date_utils.dart';

class StudentModel extends Student {
  StudentModel({
    super.id,
    required super.name,
    super.phone,
    super.guardianName,
    super.guardianPhone,
    super.schoolCollege,
    super.className,
    super.rollNumber,
    required super.admissionDate,
    required super.monthlyFee,
    required super.status,
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
      schoolCollege: entity.schoolCollege,
      className: entity.className,
      rollNumber: entity.rollNumber,
      admissionDate: entity.admissionDate,
      monthlyFee: entity.monthlyFee,
      status: entity.status,
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
      schoolCollege: map['school_college'],
      className: map['class_name'],
      rollNumber: map['roll_number'],
      admissionDate: DateUtilsHelper.parseFromDb(map['admission_date']),
      monthlyFee: (map['monthly_fee'] as num).toDouble(),
      status: map['status'],
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
      'school_college': schoolCollege,
      'class_name': className,
      'roll_number': rollNumber,
      'admission_date': DateUtilsHelper.formatForDb(admissionDate),
      'monthly_fee': monthlyFee,
      'status': status,
      'created_at': DateUtilsHelper.formatForDb(createdAt),
      'updated_at': DateUtilsHelper.formatForDb(updatedAt),
    };
  }
}
