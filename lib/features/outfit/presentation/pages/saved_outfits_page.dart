import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../avatar/presentation/widgets/avatar_canvas.dart';
import '../../../wardrobe/domain/models/clothing_item.dart';
import '../../domain/models/saved_outfit.dart';

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
        _clothesById = {};
        _isLoading = false;
      });
      return;
    }

    try {
      final outfitsData = await supabase
          .from('outfits')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final clothesData = await supabase
          .from('clothes')
          .select()
          .eq('user_id', user.id);

      final outfits = (outfitsData as List)
          .map((e) => SavedOutfit.fromMap(e as Map<String, dynamic>))
          .toList();

      final clothes = (clothesData as List)
          .map((e) => ClothingItem.fromMap(e as Map<String, dynamic>))
          .toList();

      final clothesById = <String, ClothingItem>{
        for (final item in clothes) item.id: item,
      };

      if (!mounted) return;
      setState(() {
        _outfits = outfits;
        _clothesById = clothesById;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _outfits = [];
        _clothesById = {};
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load saved outfits: $e')),
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          : _outfits.isEmpty
          ? RefreshIndicator(
              onRefresh: _loadSavedOutfits,
              child: ListView(
                children: const [
                  SizedBox(height: 140),
                  Center(
                    child: Text(
                      'No saved outfits yet.',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Generate and save a few outfits first.',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadSavedOutfits,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _outfits.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final outfit = _outfits[index];

                  final top = _findClothing(outfit.topId);
                  final bottom = _findClothing(outfit.bottomId);
                  final shoes = _findClothing(outfit.shoesId);

                  final previewItems = <ClothingItem>[?top, ?bottom, ?shoes];

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
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AvatarCanvas(
            items: previewItems,
            height: 420,
            padding: const EdgeInsets.all(12),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
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
