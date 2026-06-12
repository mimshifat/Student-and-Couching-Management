/// Pre-aggregated batch performance summary returned from a SQL GROUP BY query.
/// Much lighter than loading thousands of raw DetailedResult rows.
class BatchSummary {
  final int batchId;
  final String batchName;
  final int totalResults;
  final int absentCount;
  final double totalObtained;
  final double totalAvailable;
  final int uniqueStudents;

  const BatchSummary({
    required this.batchId,
    required this.batchName,
    required this.totalResults,
    required this.absentCount,
    required this.totalObtained,
    required this.totalAvailable,
    required this.uniqueStudents,
  });

  double get avgPercent =>
      totalAvailable > 0 ? (totalObtained / totalAvailable) * 100 : 0.0;

  int get presentCount => totalResults - absentCount;
}
