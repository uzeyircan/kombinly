import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../avatar/domain/models/avatar_slot.dart';
import '../../../avatar/domain/services/fit_engine.dart';
import '../../../avatar/domain/services/snap_engine.dart';
import '../../../avatar/presentation/widgets/avatar_canvas.dart';
import '../../domain/models/clothing_item.dart';

class AdjustClothingPage extends StatefulWidget {
  final ClothingItem item;

  const AdjustClothingPage({super.key, required this.item});

  @override
  State<AdjustClothingPage> createState() => _AdjustClothingPageState();
}

class _AdjustClothingPageState extends State<AdjustClothingPage> {
  final supabase = Supabase.instance.client;
  final FitEngine _fitEngine = const FitEngine();
  final SnapEngine _snapEngine = const SnapEngine();

  late double scale;
  late double offsetX;
  late double offsetY;
  late double rotation;

  bool isSaving = false;
  bool _isDragging = false;

  Size? _canvasSize;
  String? _activeSnapSlotId;

  @override
  void initState() {
    super.initState();
    scale = widget.item.cropScale;
    offsetX = widget.item.offsetX;
    offsetY = widget.item.offsetY;
    rotation = widget.item.rotation;
  }

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

  double _resolvedAspectRatio() {
    final value = widget.item.aspectRatio;
    if (value != null && value > 0) {
      return value;
    }
    return _fallbackAspectRatioForCategory(widget.item.category);
  }

  AvatarSlot _resolveSlot() {
    final placement = widget.item.effectivePlacement;
    return AvatarSlots.byId(placement.targetSlot) ?? AvatarSlots.upperBody;
  }

  FitResult _resolveFit({
    required Size canvasSize,
    required double localScale,
    required double localOffsetX,
    required double localOffsetY,
  }) {
    final placement = widget.item.effectivePlacement;
    final slot = _resolveSlot();

    return _fitEngine.resolve(
      canvasSize: canvasSize,
      slot: slot,
      placement: placement,
      imageAspectRatio: _resolvedAspectRatio(),
      extraScaleMultiplier: localScale,
      offsetX: localOffsetX,
      offsetY: localOffsetY,
    );
  }

  Offset _currentVisualCenter(Size canvasSize) {
    final fit = _resolveFit(
      canvasSize: canvasSize,
      localScale: scale,
      localOffsetX: offsetX,
      localOffsetY: offsetY,
    );

    return Offset(
      fit.topLeft.dx + (fit.width / 2),
      fit.topLeft.dy + (fit.height / 2),
    );
  }

  Rect _targetSlotRect(Size canvasSize) {
    final slot = _resolveSlot();

    final slotCenter = Offset(
      slot.centerX * canvasSize.width,
      slot.centerY * canvasSize.height,
    );

    final slotWidth = slot.widthRatio * canvasSize.width;
    final slotHeight = slot.heightRatio * canvasSize.height;

    return Rect.fromCenter(
      center: slotCenter,
      width: slotWidth,
      height: slotHeight,
    );
  }

  Offset _clampCenterToSlot({
    required Offset desiredCenter,
    required Rect slotRect,
  }) {
    final clampedDx = desiredCenter.dx.clamp(slotRect.left, slotRect.right);
    final clampedDy = desiredCenter.dy.clamp(slotRect.top, slotRect.bottom);

    return Offset(clampedDx, clampedDy);
  }

  void _updateSnapPreview() {
    final canvasSize = _canvasSize;
    if (canvasSize == null) return;

    final placement = widget.item.effectivePlacement;
    final currentCenter = _currentVisualCenter(canvasSize);

    final snapResult = _snapEngine.findBestSlot(
      dropPoint: currentCenter,
      targetSlotId: placement.targetSlot,
      availableSlots: AvatarSlots.all,
      canvasSize: canvasSize,
      snapThreshold: 90,
    );

    setState(() {
      _activeSnapSlotId = snapResult?.slot.id;
    });
  }

  void _handleDragStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });
    _updateSnapPreview();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final canvasSize = _canvasSize;
    if (canvasSize == null) return;

    final currentCenter = _currentVisualCenter(canvasSize);
    final desiredCenter = currentCenter + details.delta;
    final slotRect = _targetSlotRect(canvasSize);
    final clampedCenter = _clampCenterToSlot(
      desiredCenter: desiredCenter,
      slotRect: slotRect,
    );

    final dx = clampedCenter.dx - currentCenter.dx;
    final dy = clampedCenter.dy - currentCenter.dy;

    setState(() {
      offsetX += dx;
      offsetY += dy;
    });

    _updateSnapPreview();
  }

  void _handleDragEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });

    _updateSnapPreview();
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      setState(() {
        final delta = event.scrollDelta.dy;
        if (delta < 0) {
          scale = (scale + 0.05).clamp(0.5, 2.2);
        } else if (delta > 0) {
          scale = (scale - 0.05).clamp(0.5, 2.2);
        }
      });

      _updateSnapPreview();
    }
  }

  void _rotateLeft() {
    setState(() {
      rotation = (rotation - 0.08).clamp(-1.2, 1.2);
    });
  }

  void _rotateRight() {
    setState(() {
      rotation = (rotation + 0.08).clamp(-1.2, 1.2);
    });
  }

  Future<void> saveAdjustments() async {
    setState(() => isSaving = true);

    try {
      await supabase
          .from('clothes')
          .update({
            'crop_scale': scale,
            'offset_x': offsetX,
            'offset_y': offsetY,
            'rotation': rotation,
          })
          .eq('id', widget.item.id);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save adjustments: $e')));
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  void resetAdjustments() {
    setState(() {
      scale = 1.0;
      offsetX = 0.0;
      offsetY = 0.0;
      rotation = 0.0;
      _activeSnapSlotId = null;
      _isDragging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.item.renderImageUrl;

    final previewItem = widget.item.copyWith(
      imageUrl: widget.item.imageUrl,
      processedImageUrl: widget.item.processedImageUrl,
      cropScale: scale,
      offsetX: offsetX,
      offsetY: offsetY,
      rotation: rotation,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Adjust Clothing'), centerTitle: true),
      body: imageUrl == null || imageUrl.isEmpty
          ? const Center(
              child: Text(
                'This clothing item has no image.',
                style: TextStyle(fontSize: 18),
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.item.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Category: ${widget.item.category}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Drag to move. Scroll to zoom. Use buttons to rotate.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    AvatarCanvas(
                      items: [previewItem],
                      showSlotOverlay: _isDragging || _activeSnapSlotId != null,
                      highlightedSlotId: _activeSnapSlotId,
                      onCanvasSizeChanged: (size) {
                        if (_canvasSize == size || !mounted) return;
                        setState(() {
                          _canvasSize = size;
                        });
                      },
                      itemWrapperBuilder: (context, item, child) {
                        return Listener(
                          onPointerSignal: _handlePointerSignal,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onPanStart: _handleDragStart,
                            onPanUpdate: _handleDragUpdate,
                            onPanEnd: _handleDragEnd,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.35),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: child,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _rotateLeft,
                            icon: const Icon(Icons.rotate_left),
                            label: const Text('Rotate Left'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _rotateRight,
                            icon: const Icon(Icons.rotate_right),
                            label: const Text('Rotate Right'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: resetAdjustments,
                            child: const Text('Reset'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: isSaving ? null : saveAdjustments,
                            child: Text(
                              isSaving ? 'Saving...' : 'Save Adjustments',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
