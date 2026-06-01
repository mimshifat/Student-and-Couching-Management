import '../../../../core/utils/date_utils.dart';

class BatchInactivePeriodModel {
  final int? id;
  final int batchId;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime createdAt;

  BatchInactivePeriodModel({
    this.id,
    required this.batchId,
    required this.startDate,
    this.endDate,
    required this.createdAt,
  });

  factory BatchInactivePeriodModel.fromMap(Map<String, dynamic> map) {
    return BatchInactivePeriodModel(
      id: map['id'],
      batchId: map['batch_id'],
      startDate: DateUtilsHelper.parseFromDb(map['start_date']),
      endDate: map['end_date'] != null ? DateUtilsHelper.parseFromDb(map['end_date']) : null,
      createdAt: DateUtilsHelper.parseFromDb(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'batch_id': batchId,
      'start_date': DateUtilsHelper.formatForDb(startDate),
      'end_date': endDate != null ? DateUtilsHelper.formatForDb(endDate!) : null,
      'created_at': DateUtilsHelper.formatForDb(createdAt),
    };
  }
}
