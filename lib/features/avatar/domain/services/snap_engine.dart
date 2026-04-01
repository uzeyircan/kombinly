import 'dart:ui';

import '../models/avatar_slot.dart';

class SnapResult {
  final AvatarSlot slot;
  final double distance;
  final bool isInsideSlotBounds;

  const SnapResult({
    required this.slot,
    required this.distance,
    required this.isInsideSlotBounds,
  });
}

class SnapEngine {
  const SnapEngine();

  SnapResult? findBestSlot({
    required Offset dropPoint,
    required String targetSlotId,
    required List<AvatarSlot> availableSlots,
    required Size canvasSize,
    double snapThreshold = 120.0,
  }) {
    AvatarSlot? bestSlot;
    double bestDistance = double.infinity;
    bool insideBounds = false;

    for (final slot in availableSlots) {
      if (slot.id != targetSlotId) continue;

      final slotCenter = Offset(
        slot.centerX * canvasSize.width,
        slot.centerY * canvasSize.height,
      );

      final slotWidth = slot.widthRatio * canvasSize.width;
      final slotHeight = slot.heightRatio * canvasSize.height;

      final slotRect = Rect.fromCenter(
        center: slotCenter,
        width: slotWidth,
        height: slotHeight,
      );

      final distance = (dropPoint - slotCenter).distance;
      final containsPoint = slotRect.contains(dropPoint);

      // Öncelik: kutunun içindeyse direkt en iyi aday
      if (containsPoint) {
        if (!insideBounds || distance < bestDistance) {
          bestSlot = slot;
          bestDistance = distance;
          insideBounds = true;
        }
        continue;
      }

      // İçeride aday yoksa, eski threshold mantığı fallback olarak çalışsın
      if (!insideBounds && distance < bestDistance) {
        bestSlot = slot;
        bestDistance = distance;
      }
    }

    if (bestSlot == null) return null;

    if (!insideBounds && bestDistance > snapThreshold) {
      return null;
    }

    return SnapResult(
      slot: bestSlot,
      distance: bestDistance,
      isInsideSlotBounds: insideBounds,
    );
  }
}
