import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../avatar/domain/services/smart_placement_service.dart';
import '../../domain/services/garment_processor.dart';

class AddClothingPage extends StatefulWidget {
  const AddClothingPage({super.key});

  @override
  State<AddClothingPage> createState() => _AddClothingPageState();
}

class _AddClothingPageState extends State<AddClothingPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final supabase = Supabase.instance.client;
  final imagePicker = ImagePicker();
  final garmentProcessor = const GarmentProcessor();
  final smartPlacementService = const SmartPlacementService();

  String _selectedCategory = 'Top';
  String _selectedColor = 'Black';
  String _selectedSeason = 'All Seasons';
  String _selectedOccasion = 'Casual';

  bool _isLoading = false;
  File? _selectedImageFile;

  final List<String> categories = ['Top', 'Bottom', 'Outerwear', 'Shoes'];
  final List<String> colors = [
    'Black',
    'White',
    'Blue',
    'Red',
    'Beige',
    'Gray',
  ];
  final List<String> seasons = [
    'All Seasons',
    'Summer',
    'Winter',
    'Spring',
    'Autumn',
  ];
  final List<String> occasions = ['Casual', 'Office', 'Date'];

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() {
        _selectedImageFile = File(pickedFile.path);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Image selection failed: $e')));
    }
  }

  Future<String?> _uploadOriginalImage(String userId) async {
    if (_selectedImageFile == null) return null;

    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${_selectedCategory.toLowerCase()}_original.jpg';
    final path = '$userId/original/$fileName';

    await supabase.storage
        .from('clothes-images')
        .upload(
          path,
          _selectedImageFile!,
          fileOptions: const FileOptions(upsert: true),
        );

    return supabase.storage.from('clothes-images').getPublicUrl(path);
  }

  Future<Uint8List> _removeBackground(String imageUrl) async {
    final response = await supabase.functions.invoke(
      'remove-background',
      body: {'imageUrl': imageUrl},
    );

    if (response.data == null) {
      throw Exception('Background removal failed: empty response');
    }

    final data = response.data;

    if (data is! Map<String, dynamic>) {
      throw Exception('Unexpected function response type: ${data.runtimeType}');
    }

    final base64Image = data['imageBase64'] as String?;

    if (base64Image == null || base64Image.isEmpty) {
      throw Exception('Background removal failed: imageBase64 missing');
    }

    return base64Decode(base64Image);
  }

  Future<String> _uploadProcessedImage({
    required String userId,
    required Uint8List pngBytes,
  }) async {
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${_selectedCategory.toLowerCase()}_processed.png';
    final path = '$userId/processed/$fileName';

    await supabase.storage
        .from('clothes-images')
        .uploadBinary(
          path,
          pngBytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/png',
          ),
        );

    return supabase.storage.from('clothes-images').getPublicUrl(path);
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User session not found')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? originalImageUrl;
      String? processedImageUrl;
      if (_selectedImageFile != null) {
        originalImageUrl = await _uploadOriginalImage(user.id);

        if (originalImageUrl != null) {
          final processedBytes = await _removeBackground(originalImageUrl);
          processedImageUrl = await _uploadProcessedImage(
            userId: user.id,
            pngBytes: processedBytes,
          );
        }
      }

      double aspectRatio = 1.0;

      if (processedImageUrl != null && processedImageUrl.isNotEmpty) {
        try {
          aspectRatio = await garmentProcessor.detectAspectRatio(
            processedImageUrl,
          );
        } catch (_) {
          aspectRatio = 1.0;
        }
      }

      final fitProfile = garmentProcessor.resolveFitProfile(
        _selectedCategory,
        aspectRatio,
      );
      final smartPlacement = smartPlacementService.resolve(
        category: _selectedCategory,
        aspectRatio: aspectRatio,
        fitProfile: fitProfile,
      );

      final inserted = await supabase
          .from('clothes')
          .insert({
            'user_id': user.id,
            'title': _titleController.text.trim(),
            'category': _selectedCategory,
            'color': _selectedColor,
            'season': _selectedSeason,
            'occasion': _selectedOccasion,
            'image_url': originalImageUrl,
            'processed_image_url': processedImageUrl,
            'crop_scale': smartPlacement.cropScale,
            'offset_x': smartPlacement.offsetX,
            'offset_y': smartPlacement.offsetY,
            'rotation': smartPlacement.rotation,
            'aspect_ratio': aspectRatio,
            'fit_profile': fitProfile,
            'is_processed': processedImageUrl != null,
            'needs_review': processedImageUrl == null,
            'last_processed_at': processedImageUrl != null
                ? DateTime.now().toIso8601String()
                : null,
          })
          .select()
          .single();

      final insertedItemId = inserted['id'] as String;

      if (!mounted) return;
      Navigator.pop(context, insertedItemId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save item: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildImagePreview() {
    if (_selectedImageFile == null) {
      return InkWell(
        onTap: _pickImage,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate_outlined, size: 42),
                SizedBox(height: 8),
                Text('Select clothing image'),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(
            _selectedImageFile!,
            height: 220,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _pickImage,
          child: const Text('Change Image'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Clothing'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildImagePreview(),
              const SizedBox(height: 20),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Clothing Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a clothing title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: categories
                    .map(
                      (e) => DropdownMenuItem<String>(value: e, child: Text(e)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedCategory = value;
                  });
                },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: _selectedColor,
                decoration: const InputDecoration(
                  labelText: 'Color',
                  border: OutlineInputBorder(),
                ),
                items: colors
                    .map(
                      (e) => DropdownMenuItem<String>(value: e, child: Text(e)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedColor = value;
                  });
                },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: _selectedSeason,
                decoration: const InputDecoration(
                  labelText: 'Season',
                  border: OutlineInputBorder(),
                ),
                items: seasons
                    .map(
                      (e) => DropdownMenuItem<String>(value: e, child: Text(e)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedSeason = value;
                  });
                },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: _selectedOccasion,
                decoration: const InputDecoration(
                  labelText: 'Occasion',
                  border: OutlineInputBorder(),
                ),
                items: occasions
                    .map(
                      (e) => DropdownMenuItem<String>(value: e, child: Text(e)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedOccasion = value;
                  });
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isLoading ? null : _saveItem,
                  child: Text(_isLoading ? 'Saving...' : 'Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
