class SmartPlacementResult {
  final double cropScale;
  final double offsetX;
  final double offsetY;
  final double rotation;

  const SmartPlacementResult({
    required this.cropScale,
    required this.offsetX,
    required this.offsetY,
    required this.rotation,
  });
}

class SmartPlacementService {
  const SmartPlacementService();

  SmartPlacementResult resolve({
    required String category,
    required double aspectRatio,
    String? fitProfile,
  }) {
    final normalizedCategory = category.trim().toLowerCase();
    final normalizedFitProfile = fitProfile?.trim().toLowerCase();

    switch (normalizedCategory) {
      case 'top':
        return _resolveTop(
          aspectRatio: aspectRatio,
          fitProfile: normalizedFitProfile,
        );
      case 'bottom':
        return _resolveBottom(
          aspectRatio: aspectRatio,
          fitProfile: normalizedFitProfile,
        );
      case 'shoes':
        return _resolveShoes(
          aspectRatio: aspectRatio,
          fitProfile: normalizedFitProfile,
        );
      case 'outerwear':
        return _resolveOuterwear(
          aspectRatio: aspectRatio,
          fitProfile: normalizedFitProfile,
        );
      default:
        return const SmartPlacementResult(
          cropScale: 1.0,
          offsetX: 0.0,
          offsetY: 0.0,
          rotation: 0.0,
        );
    }
  }

  SmartPlacementResult _resolveTop({
    required double aspectRatio,
    String? fitProfile,
  }) {
    double cropScale;
    double offsetY;

    switch (fitProfile) {
      case 'long_top':
        cropScale = 1.15;
        offsetY = 10;
        break;

      case 'oversized_top':
        cropScale = 1.10;
        offsetY = 4;
        break;

      default: // regular
        cropScale = 1.22;
        offsetY = -6;
    }

    return SmartPlacementResult(
      cropScale: cropScale,
      offsetX: 0,
      offsetY: offsetY,
      rotation: 0,
    );
  }

  SmartPlacementResult _resolveBottom({
    required double aspectRatio,
    String? fitProfile,
  }) {
    double cropScale = 1.0;
    double offsetY = 8.0;

    if (aspectRatio < 0.50) {
      cropScale = 0.92;
      offsetY = 18.0;
    } else if (aspectRatio < 0.68) {
      cropScale = 1.0;
      offsetY = 10.0;
    } else if (aspectRatio < 0.90) {
      cropScale = 1.06;
      offsetY = 4.0;
    } else {
      cropScale = 1.12;
      offsetY = 0.0;
    }

    if (fitProfile == 'wide_bottom') {
      cropScale -= 0.05;
      offsetY += 4.0;
    }

    if (fitProfile == 'skinny_bottom') {
      cropScale += 0.03;
      offsetY -= 2.0;
    }

    return SmartPlacementResult(
      cropScale: cropScale,
      offsetX: 0.0,
      offsetY: offsetY,
      rotation: 0.0,
    );
  }

  SmartPlacementResult _resolveShoes({
    required double aspectRatio,
    String? fitProfile,
  }) {
    double cropScale = 1.0;
    double offsetY = 18.0;

    if (aspectRatio < 1.10) {
      cropScale = 0.82;
      offsetY = 10.0;
    } else if (aspectRatio < 1.55) {
      cropScale = 0.92;
      offsetY = 16.0;
    } else if (aspectRatio < 2.20) {
      cropScale = 1.0;
      offsetY = 22.0;
    } else {
      cropScale = 1.08;
      offsetY = 26.0;
    }

    if (fitProfile == 'chunky_shoes') {
      cropScale -= 0.05;
      offsetY += 2.0;
    }

    return SmartPlacementResult(
      cropScale: cropScale,
      offsetX: 0.0,
      offsetY: offsetY,
      rotation: 0.0,
    );
  }

  SmartPlacementResult _resolveOuterwear({
    required double aspectRatio,
    String? fitProfile,
  }) {
    double cropScale = 1.08;
    double offsetY = 28.0;

    if (aspectRatio < 0.45) {
      cropScale = 1.18;
      offsetY = 44.0;
    } else if (aspectRatio < 0.60) {
      cropScale = 1.14;
      offsetY = 36.0;
    } else if (aspectRatio < 0.85) {
      cropScale = 1.08;
      offsetY = 26.0;
    } else {
      cropScale = 1.00;
      offsetY = 14.0;
    }

    if (fitProfile == 'long_outerwear') {
      cropScale += 0.04;
      offsetY += 10.0;
    }

    return SmartPlacementResult(
      cropScale: cropScale,
      offsetX: 0.0,
      offsetY: offsetY,
      rotation: 0.0,
    );
  }
}
