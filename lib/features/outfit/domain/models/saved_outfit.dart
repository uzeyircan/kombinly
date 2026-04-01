class SavedOutfit {
  final String id;
  final String? topId;
  final String? bottomId;
  final String? shoesId;
  final String? season;
  final String? occasion;
  final DateTime createdAt;

  SavedOutfit({
    required this.id,
    required this.topId,
    required this.bottomId,
    required this.shoesId,
    required this.season,
    required this.occasion,
    required this.createdAt,
  });

  factory SavedOutfit.fromMap(Map<String, dynamic> map) {
    return SavedOutfit(
      id: map['id'] as String,
      topId: map['top_id'] as String?,
      bottomId: map['bottom_id'] as String?,
      shoesId: map['shoes_id'] as String?,
      season: map['season'] as String?,
      occasion: map['occasion'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
