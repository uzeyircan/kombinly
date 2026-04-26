import 'package:flutter/material.dart';

import '../../../avatar/domain/models/mannequin_manifest.dart';
import '../../../avatar/domain/services/mannequin_manifest_service.dart';
import '../../../avatar/presentation/widgets/avatar_canvas.dart';
import '../../../avatar/presentation/widgets/garment_3d_overlay.dart';
import '../../../avatar/presentation/widgets/mannequin_3d_viewer.dart';
import '../../../wardrobe/domain/models/clothing_item.dart';

/// Premium 3D Manken Sahnesi.
///
/// Manifest'te `hasRealModel == true` ise [Mannequin3DViewer] (GLB render)
/// kullanır ve üstüne [GarmentScene3DOverlay] katar.
///
/// `hasRealModel == false` ise mevcut [AvatarCanvas] 2D fallback devreye
/// girer — bu sayede eski sistem tamamen korunur.
class ThreeDMannequinStage extends StatefulWidget {
  static const _manifestService = MannequinManifestService();

  final List<ClothingItem> items;
  final double yaw;
  final double zoom;
  final double windStrength;

  const ThreeDMannequinStage({
    super.key,
    required this.items,
    required this.yaw,
    required this.zoom,
    required this.windStrength,
  });

  @override
  State<ThreeDMannequinStage> createState() => _ThreeDMannequinStageState();
}

class _ThreeDMannequinStageState extends State<ThreeDMannequinStage> {
  bool _modelLoaded = false;

  AvatarViewMode _resolveViewMode() {
    if (widget.yaw < -0.2) return AvatarViewMode.quarterLeft;
    if (widget.yaw > 0.2) return AvatarViewMode.quarterRight;
    return AvatarViewMode.front;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MannequinManifest>(
      future: ThreeDMannequinStage._manifestService.loadStandardManifest(),
      builder: (context, snapshot) {
        final manifest = snapshot.data;
        final use3D =
            manifest != null && manifest.hasRealModel;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StageHeader(
              manifest: manifest,
              modelLoaded: _modelLoaded,
              use3D: use3D,
            ),
            const SizedBox(height: 14),
            // ── Sahne ────────────────────────────────────────────────────
            SizedBox(
              height: 580,
              child: use3D
                  ? _Premium3DScene(
                      manifest: manifest,
                      items: widget.items,
                      yaw: widget.yaw,
                      zoom: widget.zoom,
                    )
                  : _Fallback2DScene(
                      items: widget.items,
                      zoom: widget.zoom,
                      viewMode: _resolveViewMode(),
                    ),
            ),
            const SizedBox(height: 14),
            // ── Alt bilgi paneli ─────────────────────────────────────────
            _StageInfoPanel(
              use3D: use3D,
              windStrength: widget.windStrength,
              modelLoaded: _modelLoaded,
            ),
          ],
        );
      },
    );
  }
}

// ── Premium 3D Sahne ────────────────────────────────────────────────────────

class _Premium3DScene extends StatelessWidget {
  final MannequinManifest manifest;
  final List<ClothingItem> items;
  final double yaw;
  final double zoom;

  const _Premium3DScene({
    required this.manifest,
    required this.items,
    required this.yaw,
    required this.zoom,
  });


  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          // 1) GLB manken
          Positioned.fill(
            child: Mannequin3DViewer(
              modelSrc: manifest.modelPath ?? '',
              yaw: yaw,
              pitch: manifest.camera.initialPitch,
              zoom: zoom,
            ),
          ),
          // 2) Kıyafet katmanı (hibrit overlay)
          if (items.isNotEmpty)
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GarmentScene3DOverlay(
                    items: items,
                    yaw: yaw,
                    sceneSize: Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    ),
                  );
                },
              ),
            ),
          // 3) Hafif vignette — sahnede derinlik hissi
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.0,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.22),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 2D Fallback Sahne ───────────────────────────────────────────────────────

class _Fallback2DScene extends StatelessWidget {
  final List<ClothingItem> items;
  final double zoom;
  final AvatarViewMode viewMode;

  const _Fallback2DScene({
    required this.items,
    required this.zoom,
    required this.viewMode,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: zoom,
      child: AvatarCanvas(
        items: items,
        height: 580,
        viewMode: viewMode,
      ),
    );
  }
}

// ── Stage Header ────────────────────────────────────────────────────────────

class _StageHeader extends StatelessWidget {
  final MannequinManifest? manifest;
  final bool modelLoaded;
  final bool use3D;

  const _StageHeader({
    required this.manifest,
    required this.modelLoaded,
    required this.use3D,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String badgeLabel;
    Color badgeColor;

    if (use3D && modelLoaded) {
      badgeLabel = '✦ Premium 3D';
      badgeColor = const Color(0xFF8B7CF8);
    } else if (use3D) {
      badgeLabel = 'GLB yükleniyor…';
      badgeColor = Colors.amber.shade600;
    } else {
      badgeLabel = 'Studio 2D';
      badgeColor = theme.colorScheme.primary;
    }

    return Row(
      children: [
        const Icon(Icons.view_in_ar_outlined, color: Color(0xFF8B7CF8)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            use3D ? 'Premium 3D Stage' : '3D Mannequin Stage',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        _StageBadge(label: badgeLabel, color: badgeColor),
      ],
    );
  }
}

// ── Stage Info Panel ─────────────────────────────────────────────────────────

class _StageInfoPanel extends StatelessWidget {
  final bool use3D;
  final double windStrength;
  final bool modelLoaded;

  const _StageInfoPanel({
    required this.use3D,
    required this.windStrength,
    required this.modelLoaded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final String infoText;
    if (use3D && modelLoaded) {
      infoText =
          'Kıyafetler 3D mankene perspektif, gölge ve kenar yumuşatmayla bindiriliyor. '
          'Wind: ${(windStrength * 100).round()}%';
    } else if (use3D) {
      infoText = 'GLB model yükleniyor, lütfen bekleyin…';
    } else {
      infoText =
          'GLB model bulunamadı — 2D fallback aktif. '
          'assets/mannequin/ klasörüne standard_female_v1.glb ekleyin.';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: theme.colorScheme.surface.withValues(alpha: 0.72),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        infoText,
        style: TextStyle(
          height: 1.4,
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: 13,
        ),
      ),
    );
  }
}

// ── Badge ────────────────────────────────────────────────────────────────────

class _StageBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StageBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.14),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        ),
      ),
    );
  }
}
