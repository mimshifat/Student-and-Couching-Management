import '../../domain/entities/institute_profile.dart';

class InstituteProfileModel extends InstituteProfile {
  const InstituteProfileModel({
    super.id = 1,
    required super.instituteName,
    super.instituteShortName,
    required super.ownerName,
    super.phone,
    super.address,
    required super.createdAt,
    required super.updatedAt,
  });

  factory InstituteProfileModel.fromMap(Map<String, dynamic> map) {
    return InstituteProfileModel(
      id: map['id'] as int? ?? 1,
      instituteName: map['institute_name'] as String,
      instituteShortName: map['institute_short_name'] as String?,
      ownerName: map['owner_name'] as String,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'institute_name': instituteName,
      'institute_short_name': instituteShortName,
      'owner_name': ownerName,
      'phone': phone,
      'address': address,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory InstituteProfileModel.fromEntity(InstituteProfile entity) {
    return InstituteProfileModel(
      id: entity.id,
      instituteName: entity.instituteName,
      instituteShortName: entity.instituteShortName,
      ownerName: entity.ownerName,
      phone: entity.phone,
      address: entity.address,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
}
