class Enrollment {
  final int? id;
  final int studentId;
  final int batchId;
  final DateTime joinDate;
  final DateTime? leaveDate;
  final double? feeOverride; // Custom fee that overrides batch fee
  final String? studentClass; // Snapshot of student's class
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
      createdAt: createdAt ?? this.createdAt,
      batchName: batchName ?? this.batchName,
      studentName: studentName ?? this.studentName,
    );
  }
}
