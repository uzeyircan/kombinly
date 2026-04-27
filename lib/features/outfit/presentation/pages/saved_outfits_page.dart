import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../avatar/presentation/widgets/avatar_canvas.dart';
import '../../../wardrobe/domain/models/clothing_item.dart';
import '../../domain/models/saved_outfit.dart';
import '../../domain/models/saved_outfit_recommendation.dart';

class SavedOutfitsPage extends StatefulWidget {
  const SavedOutfitsPage({super.key});

  @override
  State<SavedOutfitsPage> createState() => _SavedOutfitsPageState();
}

class _SavedOutfitsPageState extends State<SavedOutfitsPage> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isDeleting = false;

  List<SavedOutfit> _outfits = [];
  List<SavedOutfitRecommendation> _recommendations = [];
  Map<String, ClothingItem> _clothesById = {};

  @override
  void initState() {
    super.initState();
    _loadSavedOutfits();
  }

  Future<void> _loadSavedOutfits() async {
    setState(() {
      _isLoading = true;
    });

    final user = supabase.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _outfits = [];
        _recommendations = [];
        _clothesById = {};
        _isLoading = false;
      });
      return;
    }

    try {
      final recommendations = await _loadRecommendations(user.id);

      final outfitsData = await supabase
          .from('outfits')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 12));

      final clothesData = await supabase
          .from('clothes')
          .select()
          .eq('user_id', user.id)
          .timeout(const Duration(seconds: 12));

      final outfits = (outfitsData as List)
          .map((e) => SavedOutfit.fromMap(e as Map<String, dynamic>))
          .toList();

      final clothes = <ClothingItem>[];
      for (final item in clothesData as List) {
        try {
          clothes.add(ClothingItem.fromMap(item as Map<String, dynamic>));
        } catch (_) {
          // Saved outfits can still render even if an old clothing row is partial.
        }
      }

      final clothesById = <String, ClothingItem>{
        for (final item in clothes) item.id: item,
      };

      if (!mounted) return;
      setState(() {
        _outfits = outfits;
        _recommendations = recommendations;
        _clothesById = clothesById;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _outfits = [];
        _recommendations = [];
        _clothesById = {};
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load saved outfits: $e')),
      );
    }
  }

  Future<List<SavedOutfitRecommendation>> _loadRecommendations(
    String userId,
  ) async {
    try {
      final data = await supabase
          .from('outfit_recommendations')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 12));

      return (data as List)
          .map(
            (item) =>
                SavedOutfitRecommendation.fromMap(item as Map<String, dynamic>),
          )
          .toList();
    } on PostgrestException catch (_) {
      return const [];
    }
  }

  ClothingItem? _findClothing(String? id) {
    if (id == null || id.isEmpty) return null;
    return _clothesById[id];
  }

  Future<void> _deleteOutfit(String outfitId) async {
    setState(() {
      _isDeleting = true;
    });

    try {
      await supabase.from('outfits').delete().eq('id', outfitId);

      if (!mounted) return;
      setState(() {
        _outfits.removeWhere((e) => e.id == outfitId);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Outfit deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete outfit: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  Future<void> _deleteRecommendation(String recommendationId) async {
    setState(() {
      _isDeleting = true;
    });

    try {
      await supabase
          .from('outfit_recommendations')
          .delete()
          .eq('id', recommendationId);

      if (!mounted) return;
      setState(() {
        _recommendations.removeWhere((e) => e.id == recommendationId);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Recommendation deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete recommendation: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day.$month.$year';
  }

  String _buildMetaLine(SavedOutfit outfit) {
    final parts = <String>[];

    if (outfit.season != null && outfit.season!.trim().isNotEmpty) {
      parts.add(outfit.season!);
    }

    if (outfit.occasion != null && outfit.occasion!.trim().isNotEmpty) {
      parts.add(outfit.occasion!);
    }

    return parts.isEmpty ? 'No details' : parts.join(' • ');
  }

  String _buildRecommendationMetaLine(SavedOutfitRecommendation item) {
    final parts = <String>[item.scenario];

    if (item.style != null && item.style!.trim().isNotEmpty) {
      parts.add(item.style!);
    }

    if (item.environment != null && item.environment!.trim().isNotEmpty) {
      parts.add(item.environment!);
    }

    if (item.score != null) {
      parts.add('${item.score!.round()}/100');
    }

    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F1),
      appBar: AppBar(
        title: const Text('Saved Outfits'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadSavedOutfits,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _recommendations.isEmpty && _outfits.isEmpty
          ? RefreshIndicator(
              onRefresh: _loadSavedOutfits,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 60),
                  _SavedOutfitsEmptyState(),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadSavedOutfits,
              child: _recommendations.isNotEmpty
                  ? ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
                      itemCount: _recommendations.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final item = _recommendations[index];

                        final top = _findClothing(item.topId);
                        final bottom = _findClothing(item.bottomId);
                        final shoes = _findClothing(item.shoesId);
                        final outerwear = _findClothing(item.outerwearId);
                        final accessory = _findClothing(item.accessoryId);

                        final previewItems = <ClothingItem>[
                          ?top,
                          ?bottom,
                          ?shoes,
                          ?outerwear,
                          ?accessory,
                        ];

                        return _SavedRecommendationCard(
                          recommendation: item,
                          previewItems: previewItems,
                          top: top,
                          bottom: bottom,
                          shoes: shoes,
                          outerwear: outerwear,
                          accessory: accessory,
                          isDeleting: _isDeleting,
                          onDelete: () => _deleteRecommendation(item.id),
                          formattedDate: _formatDate(item.createdAt),
                          metaLine: _buildRecommendationMetaLine(item),
                        );
                      },
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
                      itemCount: _outfits.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final outfit = _outfits[index];

                        final top = _findClothing(outfit.topId);
                        final bottom = _findClothing(outfit.bottomId);
                        final shoes = _findClothing(outfit.shoesId);

                        final previewItems = <ClothingItem>[
                          ?top,
                          ?bottom,
                          ?shoes,
                        ];

                        return _SavedOutfitCard(
                          outfit: outfit,
                          previewItems: previewItems,
                          top: top,
                          bottom: bottom,
                          shoes: shoes,
                          isDeleting: _isDeleting,
                          onDelete: () => _deleteOutfit(outfit.id),
                          formattedDate: _formatDate(outfit.createdAt),
                          metaLine: _buildMetaLine(outfit),
                        );
                      },
                    ),
            ),
    );
  }
}

class _SavedOutfitsEmptyState extends StatelessWidget {
  const _SavedOutfitsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: Colors.white.withValues(alpha: 0.78),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Icon(
              Icons.bookmark_outline,
              size: 38,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'No saved outfits yet',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'Save looks from Today’s Outfit or Try On Studio and they will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedRecommendationCard extends StatelessWidget {
  final SavedOutfitRecommendation recommendation;
  final List<ClothingItem> previewItems;
  final ClothingItem? top;
  final ClothingItem? bottom;
  final ClothingItem? shoes;
  final ClothingItem? outerwear;
  final ClothingItem? accessory;
  final bool isDeleting;
  final VoidCallback onDelete;
  final String formattedDate;
  final String metaLine;

  const _SavedRecommendationCard({
    required this.recommendation,
    required this.previewItems,
    required this.top,
    required this.bottom,
    required this.shoes,
    required this.outerwear,
    required this.accessory,
    required this.isDeleting,
    required this.onDelete,
    required this.formattedDate,
    required this.metaLine,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AvatarCanvas(
            items: previewItems,
            height: 390,
            padding: const EdgeInsets.all(12),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        recommendation.scenario,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (recommendation.score != null)
                      _ScorePill(score: recommendation.score!.round()),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '$metaLine • $formattedDate',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                if (recommendation.aiReason != null &&
                    recommendation.aiReason!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    recommendation.aiReason!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(height: 1.35),
                  ),
                ],
                if (recommendation.missingItems.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: recommendation.missingItems
                        .map((item) => Chip(label: Text('Eksik: $item')))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 14),
                _InfoRow(label: 'Top', value: top?.title ?? 'Not included'),
                const SizedBox(height: 8),
                _InfoRow(
                  label: 'Bottom',
                  value: bottom?.title ?? 'Not included',
                ),
                const SizedBox(height: 8),
                _InfoRow(label: 'Shoes', value: shoes?.title ?? 'Not included'),
                if (outerwear != null) ...[
                  const SizedBox(height: 8),
                  _InfoRow(label: 'Outer', value: outerwear!.title),
                ],
                if (accessory != null) ...[
                  const SizedBox(height: 8),
                  _InfoRow(label: 'Accessory', value: accessory!.title),
                ],
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    onPressed: isDeleting ? null : onDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
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

class _ScorePill extends StatelessWidget {
  final int score;

  const _ScorePill({required this.score});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$score/100',
        style: TextStyle(
          color: colorScheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SavedOutfitCard extends StatelessWidget {
  final SavedOutfit outfit;
  final List<ClothingItem> previewItems;
  final ClothingItem? top;
  final ClothingItem? bottom;
  final ClothingItem? shoes;
  final bool isDeleting;
  final VoidCallback onDelete;
  final String formattedDate;
  final String metaLine;

  const _SavedOutfitCard({
    required this.outfit,
    required this.previewItems,
    required this.top,
    required this.bottom,
    required this.shoes,
    required this.isDeleting,
    required this.onDelete,
    required this.formattedDate,
    required this.metaLine,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AvatarCanvas(
            items: previewItems,
            height: 390,
            padding: const EdgeInsets.all(12),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saved Outfit',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  '$metaLine • $formattedDate',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                _InfoRow(label: 'Top', value: top?.title ?? 'Not included'),
                const SizedBox(height: 8),
                _InfoRow(
                  label: 'Bottom',
                  value: bottom?.title ?? 'Not included',
                ),
                const SizedBox(height: 8),
                _InfoRow(label: 'Shoes', value: shoes?.title ?? 'Not included'),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    onPressed: isDeleting ? null : onDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }
}
