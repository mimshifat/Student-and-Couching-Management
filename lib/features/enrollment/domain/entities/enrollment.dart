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

  static const Object _sentinel = Object();

  Enrollment copyWith({
    int? id,
    int? studentId,
    int? batchId,
    DateTime? joinDate,
    Object? leaveDate = _sentinel,
    Object? feeOverride = _sentinel,
    Object? studentClass = _sentinel,
    Object? batchNameSnapshot = _sentinel,
    Object? batchScheduleDaysSnapshot = _sentinel,
    Object? batchTimeSlotSnapshot = _sentinel,
    DateTime? createdAt,
    Object? batchName = _sentinel,
    Object? studentName = _sentinel,
  }) {
    return Enrollment(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      batchId: batchId ?? this.batchId,
      joinDate: joinDate ?? this.joinDate,
      leaveDate: leaveDate == _sentinel ? this.leaveDate : leaveDate as DateTime?,
      feeOverride: feeOverride == _sentinel ? this.feeOverride : feeOverride as double?,
      studentClass: studentClass == _sentinel ? this.studentClass : studentClass as String?,
      batchNameSnapshot: batchNameSnapshot == _sentinel ? this.batchNameSnapshot : batchNameSnapshot as String?,
      batchScheduleDaysSnapshot: batchScheduleDaysSnapshot == _sentinel ? this.batchScheduleDaysSnapshot : batchScheduleDaysSnapshot as String?,
      batchTimeSlotSnapshot: batchTimeSlotSnapshot == _sentinel ? this.batchTimeSlotSnapshot : batchTimeSlotSnapshot as String?,
      createdAt: createdAt ?? this.createdAt,
      batchName: batchName == _sentinel ? this.batchName : batchName as String?,
      studentName: studentName == _sentinel ? this.studentName : studentName as String?,
    );
  }
}
