import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../avatar/presentation/widgets/avatar_canvas.dart';
import '../../../wardrobe/domain/models/clothing_item.dart';
import '../../../wardrobe/presentation/pages/adjust_clothing_page.dart';
import '../../domain/models/outfit_recommendation.dart';
import '../../domain/models/outfit_request.dart';
import '../../domain/services/wardrobe_recommendation_engine.dart';

class TodayOutfitPage extends StatefulWidget {
  final String? initialGender;

  const TodayOutfitPage({super.key, this.initialGender});

  @override
  State<TodayOutfitPage> createState() => _TodayOutfitPageState();
}

class _TodayOutfitPageState extends State<TodayOutfitPage> {
  final supabase = Supabase.instance.client;
  final _engine = const WardrobeRecommendationEngine();

  final List<String> scenarios = const [
    'İş görüşmesi',
    'İlk buluşma',
    'Günlük kullanım',
    'Okul',
    'Ofis',
    'Düğün',
    'Arkadaş buluşması',
    'Özel davet',
    'Spor / yürüyüş',
    'Seyahat',
    'Akşam yemeği',
  ];

  final List<String> styles = const [
    'Casual',
    'Smart casual',
    'Klasik',
    'Minimal',
    'Streetwear',
    'Sportif',
    'Elegant',
    'Basic',
    'Premium görünüm',
  ];

  final List<String> environments = const [
    'Kapalı alan',
    'Açık hava',
    'Sıcak hava',
    'Soğuk hava',
    'Yağmurlu hava',
    'Yaz / gündüz',
    'Kış / gece',
    'Resmi ortam',
    'Rahat ortam',
  ];

  final List<String> genders = const ['Erkek', 'Kadın', 'Unisex'];

  String selectedScenario = 'İş görüşmesi';
  String selectedStyle = 'Smart casual';
  String selectedEnvironment = 'Kapalı alan';
  String selectedGender = 'Erkek';

  List<ClothingItem> wardrobeItems = [];
  OutfitRecommendation? recommendation;

  bool isLoading = true;
  bool isSaving = false;
  final Set<String> lockedItemIds = {};

  @override
  void initState() {
    super.initState();
    selectedGender = _resolveInitialGender(widget.initialGender);
    _loadWardrobeAndGenerate();
  }

  String _resolveInitialGender(String? value) {
    final normalized = value?.trim().toLowerCase();
    switch (normalized) {
      case 'male':
      case 'men':
      case 'man':
      case 'erkek':
        return 'Erkek';
      case 'female':
      case 'women':
      case 'woman':
      case 'kadın':
      case 'kadin':
        return 'Kadın';
      case 'unisex':
        return 'Unisex';
      default:
        return 'Unisex';
    }
  }

  OutfitRequest get _request {
    return OutfitRequest(
      scenario: selectedScenario,
      style: selectedStyle,
      environment: selectedEnvironment,
      gender: selectedGender,
    );
  }

  Future<void> _loadWardrobeAndGenerate() async {
    setState(() => isLoading = true);

    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        wardrobeItems = [];
        recommendation = null;
        lockedItemIds.clear();
        isLoading = false;
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
      for (final item in data as List) {
        try {
          items.add(ClothingItem.fromMap(item as Map<String, dynamic>));
        } catch (_) {
          // Keep recommendations available even if an older row is partial.
        }
      }

      final nextRecommendation = _engine.recommend(
        request: _request,
        wardrobeItems: items,
        lockedItemIds: lockedItemIds,
      );

      if (!mounted) return;
      setState(() {
        wardrobeItems = items;
        recommendation = nextRecommendation;
        lockedItemIds.removeWhere(
          (id) =>
              !nextRecommendation.selectedItems.any((item) => item.id == id),
        );
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        wardrobeItems = [];
        recommendation = null;
        isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to generate outfit: $e')));
    }
  }

  void _regenerateFromLoadedWardrobe() {
    setState(() {
      recommendation = _engine.recommend(
        request: _request,
        wardrobeItems: wardrobeItems,
        lockedItemIds: lockedItemIds,
      );
      lockedItemIds.removeWhere(
        (id) => !recommendation!.selectedItems.any((item) => item.id == id),
      );
    });
  }

  Future<void> _saveOutfit() async {
    final user = supabase.auth.currentUser;
    final current = recommendation;

    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User session not found')));
      return;
    }

    if (current == null || !current.hasAnyItem) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No outfit to save')));
      return;
    }

