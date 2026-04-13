import 'package:flutter/material.dart';

import '../../../wardrobe/domain/models/clothing_item.dart';
import '../../domain/models/avatar_slot.dart';
import 'placed_clothing_item.dart';

enum AvatarViewMode { front, quarterLeft, quarterRight }

class AvatarCanvas extends StatelessWidget {
  final List<ClothingItem> items;
  final double height;
  final EdgeInsets padding;
  final String? highlightedSlotId;
  final bool showSlotOverlay;
  final AvatarViewMode viewMode;
  final ValueChanged<Size>? onCanvasSizeChanged;
  final Widget Function(BuildContext context, ClothingItem item, Widget child)?
  itemWrapperBuilder;

  const AvatarCanvas({
    super.key,
    required this.items,
    this.height = 560,
    this.padding = const EdgeInsets.all(16),
    this.highlightedSlotId,
    this.showSlotOverlay = false,
    this.viewMode = AvatarViewMode.front,
    this.onCanvasSizeChanged,
    this.itemWrapperBuilder,
  });

  double _horizontalShiftForViewMode() {
    switch (viewMode) {
      case AvatarViewMode.front:
        return 0.0;
      case AvatarViewMode.quarterLeft:
        return -10.0;
      case AvatarViewMode.quarterRight:
        return 10.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderedItems = [...items]
      ..sort(
        (a, b) => a.effectivePlacement.layerOrder.compareTo(
          b.effectivePlacement.layerOrder,
        ),
      );

    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.surfaceContainerHighest,
            Theme.of(context).colorScheme.surfaceContainer,
          ],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
          final horizontalShift = _horizontalShiftForViewMode();

          if (onCanvasSizeChanged != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              onCanvasSizeChanged!(canvasSize);
            });
          }

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: canvasSize.width * 0.28,
                right: canvasSize.width * 0.28,
                bottom: 12,
                child: IgnorePointer(
                  child: Container(
                    height: 28,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: RadialGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.18),
                          Colors.black.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(horizontalShift, 0),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: Image.asset(
                        'assets/body.png',
                        height: 500,
                        fit: BoxFit.contain,
                      ),
                    ),
                    if (showSlotOverlay && highlightedSlotId != null)
                      _SlotOverlay(
                        slotId: highlightedSlotId!,
                        canvasSize: canvasSize,
                      ),
                    for (final item in orderedItems)
                      PlacedClothingItem(
                        item: item,
                        canvasSize: canvasSize,
                        wrapperBuilder: itemWrapperBuilder == null
                            ? null
                            : (context, child) =>
                                  itemWrapperBuilder!(context, item, child),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SlotOverlay extends StatelessWidget {
  final String slotId;
  final Size canvasSize;

  const _SlotOverlay({required this.slotId, required this.canvasSize});

  @override
  Widget build(BuildContext context) {
    final slot = AvatarSlots.byId(slotId);
    if (slot == null) return const SizedBox.shrink();

    final slotWidth = slot.widthRatio * canvasSize.width;
    final slotHeight = slot.heightRatio * canvasSize.height;
    final slotCenter = Offset(
      slot.centerX * canvasSize.width,
      slot.centerY * canvasSize.height,
    );

    return Positioned(
      left: slotCenter.dx - (slotWidth / 2),
      top: slotCenter.dy - (slotHeight / 2),
      child: IgnorePointer(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: slotWidth,
          height: slotHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 2.5,
            ),
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.10),
          ),
        ),
      ),
    );
  }
}
