class MannequinManifest {
  final String id;
  final int version;
  final String status;
  final String displayName;
  final String? modelPath;
  final List<MannequinGarmentSlot> garmentSlots;

  const MannequinManifest({
    required this.id,
    required this.version,
    required this.status,
    required this.displayName,
    required this.modelPath,
    required this.garmentSlots,
  });

  factory MannequinManifest.fromJson(Map<String, dynamic> json) {
    final model = json['model'] as Map<String, dynamic>? ?? {};
    final slots = json['garmentSlots'] as List? ?? [];

    return MannequinManifest(
      id: json['id'] as String? ?? 'unknown_mannequin',
      version: (json['version'] as num?)?.toInt() ?? 1,
      status: json['status'] as String? ?? 'placeholder',
      displayName: json['displayName'] as String? ?? 'Standard Mannequin',
      modelPath: model['path'] as String?,
      garmentSlots: slots
          .whereType<Map<String, dynamic>>()
          .map(MannequinGarmentSlot.fromJson)
          .toList(),
    );
  }

  bool get hasRealModel => modelPath != null && modelPath!.trim().isNotEmpty;
}

class MannequinGarmentSlot {
  final String id;
  final String category;
  final String anchorBone;
  final String? secondaryAnchorBone;
  final int layerOrder;
  final String wrapMode;

  const MannequinGarmentSlot({
    required this.id,
    required this.category,
    required this.anchorBone,
    required this.secondaryAnchorBone,
    required this.layerOrder,
    required this.wrapMode,
  });

  factory MannequinGarmentSlot.fromJson(Map<String, dynamic> json) {
    return MannequinGarmentSlot(
      id: json['id'] as String? ?? 'unknown_slot',
      category: json['category'] as String? ?? 'Top',
      anchorBone: json['anchorBone'] as String? ?? 'chest',
      secondaryAnchorBone: json['secondaryAnchorBone'] as String?,
      layerOrder: (json['layerOrder'] as num?)?.toInt() ?? 20,
      wrapMode: json['wrapMode'] as String? ?? 'torso_front',
    );
  }
}
