class Enrollment {
  final int? id;
  final int studentId;
  final int batchId;
  final DateTime joinDate;
  final DateTime? leaveDate;
  final double? feeOverride; // Custom fee that overrides batch fee
  final String? studentClass; // Snapshot of student's class
  final String? batchNameSnapshot;
  final String? batchScheduleDaysSnapshot;
  final String? batchTimeSlotSnapshot;
  final DateTime createdAt;

  // Transient fields for display
  final String? batchName;
  final String? studentName;

  Enrollment({
    this.id,
    required this.studentId,
    required this.batchId,
    required this.joinDate,
    this.leaveDate,
    this.feeOverride,
    this.studentClass,
    this.batchNameSnapshot,
    this.batchScheduleDaysSnapshot,
    this.batchTimeSlotSnapshot,
    required this.createdAt,
    this.batchName,
    this.studentName,
  });

  Enrollment copyWith({
    int? id,
    int? studentId,
    int? batchId,
    DateTime? joinDate,
    DateTime? leaveDate,
    double? feeOverride,
    String? studentClass,
    String? batchNameSnapshot,
    String? batchScheduleDaysSnapshot,
    String? batchTimeSlotSnapshot,
    DateTime? createdAt,
    String? batchName,
    String? studentName,
  }) {
    return Enrollment(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      batchId: batchId ?? this.batchId,
      joinDate: joinDate ?? this.joinDate,
      leaveDate: leaveDate ?? this.leaveDate,
      feeOverride: feeOverride ?? this.feeOverride,
      studentClass: studentClass ?? this.studentClass,
      batchNameSnapshot: batchNameSnapshot ?? this.batchNameSnapshot,
      batchScheduleDaysSnapshot: batchScheduleDaysSnapshot ?? this.batchScheduleDaysSnapshot,
      batchTimeSlotSnapshot: batchTimeSlotSnapshot ?? this.batchTimeSlotSnapshot,
      createdAt: createdAt ?? this.createdAt,
      batchName: batchName ?? this.batchName,
      studentName: studentName ?? this.studentName,
    );
  }
}