    setState(() => isSaving = true);

    try {
      await _trySaveRecommendation(userId: user.id, recommendation: current);
      await _saveLegacyOutfit(userId: user.id, recommendation: current);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Outfit saved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save outfit: $e')));
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  Future<void> _trySaveRecommendation({
    required String userId,
    required OutfitRecommendation recommendation,
  }) async {
    try {
      await supabase.from('outfit_recommendations').insert({
        'user_id': userId,
        'source_type': 'wardrobe',
        'scenario': recommendation.request.scenario,
        'style': recommendation.request.style,
        'environment': recommendation.request.environment,
        'gender': recommendation.request.gender,
        'selected_items': recommendation.selectedItemsMap(),
        'ai_reason': recommendation.reason,
        'score': recommendation.score,
        'missing_items': recommendation.missingItems,
      });
    } on PostgrestException catch (_) {
      // The V1 recommendation table may not be migrated yet. Keep the user
      // flow working by saving to the existing outfits table below.
    }
  }

  Future<void> _saveLegacyOutfit({
    required String userId,
    required OutfitRecommendation recommendation,
  }) async {
    await supabase.from('outfits').insert({
      'user_id': userId,
      'top_id': recommendation.top?.id,
      'bottom_id': recommendation.bottom?.id,
      'shoes_id': recommendation.shoes?.id,
      'season': recommendation.request.environment,
      'occasion': recommendation.request.scenario,
    });
  }

  void _toggleLock(ClothingItem? item) {
    if (item == null) return;

    setState(() {
      if (lockedItemIds.contains(item.id)) {
        lockedItemIds.remove(item.id);
      } else {
        lockedItemIds.add(item.id);
      }
    });
  }

  bool _sameCategory(String actual, String expected) {
    final normalized = actual.trim().toLowerCase();
    final target = expected.trim().toLowerCase();
    if (normalized == target) return true;
    if (target == 'accessory') {
      return normalized == 'accessories' || normalized == 'aksesuar';
    }
    return false;
  }

  List<ClothingItem> _itemsForSlot(String category) {
    return wardrobeItems
        .where((item) => _sameCategory(item.category, category))
        .where((item) => item.renderImageUrl != null)
        .where((item) => item.renderImageUrl!.trim().isNotEmpty)
        .toList();
  }

  Future<void> _chooseSlotItem({
    required String title,
    required String category,
    required ClothingItem? selectedItem,
    required ValueChanged<ClothingItem> onSelected,
  }) async {
    final items = _itemsForSlot(category);

    final picked = await showModalBottomSheet<ClothingItem>(
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
                const Divider(height: 1),
                Expanded(
                  child: items.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Bu kategori için gardırobunda uygun parça yok.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 16),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final isSelected = item.id == selectedItem?.id;

                            return ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 52,
                                  height: 52,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  child: Image.network(
                                    item.renderImageUrl!,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, _, _) =>
                                        const Icon(Icons.broken_image_outlined),
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

    if (picked == null) return;
    onSelected(picked);
  }

  void _replaceSlot({required String category, required ClothingItem item}) {
    final current = recommendation;
    if (current == null) return;

    final nextTop = category == 'Top' ? item : current.top;
    final nextBottom = category == 'Bottom' ? item : current.bottom;
    final nextShoes = category == 'Shoes' ? item : current.shoes;
    final nextOuterwear = category == 'Outerwear' ? item : current.outerwear;
    final nextAccessory = category == 'Accessory' ? item : current.accessory;
    final missingItems = <String>[
      if (nextTop == null) 'üst parça',
      if (nextBottom == null) 'alt parça',
      if (nextShoes == null) 'ayakkabı',
      if (current.missingItems.contains('dış giyim') && nextOuterwear == null)
        'dış giyim',
    ];
    final selectedCount = <ClothingItem>[
      ?nextTop,
      ?nextBottom,
      ?nextShoes,
      ?nextOuterwear,
      ?nextAccessory,
    ].length;
    final score = (50 + (selectedCount * 10) - (missingItems.length * 12))
        .clamp(0, 100)
        .toInt();

    setState(() {
      recommendation = OutfitRecommendation(
        request: current.request,
        top: nextTop,
        bottom: nextBottom,
        shoes: nextShoes,
        outerwear: nextOuterwear,
        accessory: nextAccessory,
        score: score,
        missingItems: missingItems,
        reason:
            '${current.request.scenario} için kombin manuel seçiminle güncellendi. Seçilen parçalar gardırobundaki mevcut metadata ve slot uyumuyla gösteriliyor.',
      );
      lockedItemIds.add(item.id);
    });
  }

  Future<void> _openAdjustItem(ClothingItem? item) async {
    if (item == null) return;

    final adjusted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AdjustClothingPage(item: item)),
    );

    if (adjusted != true) return;

    try {
      final data = await supabase
          .from('clothes')
          .select()
          .eq('id', item.id)
          .single()
          .timeout(const Duration(seconds: 12));

      final refreshedItem = ClothingItem.fromMap(data);
      _replaceAdjustedItem(refreshedItem);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to refresh item: $e')));
    }
  }

