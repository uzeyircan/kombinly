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
    return Scaffold(
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
                children: [
                  const SizedBox(height: 140),
                  const Center(
                    child: Text(
                      'Wardrobe could not load.',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      _loadError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
            )
          : _items.isEmpty
          ? RefreshIndicator(
              onRefresh: _loadItems,
              child: ListView(
                children: const [
                  SizedBox(height: 140),
                  Center(
                    child: Text(
                      'No clothes added yet.',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Tap + to add your first item.',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadItems,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GridView.builder(
                  itemCount: _items.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
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
        child: const Icon(Icons.add),
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

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.renderImageUrl;
    final statusText = _statusLabel(item);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(22),
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
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          padding: const EdgeInsets.all(10),
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
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${item.category} • ${item.color}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.season} • ${item.occasion}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (onRetry != null)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isRetrying ? null : onRetry,
                              child: Text(isRetrying ? 'Retrying...' : 'Retry'),
                            ),
                          ),
                        if (onRetry != null) const SizedBox(width: 8),
                        IconButton.filledTonal(
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Delete',
                          visualDensity: VisualDensity.compact,
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
