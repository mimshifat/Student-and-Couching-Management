import '../../domain/entities/batch.dart';
import '../../../../core/utils/date_utils.dart';

class BatchModel extends Batch {
  BatchModel({
    super.id,
    required super.name,
    super.description,
    super.monthlyFee = 0.0,
    required super.createdAt,
  });

  factory BatchModel.fromEntity(Batch entity) {
    return BatchModel(
      id: entity.id,
      name: entity.name,
      description: entity.description,
      monthlyFee: entity.monthlyFee,
      createdAt: entity.createdAt,
    );
  }

  factory BatchModel.fromMap(Map<String, dynamic> map) {
    return BatchModel(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      monthlyFee: (map['monthly_fee'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateUtilsHelper.parseFromDb(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'monthly_fee': monthlyFee,
      'created_at': DateUtilsHelper.formatForDb(createdAt),
    };
  }
}
