import 'package:flutter/material.dart';

import '../../../wardrobe/domain/models/clothing_item.dart';
import '../../domain/models/avatar_slot.dart';
import '../../domain/services/fit_engine.dart';

class PlacedClothingItem extends StatelessWidget {
  final ClothingItem item;
  final Size canvasSize;
  final Widget Function(BuildContext context, Widget child)? wrapperBuilder;

  const PlacedClothingItem({
    super.key,
    required this.item,
    required this.canvasSize,
    this.wrapperBuilder,
  });

  double _fallbackAspectRatioForCategory(String category) {
    switch (category.trim().toLowerCase()) {
      case 'top':
        return 220 / 185;
      case 'bottom':
        return 185 / 210;
      case 'outerwear':
        return 220 / 220;
      case 'shoes':
        return 180 / 90;
      default:
        return 1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.renderImageUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    final placement = item.effectivePlacement;
    final slot =
        AvatarSlots.byId(placement.targetSlot) ??
        AvatarSlots.forCategory(item.category);

    final resolvedAspectRatio =
        (item.aspectRatio != null && item.aspectRatio! > 0)
        ? item.aspectRatio!
        : _fallbackAspectRatioForCategory(item.category);

    final fit = const FitEngine().resolve(
      canvasSize: canvasSize,
      slot: slot,
      placement: placement,
      imageAspectRatio: resolvedAspectRatio,
      extraScaleMultiplier: item.cropScale,
      offsetX: item.offsetX,
      offsetY: item.offsetY,
    );

    Widget child = Transform.rotate(
      angle: item.rotation,
      child: Image.network(
        imageUrl,
        width: fit.width,
        height: fit.height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );

    if (wrapperBuilder != null) {
      child = wrapperBuilder!(context, child);
    }

    return Positioned(left: fit.topLeft.dx, top: fit.topLeft.dy, child: child);
  }
}
