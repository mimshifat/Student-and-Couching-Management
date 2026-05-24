class Batch {
  final int? id;
  final String name;
  final String? description;
  final double monthlyFee;
  final DateTime createdAt;

  Batch({
    this.id,
    required this.name,
    this.description,
    this.monthlyFee = 0.0,
    required this.createdAt,
  });

  Batch copyWith({
    int? id,
    String? name,
    String? description,
    DateTime? createdAt,
  }) {
    return Batch(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
