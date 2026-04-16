import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../avatar/presentation/widgets/avatar_canvas.dart';
import '../../../wardrobe/domain/models/clothing_item.dart';
import '../../../wardrobe/presentation/pages/add_clothing_page.dart';
import 'saved_outfits_page.dart';
import '../widgets/three_d_mannequin_stage.dart';

enum TryOnRenderMode { studio2d, mannequin3d }

class TryOnStudioPage extends StatefulWidget {
  const TryOnStudioPage({super.key});

  @override
  State<TryOnStudioPage> createState() => _TryOnStudioPageState();
}

class _TryOnStudioPageState extends State<TryOnStudioPage> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isSaving = false;

  List<ClothingItem> _tops = [];
  List<ClothingItem> _bottoms = [];
  List<ClothingItem> _shoes = [];

  ClothingItem? _selectedTop;
  ClothingItem? _selectedBottom;
  ClothingItem? _selectedShoes;

  AvatarViewMode _viewMode = AvatarViewMode.front;
  TryOnRenderMode _renderMode = TryOnRenderMode.studio2d;
  double _orbitYaw = 0.0;
  double _stageZoom = 1.0;
  double _windStrength = 0.0;

  @override
  void initState() {
    super.initState();
    _loadWardrobe();
  }

  Future<void> _loadWardrobe() async {
    setState(() => _isLoading = true);

    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _tops = [];
        _bottoms = [];
        _shoes = [];
        _isLoading = false;
      });
      return;
    }

    try {
      final data = await _supabase
          .from('clothes')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 12));

      final items = <ClothingItem>[];
      for (final item in data as List) {
        try {
          items.add(ClothingItem.fromMap(item as Map<String, dynamic>));
        } catch (_) {
          // Keep the studio usable even if an older wardrobe row is incomplete.
        }
      }

      if (!mounted) return;
      setState(() {
        _tops = items.where((item) => item.category == 'Top').toList();
        _bottoms = items.where((item) => item.category == 'Bottom').toList();
        _shoes = items.where((item) => item.category == 'Shoes').toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load studio items: $e')),
      );
    }
  }

  List<ClothingItem> get _previewItems => [
    ?_selectedTop,
    ?_selectedBottom,
    ?_selectedShoes,
  ];

  bool get _hasSelections => _previewItems.isNotEmpty;

  String? _commonValue(Iterable<String> values) {
    final distinct = values.where((value) => value.trim().isNotEmpty).toSet();
    if (distinct.length == 1) {
      return distinct.first;
    }
    return null;
  }

  Future<void> _saveOutfit() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User session not found')));
      return;
    }

    if (_previewItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pick at least one item')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final season = _commonValue(_previewItems.map((item) => item.season));
      final occasion = _commonValue(_previewItems.map((item) => item.occasion));

      await _supabase.from('outfits').insert({
        'user_id': user.id,
        'top_id': _selectedTop?.id,
        'bottom_id': _selectedBottom?.id,
        'shoes_id': _selectedShoes?.id,
        'season': season,
        'occasion': occasion,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Studio outfit saved'),
          action: SnackBarAction(label: 'View', onPressed: _openSavedOutfits),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save studio outfit: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _clearSelections() {
    setState(() {
      _selectedTop = null;
      _selectedBottom = null;
      _selectedShoes = null;
    });
  }

  Future<void> _openSavedOutfits() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SavedOutfitsPage()),
    );
  }

  Future<void> _goToAddCategory(String category) async {
    final insertedId = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => AddClothingPage(initialCategory: category),
      ),
    );

    if (insertedId != null) {
      await _loadWardrobe();
    }
  }

  Future<void> _pickItem({
    required String title,
    required List<ClothingItem> items,
    required ClothingItem? selectedItem,
    required String addCategory,
    required ValueChanged<ClothingItem?> onSelected,
  }) async {
    var shouldClearSelection = false;
    final picked = await showModalBottomSheet<ClothingItem?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.clear)),
                  title: const Text('None'),
                  subtitle: const Text('Remove this layer from the studio'),
                  onTap: () {
                    shouldClearSelection = true;
                    Navigator.pop(context);
                  },
                ),
                const Divider(height: 1),
                Expanded(
                  child: items.isEmpty
                      ? _EmptyCategoryPrompt(
                          title: 'No ${addCategory.toLowerCase()} items yet',
                          subtitle: 'Add one to use it in your studio looks.',
                          onAdd: () {
                            Navigator.pop(context);
                            _goToAddCategory(addCategory);
                          },
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 12),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final isSelected = item.id == selectedItem?.id;
                            final imageUrl = item.renderImageUrl;

                            return ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 52,
                                  height: 52,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  child: imageUrl == null || imageUrl.isEmpty
                                      ? const Icon(
                                          Icons.image_not_supported_outlined,
                                        )
                                      : Image.network(
                                          imageUrl,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, _, _) => const Icon(
                                            Icons.broken_image_outlined,
                                          ),
                                        ),
                                ),
                              ),
                              title: Text(item.title),
                              subtitle: Text(
                                '${item.color} • ${item.season} • ${item.occasion}',
                              ),
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle)
                                  : null,
                              onTap: () => Navigator.pop(context, item),
                            );
                          },
                        ),
                ),
                if (items.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _goToAddCategory(addCategory);
                      },
                      icon: const Icon(Icons.add),
                      label: Text('Add $addCategory'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (picked == null && !shouldClearSelection) return;

    onSelected(picked);
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _previewItems.length;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F1),
      appBar: AppBar(
        title: const Text('Try On Studio'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadWardrobe,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh wardrobe',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _StudioHeroCard(),
                  const SizedBox(height: 16),
                  _ActiveLookBar(
                    selectedCount: selectedCount,
                    top: _selectedTop,
                    bottom: _selectedBottom,
                    shoes: _selectedShoes,
                    onClear: _hasSelections ? _clearSelections : null,
                    onSaved: _openSavedOutfits,
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: SegmentedButton<TryOnRenderMode>(
                      segments: const [
                        ButtonSegment(
                          value: TryOnRenderMode.studio2d,
                          label: Text('Studio'),
                          icon: Icon(Icons.layers_outlined),
                        ),
                        ButtonSegment(
                          value: TryOnRenderMode.mannequin3d,
                          label: Text('3D Build'),
                          icon: Icon(Icons.view_in_ar_outlined),
                        ),
                      ],
                      selected: {_renderMode},
                      onSelectionChanged: (selection) {
                        setState(() {
                          _renderMode = selection.first;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_renderMode == TryOnRenderMode.studio2d) ...[
                    Center(
                      child: SegmentedButton<AvatarViewMode>(
                        segments: const [
                          ButtonSegment(
                            value: AvatarViewMode.front,
                            label: Text('Front'),
                            icon: Icon(Icons.person_outline),
                          ),
                          ButtonSegment(
                            value: AvatarViewMode.quarterLeft,
                            label: Text('Left 3/4'),
                            icon: Icon(Icons.turn_left),
                          ),
                          ButtonSegment(
                            value: AvatarViewMode.quarterRight,
                            label: Text('Right 3/4'),
                            icon: Icon(Icons.turn_right),
                          ),
                        ],
                        selected: {_viewMode},
                        onSelectionChanged: (selection) {
                          setState(() {
                            _viewMode = selection.first;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    AvatarCanvas(
                      items: _previewItems,
                      height: 620,
                      viewMode: _viewMode,
                    ),
                  ] else ...[
                    _StageSlider(
                      label: 'Orbit',
                      value: _orbitYaw,
                      min: -1.0,
                      max: 1.0,
                      onChanged: (value) {
                        setState(() => _orbitYaw = value);
                      },
                    ),
                    const SizedBox(height: 10),
                    _StageSlider(
                      label: 'Zoom',
                      value: _stageZoom,
                      min: 0.85,
                      max: 1.2,
                      onChanged: (value) {
                        setState(() => _stageZoom = value);
                      },
                    ),
                    const SizedBox(height: 10),
                    _StageSlider(
                      label: 'Wind',
                      value: _windStrength,
                      min: 0.0,
                      max: 1.0,
                      onChanged: (value) {
                        setState(() => _windStrength = value);
                      },
                    ),
                    const SizedBox(height: 20),
                    ThreeDMannequinStage(
                      items: _previewItems,
                      yaw: _orbitYaw,
                      zoom: _stageZoom,
                      windStrength: _windStrength,
                    ),
                  ],
                  const SizedBox(height: 20),
                  _StudioSlotTile(
                    title: 'Top',
                    subtitle: _selectedTop?.title ?? 'Pick a top',
                    icon: Icons.checkroom_outlined,
                    isSelected: _selectedTop != null,
                    onTap: () => _pickItem(
                      title: 'Choose Top',
                      items: _tops,
                      selectedItem: _selectedTop,
                      addCategory: 'Top',
                      onSelected: (item) {
                        setState(() => _selectedTop = item);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _StudioSlotTile(
                    title: 'Bottom',
                    subtitle: _selectedBottom?.title ?? 'Pick a bottom',
                    icon: Icons.accessibility_new_outlined,
                    isSelected: _selectedBottom != null,
                    onTap: () => _pickItem(
                      title: 'Choose Bottom',
                      items: _bottoms,
                      selectedItem: _selectedBottom,
                      addCategory: 'Bottom',
                      onSelected: (item) {
                        setState(() => _selectedBottom = item);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _StudioSlotTile(
                    title: 'Shoes',
                    subtitle: _selectedShoes?.title ?? 'Pick shoes',
                    icon: Icons.hiking_outlined,
                    isSelected: _selectedShoes != null,
                    onTap: () => _pickItem(
                      title: 'Choose Shoes',
                      items: _shoes,
                      selectedItem: _selectedShoes,
                      addCategory: 'Shoes',
                      onSelected: (item) {
                        setState(() => _selectedShoes = item);
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _hasSelections ? _clearSelections : null,
                          child: const Text('Clear'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _isSaving || !_hasSelections
                              ? null
                              : _saveOutfit,
                          child: Text(
                            _isSaving ? 'Saving...' : 'Save Studio Outfit',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

class _EmptyCategoryPrompt extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onAdd;

  const _EmptyCategoryPrompt({
    required this.title,
    required this.subtitle,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_photo_alternate_outlined,
                size: 38,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add item'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveLookBar extends StatelessWidget {
  final int selectedCount;
  final ClothingItem? top;
  final ClothingItem? bottom;
  final ClothingItem? shoes;
  final VoidCallback? onClear;
  final VoidCallback onSaved;

  const _ActiveLookBar({
    required this.selectedCount,
    required this.top,
    required this.bottom,
    required this.shoes,
    required this.onClear,
    required this.onSaved,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.style_outlined, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  selectedCount == 0
                      ? 'Active look is empty'
                      : '$selectedCount piece active look',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(onPressed: onSaved, child: const Text('Saved')),
              TextButton(onPressed: onClear, child: const Text('Clear')),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _LookChip(label: 'Top', value: top?.title),
              _LookChip(label: 'Bottom', value: bottom?.title),
              _LookChip(label: 'Shoes', value: shoes?.title),
            ],
          ),
        ],
      ),
    );
  }
}

class _LookChip extends StatelessWidget {
  final String label;
  final String? value;

  const _LookChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasValue = value != null && value!.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: hasValue
            ? colorScheme.primary.withValues(alpha: 0.10)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: hasValue
              ? colorScheme.primary.withValues(alpha: 0.25)
              : colorScheme.outlineVariant,
        ),
      ),
      child: Text(
        '$label: ${hasValue ? value! : 'None'}',
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: hasValue ? colorScheme.primary : colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _StageSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _StageSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.82),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioSlotTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isSelected;

  const _StudioSlotTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Colors.white.withValues(alpha: 0.86),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.50),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.12),
              ),
              child: Icon(
                icon,
                size: 26,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle),
                ],
              ),
            ),
            Icon(isSelected ? Icons.check_circle : Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _StudioHeroCard extends StatelessWidget {
  const _StudioHeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF26343A), Color(0xFF3F6C7B), Color(0xFFC2A46D)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: Colors.white.withValues(alpha: 0.16),
            ),
            child: const Text(
              'Manual studio',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Build looks layer by layer',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
              height: 1.04,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Pick a top, bottom, and shoes from your wardrobe. Preview the outfit before saving it.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.84),
              fontSize: 16,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
