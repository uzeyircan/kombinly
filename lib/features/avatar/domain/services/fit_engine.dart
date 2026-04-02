import 'dart:math' as math;
import 'dart:ui';

import '../models/avatar_slot.dart';
import '../models/clothing_placement.dart';

class FitResult {
  final double width;
  final double height;
  final Offset topLeft;
  final int zIndex;

  const FitResult({
    required this.width,
    required this.height,
    required this.topLeft,
    required this.zIndex,
  });
}

class FitEngine {
  const FitEngine();

  FitResult resolve({
    required Size canvasSize,
    required AvatarSlot slot,
    required ClothingPlacement placement,
    required double imageAspectRatio, // width / height
    double extraScaleMultiplier = 1.0,
    double offsetX = 0.0,
    double offsetY = 0.0,
  }) {
    final safeAspectRatio = imageAspectRatio <= 0 ? 1.0 : imageAspectRatio;

    final slotWidth = slot.widthRatio * canvasSize.width;
    final slotHeight = slot.heightRatio * canvasSize.height;

    double targetWidth;
    double targetHeight;

    switch (placement.fitStrategy) {
      case FitStrategy.contain:
        final widthBasedHeight = slotWidth / safeAspectRatio;

        if (widthBasedHeight <= slotHeight) {
          targetWidth = slotWidth;
          targetHeight = widthBasedHeight;
        } else {
          targetHeight = slotHeight;
          targetWidth = targetHeight * safeAspectRatio;
        }
        break;

      case FitStrategy.coverWidth:
        targetWidth = slotWidth;
        targetHeight = targetWidth / safeAspectRatio;
        break;

      case FitStrategy.coverHeight:
        targetHeight = slotHeight;
        targetWidth = targetHeight * safeAspectRatio;
        break;
    }

    targetWidth *= extraScaleMultiplier;
    targetHeight *= extraScaleMultiplier;

    // Aşırı taşmaları biraz yumuşat.
    // Bu tamamen kusursuz çözüm değil ama V1 için stabilite sağlar.
    final maxWidth = slotWidth * 1.35;
    final maxHeight = slotHeight * 1.45;

    targetWidth = targetWidth.clamp(1.0, maxWidth);
    targetHeight = targetHeight.clamp(1.0, maxHeight);

    final slotCenter = Offset(
      slot.centerX * canvasSize.width,
      slot.centerY * canvasSize.height,
    );

    final topLeft = Offset(
      slotCenter.dx - (targetWidth * placement.anchorX) + offsetX,
      slotCenter.dy - (targetHeight * placement.anchorY) + offsetY,
    );

    return FitResult(
      width: math.max(1.0, targetWidth),
      height: math.max(1.0, targetHeight),
      topLeft: topLeft,
      zIndex: slot.zIndex,
    );
  }
}
