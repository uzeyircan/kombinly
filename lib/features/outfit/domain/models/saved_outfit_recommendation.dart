class SavedOutfitRecommendation {
  final String id;
  final String sourceType;
  final String scenario;
  final String? style;
  final String? environment;
  final String? gender;
  final Map<String, dynamic> selectedItems;
  final String? aiReason;
  final num? score;
  final List<String> missingItems;
  final DateTime createdAt;

  const SavedOutfitRecommendation({
    required this.id,
    required this.sourceType,
    required this.scenario,
    required this.style,
    required this.environment,
    required this.gender,
    required this.selectedItems,
    required this.aiReason,
    required this.score,
    required this.missingItems,
    required this.createdAt,
  });

  factory SavedOutfitRecommendation.fromMap(Map<String, dynamic> map) {
    return SavedOutfitRecommendation(
      id: map['id'] as String,
      sourceType: (map['source_type'] as String?) ?? 'wardrobe',
      scenario: (map['scenario'] as String?) ?? 'Scenario',
      style: map['style'] as String?,
      environment: map['environment'] as String?,
      gender: map['gender'] as String?,
      selectedItems:
          (map['selected_items'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      aiReason: map['ai_reason'] as String?,
      score: map['score'] as num?,
      missingItems: _parseStringList(map['missing_items']),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  String? get topId => selectedItems['top_id'] as String?;
  String? get bottomId => selectedItems['bottom_id'] as String?;
  String? get shoesId => selectedItems['shoes_id'] as String?;
  String? get outerwearId => selectedItems['outerwear_id'] as String?;
  String? get accessoryId => selectedItems['accessory_id'] as String?;

  static List<String> _parseStringList(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    return const [];
  }
}
