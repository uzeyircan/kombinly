import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../avatar/presentation/widgets/avatar_canvas.dart';
import '../../../wardrobe/domain/models/clothing_item.dart';
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
          .order('created_at', ascending: false);

      final items = (data as List)
          .map((item) => ClothingItem.fromMap(item as Map<String, dynamic>))
          .toList();

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load studio items: $e')));
    }
  }

  List<ClothingItem> get _previewItems => [
    ?_selectedTop,
    ?_selectedBottom,
    ?_selectedShoes,
  ];

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Studio outfit saved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save studio outfit: $e')));
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

  Future<void> _pickItem({
    required String title,
    required List<ClothingItem> items,
    required ClothingItem? selectedItem,
    required ValueChanged<ClothingItem?> onSelected,
  }) async {
    final picked = await showModalBottomSheet<ClothingItem?>(
      context: context,
      isScrollControlled: true,
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
                  onTap: () => Navigator.pop(context, null),
                ),
                const Divider(height: 1),
                Expanded(
                  child: items.isEmpty
                      ? const Center(
                          child: Text(
                            'No items in this category yet.',
                            style: TextStyle(fontSize: 16),
                          ),
                        )
                      : ListView.separated(
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
                                          errorBuilder: (_, _, _) =>
                                              const Icon(
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
              ],
            ),
          ),
        );
      },
    );

    onSelected(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Build a look manually and preview it on the mannequin.',
                    style: TextStyle(fontSize: 16),
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
                    onTap: () => _pickItem(
                      title: 'Choose Top',
                      items: _tops,
                      selectedItem: _selectedTop,
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
                    onTap: () => _pickItem(
                      title: 'Choose Bottom',
                      items: _bottoms,
                      selectedItem: _selectedBottom,
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
                    onTap: () => _pickItem(
                      title: 'Choose Shoes',
                      items: _shoes,
                      selectedItem: _selectedShoes,
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
                          onPressed: _clearSelections,
                          child: const Text('Clear'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _isSaving ? null : _saveOutfit,
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
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
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

  const _StudioSlotTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: Row(
          children: [
            Icon(icon, size: 28),
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
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
