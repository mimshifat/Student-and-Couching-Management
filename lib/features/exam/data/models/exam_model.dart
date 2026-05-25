import '../../domain/entities/exam.dart';
import '../../../../core/utils/date_utils.dart';

class ExamModel extends Exam {
  ExamModel({
    super.id,
    required super.batchId,
    required super.title,
    required super.examType,
    required super.examDate,
    required super.totalMarks,
    required super.createdAt,
    super.batchName,
  });

  factory ExamModel.fromEntity(Exam entity) {
    return ExamModel(
      id: entity.id,
      batchId: entity.batchId,
      title: entity.title,
      examType: entity.examType,
      examDate: entity.examDate,
      totalMarks: entity.totalMarks,
      createdAt: entity.createdAt,
      batchName: entity.batchName,
    );
  }

  factory ExamModel.fromMap(Map<String, dynamic> map) {
    return ExamModel(
      id: map['id'],
      batchId: map['batch_id'],
      title: map['title'],
      examType: map['exam_type'] ?? 'Monthly', // Fallback for old records
      examDate: DateUtilsHelper.parseFromDb(map['exam_date']),
      totalMarks: (map['total_marks'] as num).toDouble(),
      createdAt: DateUtilsHelper.parseFromDb(map['created_at']),
      batchName: map['batch_name'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'batch_id': batchId,
      'title': title,
      'exam_type': examType,
      'exam_date': DateUtilsHelper.formatForDb(examDate),
      'total_marks': totalMarks,
      'created_at': DateUtilsHelper.formatForDb(createdAt),
    };
  }
}
