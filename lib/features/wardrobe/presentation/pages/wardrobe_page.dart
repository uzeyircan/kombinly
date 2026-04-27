import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/clothing_item.dart';
import '../../domain/services/garment_processor.dart';
import '../../domain/services/reprocess_clothing_service.dart';
import '../../../avatar/domain/services/smart_placement_service.dart';
import 'add_clothing_page.dart';
import 'adjust_clothing_page.dart';

class WardrobePage extends StatefulWidget {
  const WardrobePage({super.key});

  @override
  State<WardrobePage> createState() => _WardrobePageState();
}

class _WardrobePageState extends State<WardrobePage> {
  final supabase = Supabase.instance.client;
  final _garmentProcessor = const GarmentProcessor();
  final _smartPlacementService = const SmartPlacementService();

  String? _reprocessingItemId;

  List<ClothingItem> _items = [];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _retryProcessing(ClothingItem item) async {
    final originalImageUrl = item.imageUrl;
    if (originalImageUrl == null || originalImageUrl.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Original image not found')));
      return;
    }

    setState(() {
      _reprocessingItemId = item.id;
    });

    try {
      final service = ReprocessClothingService(
        supabase: supabase,
        garmentProcessor: _garmentProcessor,
        smartPlacementService: _smartPlacementService,
      );

      await service.reprocess(
        itemId: item.id,
        category: item.category,
        originalImageUrl: originalImageUrl,
      );

      await _loadItems();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Item processed again')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Retry failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _reprocessingItemId = null;
        });
      }
    }
  }

  Future<void> _loadItems() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      setState(() {
        _items = [];
        _isLoading = false;
        _loadError = null;
      });
      return;
    }

    try {
      final data = await supabase
          .from('clothes')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 12));

      final items = <ClothingItem>[];
      var skippedItems = 0;

      for (final item in data as List) {
        try {
          items.add(ClothingItem.fromMap(item as Map<String, dynamic>));
        } catch (_) {
          skippedItems++;
        }
      }

      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
        _loadError = null;
      });

      if (skippedItems > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$skippedItems wardrobe item could not be loaded because its data is incomplete.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _items = [];
        _isLoading = false;
        _loadError = 'Failed to load wardrobe. Pull to refresh or try again.';
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load wardrobe: $e')));
    }
  }

  Future<ClothingItem?> _getItemById(String id) async {
    try {
      final data = await supabase
          .from('clothes')
          .select()
          .eq('id', id)
          .single();

      return ClothingItem.fromMap(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> _goToAddPage() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const AddClothingPage()),
    );

    if (result != null) {
      await _loadItems();

      final insertedItem = await _getItemById(result);
      if (insertedItem != null && mounted) {
        final adjusted = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => AdjustClothingPage(item: insertedItem),
          ),
        );

        if (adjusted == true) {
          await _loadItems();
        }
      }
    }
  }

  Future<void> _openAdjust(ClothingItem item) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AdjustClothingPage(item: item)),
    );

    if (result == true) {
      await _loadItems();
    }
  }

  Future<void> _deleteItem(String id) async {
    try {
      await supabase.from('clothes').delete().eq('id', id);
      await _loadItems();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Item deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete item: $e')));
    }
  }

  Future<void> _confirmDelete(ClothingItem item) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete item'),
          content: Text('Delete "${item.title}" from your wardrobe?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      await _deleteItem(item.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F1),
      appBar: AppBar(
        title: const Text('My Wardrobe'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadItems,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? RefreshIndicator(
              onRefresh: _loadItems,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 96),
                  _WardrobeNoticeCard(
                    icon: Icons.cloud_off_outlined,
                    title: 'Wardrobe could not load.',
                    subtitle: _loadError!,
                  ),
                ],
              ),
            )
          : _items.isEmpty
          ? RefreshIndicator(
              onRefresh: _loadItems,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 96),
                  _WardrobeNoticeCard(
                    icon: Icons.checkroom_outlined,
                    title: 'No clothes added yet.',
                    subtitle: 'Tap + to add your first item.',
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadItems,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 96),
                child: GridView.builder(
                  itemCount: _items.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.78,
                  ),
                  itemBuilder: (context, index) {
                    final item = _items[index];

                    return _WardrobeItemCard(
                      item: item,
                      onTap: () => _openAdjust(item),
                      onDelete: () => _confirmDelete(item),
                      onRetry: item.isProcessed
                          ? null
                          : () => _retryProcessing(item),
                      isRetrying: _reprocessingItemId == item.id,
                    );
                  },
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _goToAddPage,
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _WardrobeNoticeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _WardrobeNoticeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(icon, size: 34, color: colorScheme.primary),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 15,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _WardrobeItemCard extends StatelessWidget {
  final ClothingItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onRetry;
  final bool isRetrying;

  const _WardrobeItemCard({
    required this.item,
    required this.onTap,
    required this.onDelete,
    required this.onRetry,
    required this.isRetrying,
  });

  String _formatFitProfile(String? value) {
    if (value == null || value.trim().isEmpty) return 'unknown';
    return value.replaceAll('_', ' ');
  }

  String _statusLabel(ClothingItem item) {
    return item.isProcessed ? 'Processed' : 'Pending';
  }

  String? _styleMetaText(ClothingItem item) {
    final parts = <String>[];

    final genderTarget = item.genderTarget?.trim();
    if (genderTarget != null && genderTarget.isNotEmpty) {
      parts.add(genderTarget);
    }

    if (item.styleTags.isNotEmpty) {
      parts.add(item.styleTags.take(2).join(', '));
    }

    return parts.isEmpty ? null : parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.renderImageUrl;
    final statusText = _statusLabel(item);
    final styleMetaText = _styleMetaText(item);
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(22),
                        ),
                        child: Container(
                          color: const Color(0xFFF7EAE0),
                          padding: const EdgeInsets.all(12),
                          child: imageUrl == null || imageUrl.isEmpty
                              ? const Center(
                                  child: Icon(
                                    Icons.image_not_supported_outlined,
                                    size: 36,
                                  ),
                                )
                              : Image.network(
                                  imageUrl,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) {
                                    return const Center(
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        size: 36,
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(22),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.06),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.05),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: _MiniBadge(
                        text: statusText,
                        isPositive: item.isProcessed,
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: _MiniBadge(
                        text: _formatFitProfile(item.fitProfile),
                        isPositive: false,
                      ),
                    ),
                    if (item.needsReview)
                      Positioned(
                        bottom: 10,
                        left: 10,
                        child: _MiniBadge(
                          text: 'Needs review',
                          isPositive: false,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _MetaLine(
                      icon: Icons.category_outlined,
                      text: '${item.category} • ${item.color}',
                    ),
                    const SizedBox(height: 3),
                    _MetaLine(
                      icon: Icons.event_available_outlined,
                      text: '${item.season} • ${item.occasion}',
                    ),
                    if (styleMetaText != null) ...[
                      const SizedBox(height: 3),
                      _MetaLine(
                        icon: Icons.style_outlined,
                        text: styleMetaText,
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (onRetry != null)
                          Expanded(
                            child: SizedBox(
                              height: 36,
                              child: OutlinedButton(
                                onPressed: isRetrying ? null : onRetry,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: colorScheme.primary,
                                  side: BorderSide(
                                    color: colorScheme.primary.withValues(
                                      alpha: 0.35,
                                    ),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  isRetrying ? 'Retrying...' : 'Retry',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        if (onRetry != null) const SizedBox(width: 8),
                        IconButton.filledTonal(
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Delete',
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                            backgroundColor: colorScheme.errorContainer
                                .withValues(alpha: 0.55),
                            foregroundColor: colorScheme.onErrorContainer,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;

    return Row(
      children: [
        Icon(icon, size: 13, color: color.withValues(alpha: 0.82)),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.4, color: color, height: 1.15),
          ),
        ),
      ],
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String text;
  final bool isPositive;

  const _MiniBadge({required this.text, required this.isPositive});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final backgroundColor = isPositive
        ? colorScheme.primary.withValues(alpha: 0.14)
        : colorScheme.surface.withValues(alpha: 0.88);

    final foregroundColor = isPositive
        ? colorScheme.primary
        : colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foregroundColor,
        ),
      ),
    );
  }
}
