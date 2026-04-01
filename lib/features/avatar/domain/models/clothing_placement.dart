enum FitStrategy { contain, coverWidth, coverHeight }

class ClothingPlacement {
  final String targetSlot;
  final double anchorX;
  final double anchorY;
  final int layerOrder;
  final FitStrategy fitStrategy;

  const ClothingPlacement({
    required this.targetSlot,
    required this.anchorX,
    required this.anchorY,
    required this.layerOrder,
    required this.fitStrategy,
  });
}
