import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/clothing_item.dart';
import '../widgets/clothing_card.dart';
import 'add_clothing_page.dart';
import 'adjust_clothing_page.dart';

class WardrobePage extends StatefulWidget {
  const WardrobePage({super.key});

  @override
  State<WardrobePage> createState() => _WardrobePageState();
}

class _WardrobePageState extends State<WardrobePage> {
  final supabase = Supabase.instance.client;

  List<ClothingItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      setState(() {
        _items = [];
        _isLoading = false;
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

      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _items = [];
        _isLoading = false;
      });

      if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Wardrobe'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? const Center(
              child: Text(
                'No clothes added yet.\nTap + to add your first item.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                itemCount: _items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemBuilder: (context, index) {
                  final item = _items[index];

                  return GestureDetector(
                    onTap: () async {
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdjustClothingPage(item: item),
                        ),
                      );

                      if (result == true) {
                        await _loadItems();
                      }
                    },
                    onLongPress: () => _deleteItem(item.id),
                    child: ClothingCard(item: item),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _goToAddPage,
        child: const Icon(Icons.add),
      ),
    );
  }
}