  void _replaceAdjustedItem(ClothingItem item) {
    final current = recommendation;
    if (current == null) return;

    ClothingItem? replaceIfSame(ClothingItem? existing) {
      if (existing?.id == item.id) return item;
      return existing;
    }

    setState(() {
      wardrobeItems = wardrobeItems
          .map((existing) => existing.id == item.id ? item : existing)
          .toList();
      recommendation = current.copyWith(
        top: replaceIfSame(current.top),
        bottom: replaceIfSame(current.bottom),
        shoes: replaceIfSame(current.shoes),
        outerwear: replaceIfSame(current.outerwear),
        accessory: replaceIfSame(current.accessory),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = recommendation;
    final previewItems = current?.selectedItems ?? const <ClothingItem>[];
    final hasAccessoryOptions = _itemsForSlot('Accessory').isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F1),
      appBar: AppBar(
        title: const Text('Gardıroptan Kombin'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: isLoading ? null : _loadWardrobeAndGenerate,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh wardrobe',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadWardrobeAndGenerate,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  const _DecisionHeader(),
                  const SizedBox(height: 18),
                  _SelectionPanel(
                    selectedScenario: selectedScenario,
                    selectedStyle: selectedStyle,
                    selectedEnvironment: selectedEnvironment,
                    selectedGender: selectedGender,
                    scenarios: scenarios,
                    styles: styles,
                    environments: environments,
                    genders: genders,
                    onScenarioChanged: (value) {
                      setState(() => selectedScenario = value);
                      _regenerateFromLoadedWardrobe();
                    },
                    onStyleChanged: (value) {
                      setState(() => selectedStyle = value);
                      _regenerateFromLoadedWardrobe();
                    },
                    onEnvironmentChanged: (value) {
                      setState(() => selectedEnvironment = value);
                      _regenerateFromLoadedWardrobe();
                    },
                    onGenderChanged: (value) {
                      setState(() => selectedGender = value);
                      _regenerateFromLoadedWardrobe();
                    },
                  ),
                  const SizedBox(height: 22),
                  if (current == null || !current.hasAnyItem)
                    const _EmptyRecommendation()
                  else ...[
                    _RecommendationSummary(recommendation: current),
                    const SizedBox(height: 18),
                    AvatarCanvas(items: previewItems, height: 560),
                    const SizedBox(height: 22),
                    _OutfitTile(
                      title: 'Üst',
                      item: current.top,
                      isLocked:
                          current.top != null &&
                          lockedItemIds.contains(current.top!.id),
                      onChange: () => _chooseSlotItem(
                        title: 'Üst seç',
                        category: 'Top',
                        selectedItem: current.top,
                        onSelected: (item) =>
                            _replaceSlot(category: 'Top', item: item),
                      ),
                      onAdjust: () => _openAdjustItem(current.top),
                      onToggleLock: () => _toggleLock(current.top),
                    ),
                    const SizedBox(height: 12),
                    _OutfitTile(
                      title: 'Alt',
                      item: current.bottom,
                      isLocked:
                          current.bottom != null &&
                          lockedItemIds.contains(current.bottom!.id),
                      onChange: () => _chooseSlotItem(
                        title: 'Alt seç',
                        category: 'Bottom',
                        selectedItem: current.bottom,
                        onSelected: (item) =>
                            _replaceSlot(category: 'Bottom', item: item),
                      ),
                      onAdjust: () => _openAdjustItem(current.bottom),
                      onToggleLock: () => _toggleLock(current.bottom),
                    ),
                    const SizedBox(height: 12),
                    _OutfitTile(
                      title: 'Ayakkabı',
                      item: current.shoes,
                      isLocked:
                          current.shoes != null &&
                          lockedItemIds.contains(current.shoes!.id),
                      onChange: () => _chooseSlotItem(
                        title: 'Ayakkabı seç',
                        category: 'Shoes',
                        selectedItem: current.shoes,
                        onSelected: (item) =>
                            _replaceSlot(category: 'Shoes', item: item),
                      ),
                      onAdjust: () => _openAdjustItem(current.shoes),
                      onToggleLock: () => _toggleLock(current.shoes),
                    ),
                    const SizedBox(height: 12),
                    if (current.outerwear != null ||
                        current.missingItems.contains('dış giyim'))
                      _OutfitTile(
                        title: 'Dış giyim',
                        item: current.outerwear,
                        isLocked:
                            current.outerwear != null &&
                            lockedItemIds.contains(current.outerwear!.id),
                        onChange: () => _chooseSlotItem(
                          title: 'Dış giyim seç',
                          category: 'Outerwear',
                          selectedItem: current.outerwear,
                          onSelected: (item) =>
                              _replaceSlot(category: 'Outerwear', item: item),
                        ),
                        onAdjust: () => _openAdjustItem(current.outerwear),
                        onToggleLock: () => _toggleLock(current.outerwear),
                      ),
                    if (current.accessory != null || hasAccessoryOptions) ...[
                      const SizedBox(height: 12),
                      _OutfitTile(
                        title: 'Aksesuar',
                        item: current.accessory,
                        isLocked:
                            current.accessory != null &&
                            lockedItemIds.contains(current.accessory!.id),
                        onChange: () => _chooseSlotItem(
                          title: 'Aksesuar seç',
                          category: 'Accessory',
                          selectedItem: current.accessory,
                          onSelected: (item) =>
                              _replaceSlot(category: 'Accessory', item: item),
                        ),
                        onAdjust: () => _openAdjustItem(current.accessory),
                        onToggleLock: () => _toggleLock(current.accessory),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isSaving ? null : _saveOutfit,
                            icon: const Icon(Icons.bookmark_outline),
                            label: Text(isSaving ? 'Saving...' : 'Save'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _regenerateFromLoadedWardrobe,
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text('Generate'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _DecisionHeader extends StatelessWidget {
  const _DecisionHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.psychology_alt_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ne giyeceğim?',
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 4),
                Text(
                  'Senaryoya göre gardırobundan en uygun parçaları seç.',
                  style: TextStyle(height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionPanel extends StatelessWidget {
  final String selectedScenario;
  final String selectedStyle;
  final String selectedEnvironment;
  final String selectedGender;
  final List<String> scenarios;
  final List<String> styles;
  final List<String> environments;
  final List<String> genders;
  final ValueChanged<String> onScenarioChanged;
  final ValueChanged<String> onStyleChanged;
  final ValueChanged<String> onEnvironmentChanged;
  final ValueChanged<String> onGenderChanged;

  const _SelectionPanel({
    required this.selectedScenario,
    required this.selectedStyle,
    required this.selectedEnvironment,
    required this.selectedGender,
    required this.scenarios,
    required this.styles,
    required this.environments,
    required this.genders,
    required this.onScenarioChanged,
    required this.onStyleChanged,
    required this.onEnvironmentChanged,
    required this.onGenderChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          _PickerField(
            label: 'Senaryo',
            value: selectedScenario,
            values: scenarios,
            onChanged: onScenarioChanged,
          ),
          const SizedBox(height: 14),
          _PickerField(
            label: 'Stil',
            value: selectedStyle,
            values: styles,
            onChanged: onStyleChanged,
          ),
          const SizedBox(height: 14),
          _PickerField(
            label: 'Ortam',
            value: selectedEnvironment,
            values: environments,
            onChanged: onEnvironmentChanged,
          ),
          const SizedBox(height: 14),
          _PickerField(
            label: 'Manken',
            value: selectedGender,
            values: genders,
            onChanged: onGenderChanged,
          ),
        ],
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  const _PickerField({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: values
          .map(
            (item) => DropdownMenuItem<String>(value: item, child: Text(item)),
          )
          .toList(),
      onChanged: (next) {
        if (next == null) return;
        onChanged(next);
      },
    );
  }
}

class _RecommendationSummary extends StatelessWidget {
  final OutfitRecommendation recommendation;

  const _RecommendationSummary({required this.recommendation});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Uygunluk: ${recommendation.score}/100',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Icon(Icons.check_circle_outline, color: colorScheme.primary),
            ],
          ),
          const SizedBox(height: 10),
          Text(recommendation.reason, style: const TextStyle(height: 1.35)),
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
        ],
      ),
    );
  }
}

class _EmptyRecommendation extends StatelessWidget {
  const _EmptyRecommendation();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: const Column(
        children: [
          Icon(Icons.checkroom_outlined, size: 44),
          SizedBox(height: 14),
          Text(
            'Uygun kombin bulunamadı',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 8),
          Text(
            'Gardırobuna üst, alt ve ayakkabı ekledikten sonra tekrar dene.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _OutfitTile extends StatelessWidget {
  final String title;
  final ClothingItem? item;
  final bool isLocked;
  final VoidCallback onChange;
  final VoidCallback onAdjust;
  final VoidCallback onToggleLock;

  const _OutfitTile({
    required this.title,
    required this.item,
    required this.isLocked,
    required this.onChange,
    required this.onAdjust,
    required this.onToggleLock,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.86),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: item == null
          ? Row(
              children: [
                Expanded(
                  child: Text(
                    '$title: bulunamadı',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton(onPressed: onChange, child: const Text('Seç')),
              ],
            )
          : Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 54,
                    height: 54,
                    color: colorScheme.surfaceContainerHighest,
                    child: Image.network(
                      item!.renderImageUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item!.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${item!.color} • ${item!.season} • ${item!.occasion}',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onChange,
                  icon: const Icon(Icons.swap_horiz),
                  tooltip: 'Change item',
                ),
                IconButton(
                  onPressed: onAdjust,
                  icon: const Icon(Icons.tune),
                  tooltip: 'Adjust placement',
                ),
                IconButton(
                  onPressed: onToggleLock,
                  icon: Icon(isLocked ? Icons.lock : Icons.lock_open),
                  tooltip: isLocked ? 'Unlock item' : 'Lock item',
                ),
              ],
            ),
    );
  }
}
