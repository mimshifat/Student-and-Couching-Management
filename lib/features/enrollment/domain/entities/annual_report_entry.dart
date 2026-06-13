/// Holds all batch enrollments for a single student in a given year.
/// Multiple enrollments in different batches are grouped under one entry.
class AnnualReportEntry {
  final int studentId;

  /// Student name. Falls back to '[Deleted Student]' if the student was removed.
  final String studentName;

  /// Current phone number from the students table (null if student deleted).
  final String? phone;

  /// All batches this student was enrolled in during the report year.
  final List<BatchInfo> batches;

  const AnnualReportEntry({
    required this.studentId,
    required this.studentName,
    this.phone,
    required this.batches,
  });
}

/// Snapshot of one batch enrollment — all fields captured at enrollment time.
/// Remains accurate even if the batch is later edited or deleted.
class BatchInfo {
  /// Batch name as it was when the student enrolled (snapshot).
  final String? batchName;

  /// Student's class as it was when they enrolled (snapshot).
  final String? studentClass;

  /// Scheduled days as they were when the student enrolled (snapshot).
  final String? scheduleDays;

  /// Time slot as it was when the student enrolled (snapshot).
  final String? timeSlot;

  const BatchInfo({
    this.batchName,
    this.studentClass,
    this.scheduleDays,
    this.timeSlot,
  });
}
