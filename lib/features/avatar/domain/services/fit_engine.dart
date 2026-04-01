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
    final slotWidth = slot.widthRatio * canvasSize.width;
    final slotHeight = slot.heightRatio * canvasSize.height;

    double targetWidth;
    double targetHeight;

    switch (placement.fitStrategy) {
      case FitStrategy.contain:
        targetWidth = slotWidth;
        targetHeight = targetWidth / imageAspectRatio;

        if (targetHeight > slotHeight) {
          targetHeight = slotHeight;
          targetWidth = targetHeight * imageAspectRatio;
        }
        break;

      case FitStrategy.coverWidth:
        targetWidth = slotWidth;
        targetHeight = targetWidth / imageAspectRatio;
        break;

      case FitStrategy.coverHeight:
        targetHeight = slotHeight;
        targetWidth = targetHeight * imageAspectRatio;
        break;
    }

    targetWidth *= extraScaleMultiplier;
    targetHeight *= extraScaleMultiplier;

    final slotCenter = Offset(
      slot.centerX * canvasSize.width,
      slot.centerY * canvasSize.height,
    );

    final topLeft = Offset(
      slotCenter.dx - (targetWidth * placement.anchorX) + offsetX,
      slotCenter.dy - (targetHeight * placement.anchorY) + offsetY,
    );

    return FitResult(
      width: math.max(1, targetWidth),
      height: math.max(1, targetHeight),
      topLeft: topLeft,
      zIndex: slot.zIndex,
    );
  }
}
