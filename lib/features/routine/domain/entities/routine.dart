class Routine {
  final int? id;
  final int batchId;
  final String dayOfWeek;
  final String startTime;
  final String endTime;
  final String subject;
  final String? teacherName;
  final DateTime createdAt;

  Routine({
    this.id,
    required this.batchId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.subject,
    this.teacherName,
    required this.createdAt,
  });
}
