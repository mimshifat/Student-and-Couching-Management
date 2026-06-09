import '../../domain/entities/detailed_result.dart';
import '../../../../core/utils/date_utils.dart';

class DetailedResultModel extends DetailedResult {
  DetailedResultModel({
    super.id,
    required super.examId,
    required super.studentId,
    required super.batchId,
    super.obtainedMarks,
    super.isAbsent = false,
    required super.createdAt,
    required super.examTitle,
    required super.examType,
    required super.examDate,
    required super.totalMarks,
    super.batchName,
    super.studentName,
    super.studentClass,
  });

  factory DetailedResultModel.fromMap(Map<String, dynamic> map) {
    return DetailedResultModel(
      id: map['id'],
      examId: map['exam_id'],
      studentId: map['student_id'],
      batchId: map['batch_id'],
      obtainedMarks: map['obtained_marks'] != null ? (map['obtained_marks'] as num).toDouble() : null,
      isAbsent: map['is_absent'] == 1,
      createdAt: DateUtilsHelper.parseFromDb(map['created_at']),
      examTitle: map['exam_title'] ?? '',
      examType: map['exam_type'] ?? '',
      examDate: DateUtilsHelper.parseFromDb(map['exam_date']),
      totalMarks: (map['total_marks'] as num).toDouble(),
      batchName: map['batch_name'],
      studentName: map['student_name'],
      studentClass: map['class_name'],
    );
  }
}
