class Student {
  final int? id;
  final String name;
  final String? phone;
  final String? guardianName;
  final String? guardianPhone;
  final String? schoolCollege;
  final String? className;
  final int? rollNumber;
  final DateTime admissionDate;
  final double monthlyFee;
  final String status; // 'Running' or 'Previous'
  final DateTime createdAt;
  final DateTime updatedAt;

  Student({
    this.id,
    required this.name,
    this.phone,
    this.guardianName,
    this.guardianPhone,
    this.schoolCollege,
    this.className,
    this.rollNumber,
    required this.admissionDate,
    required this.monthlyFee,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  Student copyWith({
    int? id,
    String? name,
    String? phone,
    String? guardianName,
    String? guardianPhone,
    String? schoolCollege,
    String? className,
    int? rollNumber,
    DateTime? admissionDate,
    double? monthlyFee,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Student(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      guardianName: guardianName ?? this.guardianName,
      guardianPhone: guardianPhone ?? this.guardianPhone,
      schoolCollege: schoolCollege ?? this.schoolCollege,
      className: className ?? this.className,
      rollNumber: rollNumber ?? this.rollNumber,
      admissionDate: admissionDate ?? this.admissionDate,
      monthlyFee: monthlyFee ?? this.monthlyFee,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
