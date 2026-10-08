/// Pre-aggregated batch performance summary returned from a SQL GROUP BY query.
/// Much lighter than loading thousands of raw DetailedResult rows.
class BatchSummary {
  final int batchId;
  final String batchName;
  final int totalResults;
  final int totalExams;
  final int absentCount;
  final double totalObtained;
  final double totalAvailable;
  final int totalStudents;
  final int presentStudents;

  const BatchSummary({
    required this.batchId,
    required this.batchName,
    required this.totalResults,
    required this.totalExams,
    required this.absentCount,
    required this.totalObtained,
    required this.totalAvailable,
    required this.totalStudents,
    required this.presentStudents,
  });

  double get avgPercent =>
      totalAvailable > 0 ? (totalObtained / totalAvailable) * 100 : 0.0;

  double get attendanceRate =>
      totalResults > 0 ? ((totalResults - absentCount) / totalResults) * 100 : 0.0;
}
