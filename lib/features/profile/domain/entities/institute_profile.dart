class InstituteProfile {
  final int id;
  final String instituteName;
  final String? instituteShortName;
  final String ownerName;
  final String? phone;
  final String? address;
  final DateTime createdAt;
  final DateTime updatedAt;

  const InstituteProfile({
    this.id = 1,
    required this.instituteName,
    this.instituteShortName,
    required this.ownerName,
    this.phone,
    this.address,
    required this.createdAt,
    required this.updatedAt,
  });

  InstituteProfile copyWith({
    int? id,
    String? instituteName,
    String? instituteShortName,
    String? ownerName,
    String? phone,
    String? address,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InstituteProfile(
      id: id ?? this.id,
      instituteName: instituteName ?? this.instituteName,
      instituteShortName: instituteShortName ?? this.instituteShortName,
      ownerName: ownerName ?? this.ownerName,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
