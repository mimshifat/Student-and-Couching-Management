class Batch {
  final int? id;
  final String name;
  final String? description;
  final String? startTime;
  final String? endTime;
  final String? scheduleDays;
  final String? timeSlot;
  final double monthlyFee;
  final bool isActive;
  final int studentCount;
  final DateTime createdAt;

  Batch({
    this.id,
    required this.name,
    this.description,
    this.startTime,
    this.endTime,
    this.scheduleDays,
    this.timeSlot,
    this.monthlyFee = 0.0,
    this.isActive = true,
    this.studentCount = 0,
    required this.createdAt,
  });

  Batch copyWith({
    int? id,
    String? name,
    String? description,
    String? startTime,
    String? endTime,
    String? scheduleDays,
    String? timeSlot,
    bool? isActive,
    int? studentCount,
    DateTime? createdAt,
  }) {
    return Batch(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      scheduleDays: scheduleDays ?? this.scheduleDays,
      timeSlot: timeSlot ?? this.timeSlot,
      isActive: isActive ?? this.isActive,
      studentCount: studentCount ?? this.studentCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
