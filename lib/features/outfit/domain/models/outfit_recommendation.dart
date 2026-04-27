import '../../../wardrobe/domain/models/clothing_item.dart';
import 'outfit_request.dart';

class OutfitRecommendation {
  final OutfitRequest request;
  final ClothingItem? top;
  final ClothingItem? bottom;
  final ClothingItem? shoes;
  final ClothingItem? outerwear;
  final ClothingItem? accessory;
  final int score;
  final String reason;
  final List<String> missingItems;

  const OutfitRecommendation({
    required this.request,
    required this.top,
    required this.bottom,
    required this.shoes,
    required this.outerwear,
    required this.accessory,
    required this.score,
    required this.reason,
    required this.missingItems,
  });

  List<ClothingItem> get selectedItems {
    return <ClothingItem>[?top, ?bottom, ?shoes, ?outerwear, ?accessory];
  }

  bool get hasAnyItem => selectedItems.isNotEmpty;

  OutfitRecommendation copyWith({
    ClothingItem? top,
    ClothingItem? bottom,
    ClothingItem? shoes,
    ClothingItem? outerwear,
    ClothingItem? accessory,
    int? score,
    String? reason,
    List<String>? missingItems,
  }) {
    return OutfitRecommendation(
      request: request,
      top: top ?? this.top,
      bottom: bottom ?? this.bottom,
      shoes: shoes ?? this.shoes,
      outerwear: outerwear ?? this.outerwear,
      accessory: accessory ?? this.accessory,
      score: score ?? this.score,
      reason: reason ?? this.reason,
      missingItems: missingItems ?? this.missingItems,
    );
  }

  Map<String, dynamic> selectedItemsMap() {
    return {
      if (top != null) 'top_id': top!.id,
      if (bottom != null) 'bottom_id': bottom!.id,
      if (shoes != null) 'shoes_id': shoes!.id,
      if (outerwear != null) 'outerwear_id': outerwear!.id,
      if (accessory != null) 'accessory_id': accessory!.id,
    };
  }
}
