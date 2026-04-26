import 'package:flutter/material.dart';

import '../../../wardrobe/domain/models/clothing_item.dart';

/// Hibrit 3D Garment Overlay Engine.
///
/// 3D manken sahnesi üstünde kıyafet görselini "giyilmiş gibi" gösterir.
/// Teknikler:
///  - Perspektif transform (yaw'a bağlı matrix skew)
///  - Blur edge mask (ShaderMask ile kenar yumuşatma)
///  - Ambient shadow (BoxDecoration drop shadow)
///  - Slot-aware positioning (overlayAnchor koordinatlarından)
///  - Layer compositing (zIndex sıralaması)
class GarmentScene3DOverlay extends StatelessWidget {
  final List<ClothingItem> items;

  /// Yatay orbit açısı (-1.0..1.0). 0 = tam ön.
  final double yaw;

  /// Sahne kutu boyutu — [LayoutBuilder] ile dışarıdan verilir.
  final Size sceneSize;

  const GarmentScene3DOverlay({
    super.key,
    required this.items,
    required this.yaw,
    required this.sceneSize,
  });

  @override
  Widget build(BuildContext context) {
    // zIndex'e göre sırala (düşük → alt katman)
    final sorted = [...items]
      ..sort(
        (a, b) =>
            a.effectivePlacement.layerOrder.compareTo(
              b.effectivePlacement.layerOrder,
            ),
      );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final item in sorted)
          _GarmentLayer(item: item, yaw: yaw, sceneSize: sceneSize),
      ],
    );
  }
}

// ── Tek Kıyafet Katmanı ─────────────────────────────────────────────────────

class _GarmentLayer extends StatelessWidget {
  final ClothingItem item;
  final double yaw;
  final Size sceneSize;

  const _GarmentLayer({
    required this.item,
    required this.yaw,
    required this.sceneSize,
  });

  // Kategori bazlı overlay koordinatları (oransal, 0..1)
  _OverlayCoords _coordsForCategory(String category) {
    switch (category.trim().toLowerCase()) {
      case 'top':
        return const _OverlayCoords(
          topRatio: 0.11,
          centerXRatio: 0.50,
          widthRatio: 0.54,
          heightRatio: 0.34,
        );
      case 'bottom':
        return const _OverlayCoords(
          topRatio: 0.44,
          centerXRatio: 0.50,
          widthRatio: 0.44,
          heightRatio: 0.38,
        );
      case 'outerwear':
        return const _OverlayCoords(
          topRatio: 0.09,
          centerXRatio: 0.50,
          widthRatio: 0.60,
          heightRatio: 0.52,
        );
      case 'shoes':
        return const _OverlayCoords(
          topRatio: 0.84,
          centerXRatio: 0.50,
          widthRatio: 0.40,
          heightRatio: 0.14,
        );
      default:
        return const _OverlayCoords(
          topRatio: 0.11,
          centerXRatio: 0.50,
          widthRatio: 0.54,
          heightRatio: 0.34,
        );
    }
  }

  /// yaw değerine göre hafif perspektif matris oluştur.
  /// Sola dönünce kıyafetin sağ kenarı biraz daralır (ve tersi).
  Matrix4 _perspectiveMatrix(double perspectiveWeight) {
    // yaw: -1 = sol, 0 = ön, +1 = sağ
    // skewX: yaw'a bağlı, perspectiveWeight ile ölçeklenir
    final skewAmount = yaw * 0.08 * perspectiveWeight;
    final scaleX =
        1.0 - (yaw.abs() * 0.05 * perspectiveWeight); // hafif daralma

    final m = Matrix4.identity()
      ..setEntry(0, 0, scaleX) // X scale — perspektife bağlı daralma
      ..setEntry(1, 0, skewAmount); // skewY — hafif eğim

    return m;
  }

  double _perspectiveWeightForCategory(String category) {
    switch (category.trim().toLowerCase()) {
      case 'top':
        return 0.85;
      case 'bottom':
        return 0.75;
      case 'outerwear':
        return 0.90;
      case 'shoes':
        return 0.60;
      default:
        return 0.80;
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.renderImageUrl;
    if (imageUrl == null || imageUrl.isEmpty) return const SizedBox.shrink();

    final coords = _coordsForCategory(item.category);
    final pw = _perspectiveWeightForCategory(item.category);

    final overlayWidth = sceneSize.width * coords.widthRatio;
    final overlayHeight = sceneSize.height * coords.heightRatio;
    final left = sceneSize.width * coords.centerXRatio - overlayWidth / 2;
    final top = sceneSize.height * coords.topRatio;

    final aspectRatio =
        (item.aspectRatio != null && item.aspectRatio! > 0)
        ? item.aspectRatio!
        : _defaultAspectRatio(item.category);

    // Görüntünün gerçek boyutunu aspect ratio'yu koruyarak hesapla
    double imgW = overlayWidth;
    double imgH = imgW / aspectRatio;
    if (imgH > overlayHeight) {
      imgH = overlayHeight;
      imgW = imgH * aspectRatio;
    }

    // Scale factor — SmartPlacement'deki gibi biraz büyüt
    imgW *= item.cropScale.clamp(0.8, 1.4);
    imgH *= item.cropScale.clamp(0.8, 1.4);

    // Perspektif matris
    final matrix = _perspectiveMatrix(pw);

    Widget garment = Image.network(
      imageUrl,
      width: imgW,
      height: imgH,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );

    // Kenar yumuşatma — ShaderMask ile radial solma
    garment = ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        return RadialGradient(
          center: Alignment.center,
          radius: 0.72,
          colors: const [Colors.white, Colors.white, Colors.transparent],
          stops: const [0.0, 0.78, 1.0],
        ).createShader(bounds);
      },
      child: garment,
    );

    // Perspektif transform
    garment = Transform(
      alignment: Alignment.center,
      transform: matrix,
      child: garment,
    );

    // Drop shadow
    garment = Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28 + yaw.abs() * 0.08),
            blurRadius: 22,
            offset: Offset(yaw * 6, 10),
            spreadRadius: -4,
          ),
        ],
      ),
      child: garment,
    );

    return Positioned(
      left: left + item.offsetX,
      top: top + item.offsetY,
      child: garment,
    );
  }

  double _defaultAspectRatio(String category) {
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
}

// ── Yardımcı ────────────────────────────────────────────────────────────────

class _OverlayCoords {
  final double topRatio;
  final double centerXRatio;
  final double widthRatio;
  final double heightRatio;

  const _OverlayCoords({
    required this.topRatio,
    required this.centerXRatio,
    required this.widthRatio,
    required this.heightRatio,
  });
}
