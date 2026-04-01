import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../avatar/presentation/widgets/avatar_canvas.dart';
import '../../../wardrobe/domain/models/clothing_item.dart';

class TodayOutfitPage extends StatefulWidget {
  const TodayOutfitPage({super.key});

  @override
  State<TodayOutfitPage> createState() => _TodayOutfitPageState();
}

class _TodayOutfitPageState extends State<TodayOutfitPage> {
  final supabase = Supabase.instance.client;
  final random = Random();

  List<ClothingItem> tops = [];
  List<ClothingItem> bottoms = [];
  List<ClothingItem> shoesList = [];

  ClothingItem? top;
  ClothingItem? bottom;
  ClothingItem? shoes;

  bool isLoading = true;
  bool isTopLocked = false;
  bool isBottomLocked = false;
  bool isShoesLocked = false;

  String selectedSeason = 'All Seasons';
  String selectedOccasion = 'Casual';

  final List<String> seasons = [
    'All Seasons',
    'Summer',
    'Winter',
    'Spring',
    'Autumn',
  ];

  final List<String> occasions = ['Casual', 'Office', 'Date'];

  @override
  void initState() {
    super.initState();
    _loadWardrobeAndGenerate();
  }

  bool _matchesSeason(String itemSeason) {
    if (selectedSeason == 'All Seasons') return true;
    return itemSeason == 'All Seasons' || itemSeason == selectedSeason;
  }

  bool _matchesOccasion(String itemOccasion) {
    return itemOccasion == selectedOccasion;
  }

  int _colorScore(String colorA, String colorB) {
    final a = colorA.toLowerCase();
    final b = colorB.toLowerCase();

    if (a == b) return 2;

    const neutralColors = ['black', 'white', 'gray', 'beige'];
    if (neutralColors.contains(a) || neutralColors.contains(b)) return 3;

    const goodPairs = {
      'blue-white',
      'white-blue',
      'blue-black',
      'black-blue',
      'beige-black',
      'black-beige',
      'red-black',
      'black-red',
      'red-white',
      'white-red',
    };

    if (goodPairs.contains('$a-$b')) return 4;

    return 1;
  }

  ClothingItem? _pickRandomDifferent(
    List<ClothingItem> items,
    ClothingItem? currentItem,
  ) {
    if (items.isEmpty) return null;
    if (items.length == 1) return items.first;

    final available = items
        .where((item) => item.id != currentItem?.id)
        .toList();

    if (available.isEmpty) return items.first;

    return available[random.nextInt(available.length)];
  }

  bool _containsItem(List<ClothingItem> items, ClothingItem? item) {
    if (item == null) return false;
    return items.any((e) => e.id == item.id);
  }

