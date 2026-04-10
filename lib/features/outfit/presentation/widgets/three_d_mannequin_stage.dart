import 'package:flutter/material.dart';

import '../../../avatar/presentation/widgets/avatar_canvas.dart';
import '../../../wardrobe/domain/models/clothing_item.dart';

class ThreeDMannequinStage extends StatelessWidget {
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

  AvatarViewMode _resolveViewMode() {
    if (yaw < -0.2) return AvatarViewMode.quarterLeft;
    if (yaw > 0.2) return AvatarViewMode.quarterRight;
    return AvatarViewMode.front;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.surfaceContainerHighest,
            theme.colorScheme.surfaceContainer,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.view_in_ar_outlined),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '3D Mannequin Stage',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                ),
                child: Text(
                  'Foundation',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'This stage is ready for a real GLB mannequin renderer. Current preview still uses the studio mannequin so we can keep building camera and motion controls now.',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          Transform.scale(
            scale: zoom,
            child: AvatarCanvas(
              items: items,
              height: 620,
              viewMode: _resolveViewMode(),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: theme.colorScheme.surface.withValues(alpha: 0.72),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Next 3D hookup',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  '1. Add a mannequin GLB asset.\n2. Connect a real 3D viewer.\n3. Map clothing layers to garment meshes.\n4. Use wind strength for edge-only cloth motion later.',
                  style: TextStyle(
                    height: 1.4,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Wind preview value: ${(windStrength * 100).round()}%',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
