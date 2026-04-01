import '../../../avatar/domain/models/clothing_placement.dart';

class ClothingItem {
  final String id;
  final String title;
  final String category;
  final String color;
  final String season;
  final String occasion;
  final String? imageUrl;
  final String? processedImageUrl;
  final double cropScale;
  final double offsetX;
  final double offsetY;
  final double rotation;
  final double? aspectRatio;
  final String? fitProfile;
  final bool isProcessed;

  // Yeni placement alanları
  final String? targetSlot;
  final double? anchorX;
  final double? anchorY;
  final int? layerOrder;
  final String? fitStrategy;

  ClothingItem({
    required this.id,
    required this.title,
    required this.category,
    required this.color,
    required this.season,
    required this.occasion,
    required this.imageUrl,
    required this.processedImageUrl,
    required this.cropScale,
    required this.offsetX,
    required this.offsetY,
    required this.rotation,
    required this.aspectRatio,
    required this.fitProfile,
    required this.isProcessed,
    this.targetSlot,
    this.anchorX,
    this.anchorY,
    this.layerOrder,
    this.fitStrategy,
  });

  factory ClothingItem.fromMap(Map<String, dynamic> map) {
    return ClothingItem(
      id: map['id'] as String,
      title: map['title'] as String,
      category: map['category'] as String,
      color: map['color'] as String,
      season: map['season'] as String,
      occasion: (map['occasion'] as String?) ?? 'Casual',
      imageUrl: map['image_url'] as String?,
      processedImageUrl: map['processed_image_url'] as String?,
      cropScale: ((map['crop_scale'] ?? 1.0) as num).toDouble(),
      offsetX: ((map['offset_x'] ?? 0.0) as num).toDouble(),
      offsetY: ((map['offset_y'] ?? 0.0) as num).toDouble(),
      rotation: ((map['rotation'] ?? 0.0) as num).toDouble(),
      aspectRatio: (map['aspect_ratio'] as num?)?.toDouble(),
      fitProfile: map['fit_profile'] as String?,
      isProcessed: (map['is_processed'] as bool?) ?? false,

      targetSlot: map['target_slot'] as String?,
      anchorX: (map['anchor_x'] as num?)?.toDouble(),
      anchorY: (map['anchor_y'] as num?)?.toDouble(),
      layerOrder: map['layer_order'] as int?,
      fitStrategy: map['fit_strategy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'color': color,
      'season': season,
      'occasion': occasion,
      'image_url': imageUrl,
      'processed_image_url': processedImageUrl,
      'crop_scale': cropScale,
      'offset_x': offsetX,
      'offset_y': offsetY,
      'rotation': rotation,
      'aspect_ratio': aspectRatio,
      'fit_profile': fitProfile,
      'is_processed': isProcessed,

      'target_slot': targetSlot,
      'anchor_x': anchorX,
      'anchor_y': anchorY,
      'layer_order': layerOrder,
      'fit_strategy': fitStrategy,
    };
  }

  ClothingItem copyWith({
    String? id,
    String? title,
    String? category,
    String? color,
    String? season,
    String? occasion,
    String? imageUrl,
    String? processedImageUrl,
    double? cropScale,
    double? offsetX,
    double? offsetY,
    double? rotation,
    double? aspectRatio,
    String? fitProfile,
    bool? isProcessed,
    String? targetSlot,
    double? anchorX,
    double? anchorY,
    int? layerOrder,
    String? fitStrategy,
  }) {
    return ClothingItem(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      color: color ?? this.color,
      season: season ?? this.season,
      occasion: occasion ?? this.occasion,
      imageUrl: imageUrl ?? this.imageUrl,
      processedImageUrl: processedImageUrl ?? this.processedImageUrl,
      cropScale: cropScale ?? this.cropScale,
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
      rotation: rotation ?? this.rotation,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      fitProfile: fitProfile ?? this.fitProfile,
      isProcessed: isProcessed ?? this.isProcessed,
      targetSlot: targetSlot ?? this.targetSlot,
      anchorX: anchorX ?? this.anchorX,
      anchorY: anchorY ?? this.anchorY,
      layerOrder: layerOrder ?? this.layerOrder,
      fitStrategy: fitStrategy ?? this.fitStrategy,
    );
  }

  ClothingPlacement get effectivePlacement {
    return ClothingPlacement(
      targetSlot: targetSlot ?? _defaultTargetSlotForCategory(category),
      anchorX: anchorX ?? _defaultAnchorXForCategory(category),
      anchorY: anchorY ?? _defaultAnchorYForCategory(category),
      layerOrder: layerOrder ?? _defaultLayerOrderForCategory(category),
      fitStrategy:
          _parseFitStrategy(fitStrategy) ??
          _defaultFitStrategyForCategory(category),
    );
  }

  static String _defaultTargetSlotForCategory(String category) {
    switch (category.trim().toLowerCase()) {
      case 'top':
        return 'upper_body';
      case 'bottom':
        return 'lower_body';
      case 'outerwear':
        return 'outerwear';
      case 'shoes':
        return 'feet';
      default:
        return 'upper_body';
    }
  }

  static double _defaultAnchorXForCategory(String category) {
    return 0.5;
  }

  static double _defaultAnchorYForCategory(String category) {
    switch (category.trim().toLowerCase()) {
      case 'top':
        return 0.18;
      case 'bottom':
        return 0.10;
      case 'outerwear':
        return 0.12;
      case 'shoes':
        return 0.35;
      default:
        return 0.18;
    }
  }

  static int _defaultLayerOrderForCategory(String category) {
    switch (category.trim().toLowerCase()) {
      case 'shoes':
        return 10;
      case 'bottom':
        return 15;
      case 'top':
        return 20;
      case 'outerwear':
        return 25;
      default:
        return 20;
    }
  }

  static FitStrategy _defaultFitStrategyForCategory(String category) {
    switch (category.trim().toLowerCase()) {
      case 'shoes':
        return FitStrategy.coverWidth;
      case 'outerwear':
        return FitStrategy.contain;
      case 'top':
      case 'bottom':
      default:
        return FitStrategy.contain;
    }
  }

  static FitStrategy? _parseFitStrategy(String? raw) {
    switch (raw) {
      case 'contain':
        return FitStrategy.contain;
      case 'coverWidth':
        return FitStrategy.coverWidth;
      case 'coverHeight':
        return FitStrategy.coverHeight;
      default:
        return null;
    }
  }
}
