import '../../domain/entities/result.dart';
import '../../../../core/utils/date_utils.dart';

class ResultModel extends ExamResult {
  ResultModel({
    super.id,
    required super.examId,
    required super.studentId,
    required super.batchId,
    super.obtainedMarks,
    super.isAbsent = false,
    required super.createdAt,
    super.studentName,
  });

  factory ResultModel.fromEntity(ExamResult entity) {
    return ResultModel(
      id: entity.id,
      examId: entity.examId,
      studentId: entity.studentId,
      batchId: entity.batchId,
      obtainedMarks: entity.obtainedMarks,
      isAbsent: entity.isAbsent,
      createdAt: entity.createdAt,
      studentName: entity.studentName,
    );
  }

  factory ResultModel.fromMap(Map<String, dynamic> map) {
    return ResultModel(
      id: map['id'],
      examId: map['exam_id'],
      studentId: map['student_id'],
      batchId: map['batch_id'],
      obtainedMarks: map['obtained_marks'] != null ? (map['obtained_marks'] as num).toDouble() : null,
      isAbsent: map['is_absent'] == 1,
      createdAt: DateUtilsHelper.parseFromDb(map['created_at']),
      studentName: map['student_name'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'exam_id': examId,
      'student_id': studentId,
      'batch_id': batchId,
      'obtained_marks': obtainedMarks,
      'is_absent': isAbsent ? 1 : 0,
      'created_at': DateUtilsHelper.formatForDb(createdAt),
    };
  }
}