  Future<void> _loadWardrobeAndGenerate() async {
    setState(() => isLoading = true);

    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        tops = [];
        bottoms = [];
        shoesList = [];
        top = null;
        bottom = null;
        shoes = null;
        isTopLocked = false;
        isBottomLocked = false;
        isShoesLocked = false;
        isLoading = false;
      });
      return;
    }

    try {
      final data = await supabase
          .from('clothes')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final items = (data as List)
          .map((item) => ClothingItem.fromMap(item as Map<String, dynamic>))
          .toList();

      final filteredTops = items
          .where(
            (e) =>
                e.category == 'Top' &&
                _matchesSeason(e.season) &&
                _matchesOccasion(e.occasion),
          )
          .toList();

      final filteredBottoms = items
          .where(
            (e) =>
                e.category == 'Bottom' &&
                _matchesSeason(e.season) &&
                _matchesOccasion(e.occasion),
          )
          .toList();

      final filteredShoes = items
          .where(
            (e) =>
                e.category == 'Shoes' &&
                _matchesSeason(e.season) &&
                _matchesOccasion(e.occasion),
          )
          .toList();

      final topCanStayLocked = isTopLocked && _containsItem(filteredTops, top);
      final bottomCanStayLocked =
          isBottomLocked && _containsItem(filteredBottoms, bottom);
      final shoesCanStayLocked =
          isShoesLocked && _containsItem(filteredShoes, shoes);

      final ClothingItem? generatedTop = topCanStayLocked
          ? top
          : _pickRandomDifferent(filteredTops, top);

      ClothingItem? generatedBottom;
      if (bottomCanStayLocked) {
        generatedBottom = bottom;
      } else if (generatedTop != null && filteredBottoms.isNotEmpty) {
        final topColor = generatedTop.color;
        final sortedBottoms = [...filteredBottoms];
        sortedBottoms.sort(
          (a, b) => _colorScore(
            b.color,
            topColor,
          ).compareTo(_colorScore(a.color, topColor)),
        );
        generatedBottom = sortedBottoms.first;
      }

      ClothingItem? generatedShoes;
      if (shoesCanStayLocked) {
        generatedShoes = shoes;
      } else if (generatedBottom != null && filteredShoes.isNotEmpty) {
        final bottomColor = generatedBottom.color;
        final sortedShoes = [...filteredShoes];
        sortedShoes.sort(
          (a, b) => _colorScore(
            b.color,
            bottomColor,
          ).compareTo(_colorScore(a.color, bottomColor)),
        );
        generatedShoes = sortedShoes.first;
      }

      setState(() {
        tops = filteredTops;
        bottoms = filteredBottoms;
        shoesList = filteredShoes;
        top = generatedTop;
        bottom = generatedBottom;
        shoes = generatedShoes;
        isTopLocked = topCanStayLocked;
        isBottomLocked = bottomCanStayLocked;
        isShoesLocked = shoesCanStayLocked;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        tops = [];
        bottoms = [];
        shoesList = [];
        top = null;
        bottom = null;
        shoes = null;
        isLoading = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to generate outfit: $e')));
    }
  }

  Future<void> _saveOutfit() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User session not found')));
      return;
    }

    if (top == null && bottom == null && shoes == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No outfit to save')));
      return;
    }

    try {
      await supabase.from('outfits').insert({
        'user_id': user.id,
        'top_id': top?.id,
        'bottom_id': bottom?.id,
        'shoes_id': shoes?.id,
        'season': selectedSeason,
        'occasion': selectedOccasion,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Outfit saved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save outfit: $e')));
    }
  }

  void _resetLocks() {
    isTopLocked = false;
    isBottomLocked = false;
    isShoesLocked = false;
  }

  @override
  Widget build(BuildContext context) {
    final hasEnoughItems = top != null || bottom != null || shoes != null;
    final previewItems = <ClothingItem>[?top, ?bottom, ?shoes];

    return Scaffold(
      appBar: AppBar(title: const Text("Today's Outfit"), centerTitle: true),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Build your outfit',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      initialValue: selectedSeason,
                      decoration: const InputDecoration(
                        labelText: 'Season',
                        border: OutlineInputBorder(),
                      ),
                      items: seasons
                          .map(
                            (e) => DropdownMenuItem<String>(
                              value: e,
                              child: Text(e),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          selectedSeason = value;
                          _resetLocks();
                        });
                        _loadWardrobeAndGenerate();
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedOccasion,
                      decoration: const InputDecoration(
                        labelText: 'Occasion',
                        border: OutlineInputBorder(),
                      ),
                      items: occasions
                          .map(
                            (e) => DropdownMenuItem<String>(
                              value: e,
                              child: Text(e),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          selectedOccasion = value;
                          _resetLocks();
                        });
                        _loadWardrobeAndGenerate();
                      },
                    ),
                    const SizedBox(height: 24),
                    if (!hasEnoughItems)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(
                          child: Text(
                            'No suitable outfit found.\nTry another season or occasion, or add more clothes.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Your suggested outfit',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          AvatarCanvas(items: previewItems),
                          const SizedBox(height: 24),
                          _OutfitTile(
                            title: 'Top',
                            item: top,
                            isLocked: isTopLocked,
                            onToggleLock: () {
                              setState(() {
                                isTopLocked = !isTopLocked;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          _OutfitTile(
                            title: 'Bottom',
                            item: bottom,
                            isLocked: isBottomLocked,
                            onToggleLock: () {
                              setState(() {
                                isBottomLocked = !isBottomLocked;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          _OutfitTile(
                            title: 'Shoes',
                            item: shoes,
                            isLocked: isShoesLocked,
                            onToggleLock: () {
                              setState(() {
                                isShoesLocked = !isShoesLocked;
                              });
                            },
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _saveOutfit,
                                  child: const Text('Save Outfit'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton(
                                  onPressed: _loadWardrobeAndGenerate,
                                  child: const Text('Generate Again'),
                                ),
                              ),
                            ],
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

class _OutfitTile extends StatelessWidget {
  final String title;
  final ClothingItem? item;
  final bool isLocked;
  final VoidCallback onToggleLock;

  const _OutfitTile({
    required this.title,
    required this.item,
    required this.isLocked,
    required this.onToggleLock,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: item == null
          ? Text('$title: Not available', style: const TextStyle(fontSize: 18))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onToggleLock,
                      icon: Icon(isLocked ? Icons.lock : Icons.lock_open),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Title: ${item!.title}'),
                Text('Category: ${item!.category}'),
                Text('Color: ${item!.color}'),
                Text('Season: ${item!.season}'),
                Text('Occasion: ${item!.occasion}'),
              ],
            ),
    );
  }
}
