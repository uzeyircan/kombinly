// ignore_for_file: avoid_dynamic_calls

class MannequinManifest {
  final String id;
  final int version;
  final String status;
  final String displayName;
  final String? modelPath;
  final MannequinCamera camera;
  final MannequinLighting lighting;
  final MannequinRenderSettings renderSettings;
  final List<MannequinGarmentSlot> garmentSlots;

  const MannequinManifest({
    required this.id,
    required this.version,
    required this.status,
    required this.displayName,
    required this.modelPath,
    required this.camera,
    required this.lighting,
    required this.renderSettings,
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
      camera: MannequinCamera.fromJson(
        json['camera'] as Map<String, dynamic>? ?? {},
      ),
      lighting: MannequinLighting.fromJson(
        json['lighting'] as Map<String, dynamic>? ?? {},
      ),
      renderSettings: MannequinRenderSettings.fromJson(
        json['renderSettings'] as Map<String, dynamic>? ?? {},
      ),
      garmentSlots: slots
          .whereType<Map<String, dynamic>>()
          .map(MannequinGarmentSlot.fromJson)
          .toList(),
    );
  }

  bool get hasRealModel =>
      modelPath != null &&
      modelPath!.trim().isNotEmpty &&
      status == 'ready';

  MannequinGarmentSlot? slotForCategory(String category) {
    final normalized = category.trim().toLowerCase();
    for (final slot in garmentSlots) {
      if (slot.category.toLowerCase() == normalized) return slot;
    }
    return null;
  }
}

// ── Camera ──────────────────────────────────────────────────────────────────

class MannequinCamera {
  final double initialYaw;
  final double initialPitch;
  final double initialZoom;
  final double minZoom;
  final double maxZoom;
  final double orbitSensitivity;

  const MannequinCamera({
    required this.initialYaw,
    required this.initialPitch,
    required this.initialZoom,
    required this.minZoom,
    required this.maxZoom,
    required this.orbitSensitivity,
  });

  factory MannequinCamera.fromJson(Map<String, dynamic> json) {
    return MannequinCamera(
      initialYaw: (json['initialYaw'] as num?)?.toDouble() ?? 0,
      initialPitch: (json['initialPitch'] as num?)?.toDouble() ?? -5,
      initialZoom: (json['initialZoom'] as num?)?.toDouble() ?? 1.0,
      minZoom: (json['minZoom'] as num?)?.toDouble() ?? 0.7,
      maxZoom: (json['maxZoom'] as num?)?.toDouble() ?? 1.5,
      orbitSensitivity: (json['orbitSensitivity'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

// ── Lighting ────────────────────────────────────────────────────────────────

class MannequinLighting {
  final double ambientIntensity;
  final double directionalIntensity;
  final bool shadowEnabled;
  final double shadowSoftness;

  const MannequinLighting({
    required this.ambientIntensity,
    required this.directionalIntensity,
    required this.shadowEnabled,
    required this.shadowSoftness,
  });

  factory MannequinLighting.fromJson(Map<String, dynamic> json) {
    return MannequinLighting(
      ambientIntensity:
          (json['ambientIntensity'] as num?)?.toDouble() ?? 0.85,
      directionalIntensity:
          (json['directionalIntensity'] as num?)?.toDouble() ?? 1.2,
      shadowEnabled: json['shadowEnabled'] as bool? ?? true,
      shadowSoftness: (json['shadowSoftness'] as num?)?.toDouble() ?? 0.6,
    );
  }
}

// ── Render Settings ─────────────────────────────────────────────────────────

class MannequinRenderSettings {
  final String quality;
  final bool antiAlias;
  final double toneMappingExposure;
  final double backgroundAlpha;

  const MannequinRenderSettings({
    required this.quality,
    required this.antiAlias,
    required this.toneMappingExposure,
    required this.backgroundAlpha,
  });

  factory MannequinRenderSettings.fromJson(Map<String, dynamic> json) {
    return MannequinRenderSettings(
      quality: json['quality'] as String? ?? 'high',
      antiAlias: json['antiAlias'] as bool? ?? true,
      toneMappingExposure:
          (json['toneMappingExposure'] as num?)?.toDouble() ?? 1.1,
      backgroundAlpha:
          (json['backgroundAlpha'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// ── Garment Slot ────────────────────────────────────────────────────────────

class GarmentOverlayAnchor {
  final double topRatio;
  final double centerXRatio;
  final double widthRatio;
  final double heightRatio;

  const GarmentOverlayAnchor({
    required this.topRatio,
    required this.centerXRatio,
    required this.widthRatio,
    required this.heightRatio,
  });

  factory GarmentOverlayAnchor.fromJson(Map<String, dynamic> json) {
    return GarmentOverlayAnchor(
      topRatio: (json['topRatio'] as num?)?.toDouble() ?? 0.12,
      centerXRatio: (json['centerXRatio'] as num?)?.toDouble() ?? 0.50,
      widthRatio: (json['widthRatio'] as num?)?.toDouble() ?? 0.50,
      heightRatio: (json['heightRatio'] as num?)?.toDouble() ?? 0.35,
    );
  }
}

class MannequinGarmentSlot {
  final String id;
  final String category;
  final String anchorBone;
  final String? secondaryAnchorBone;
  final int layerOrder;
  final String wrapMode;
  final int zIndex;
  final double perspectiveWeight;
  final GarmentOverlayAnchor overlayAnchor;

  const MannequinGarmentSlot({
    required this.id,
    required this.category,
    required this.anchorBone,
    required this.secondaryAnchorBone,
    required this.layerOrder,
    required this.wrapMode,
    required this.zIndex,
    required this.perspectiveWeight,
    required this.overlayAnchor,
  });

  factory MannequinGarmentSlot.fromJson(Map<String, dynamic> json) {
    return MannequinGarmentSlot(
      id: json['id'] as String? ?? 'unknown_slot',
      category: json['category'] as String? ?? 'Top',
      anchorBone: json['anchorBone'] as String? ?? 'chest',
      secondaryAnchorBone: json['secondaryAnchorBone'] as String?,
      layerOrder: (json['layerOrder'] as num?)?.toInt() ?? 20,
      wrapMode: json['wrapMode'] as String? ?? 'torso_front',
      zIndex: (json['zIndex'] as num?)?.toInt() ?? 20,
      perspectiveWeight:
          (json['perspectiveWeight'] as num?)?.toDouble() ?? 0.80,
      overlayAnchor: GarmentOverlayAnchor.fromJson(
        json['overlayAnchor'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}
