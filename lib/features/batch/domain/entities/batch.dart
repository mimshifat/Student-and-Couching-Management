class Batch {
  final int? id;
  final String name;
  final String? description;
  final double monthlyFee;
  final bool isActive;
  final int studentCount;
  final DateTime createdAt;

  Batch({
    this.id,
    required this.name,
    this.description,
    this.monthlyFee = 0.0,
    this.isActive = true,
    this.studentCount = 0,
    required this.createdAt,
  });

  Batch copyWith({
    int? id,
    String? name,
    String? description,
    bool? isActive,
    int? studentCount,
    DateTime? createdAt,
  }) {
    return Batch(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      studentCount: studentCount ?? this.studentCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
