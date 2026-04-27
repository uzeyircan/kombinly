import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../avatar/domain/services/smart_placement_service.dart';
import '../../domain/services/garment_processor.dart';

class AddClothingPage extends StatefulWidget {
  final String? initialCategory;

  const AddClothingPage({super.key, this.initialCategory});

  @override
  State<AddClothingPage> createState() => _AddClothingPageState();
}

class _AddClothingPageState extends State<AddClothingPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _styleTagsController = TextEditingController();
  final _notesController = TextEditingController();
  final supabase = Supabase.instance.client;
  final imagePicker = ImagePicker();
  final garmentProcessor = const GarmentProcessor();
  final smartPlacementService = const SmartPlacementService();

  late String _selectedCategory;
  String _selectedColor = 'Black';
  String _selectedSeason = 'All Seasons';
  String _selectedOccasion = 'Casual';
  String _selectedGenderTarget = 'Unisex';

  bool _isLoading = false;
  File? _selectedImageFile;

  final List<String> categories = [
    'Top',
    'Bottom',
    'Outerwear',
    'Shoes',
    'Accessory',
  ];
  final List<String> colors = [
    'Black',
    'White',
    'Blue',
    'Red',
    'Beige',
    'Gray',
    'Green',
    'Brown',
    'Navy',
  ];
  final List<String> seasons = [
    'All Seasons',
    'Summer',
    'Winter',
    'Spring',
    'Autumn',
  ];
  final List<String> occasions = [
    'Casual',
    'Office',
    'Date',
    'Formal',
    'Sport',
    'School',
    'Travel',
    'Special Event',
  ];
  final List<String> genderTargets = ['Unisex', 'Men', 'Women'];

  @override
  void initState() {
    super.initState();
    _selectedCategory = categories.contains(widget.initialCategory)
        ? widget.initialCategory!
        : 'Top';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _styleTagsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  List<String> _parseStyleTags() {
    return _styleTagsController.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await imagePicker.pickImage(
        source: source,
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

  Future<void> _showImageSourcePicker() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );

    if (source != null) {
      await _pickImage(source);
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

  int _layerOrderForCategory(String category) {
    switch (category.trim().toLowerCase()) {
      case 'shoes':
        return 10;
      case 'bottom':
        return 15;
      case 'top':
        return 20;
      case 'outerwear':
        return 25;
      case 'accessory':
        return 30;
      default:
        return 20;
    }
  }

  String _targetSlotForCategory(String category) {
    switch (category.trim().toLowerCase()) {
      case 'top':
        return 'upper_body';
      case 'bottom':
        return 'lower_body';
      case 'outerwear':
        return 'outerwear';
      case 'shoes':
        return 'feet';
      case 'accessory':
        return 'accessories';
      default:
        return 'upper_body';
    }
  }

  Future<Map<String, dynamic>> _insertClothing({
    required Map<String, dynamic> enrichedPayload,
    required Map<String, dynamic> fallbackPayload,
  }) async {
    try {
      return await supabase
          .from('clothes')
          .insert(enrichedPayload)
          .select()
          .single();
    } on PostgrestException catch (_) {
      return await supabase
          .from('clothes')
          .insert(fallbackPayload)
          .select()
          .single();
    }
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

      final basePayload = {
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
        'motion_type': 'none',
        'motion_intensity': 0.0,
        'motion_speed': 0.0,
        'is_live_supported': false,
        'mannequin_gender': null,
        'garment_template': null,
      };

      final enrichedPayload = {
        ...basePayload,
        'gender_target': _selectedGenderTarget,
        'style_tags': _parseStyleTags(),
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        'layer_order': _layerOrderForCategory(_selectedCategory),
        'target_slot': _targetSlotForCategory(_selectedCategory),
      };

      final inserted = await _insertClothing(
        enrichedPayload: enrichedPayload,
        fallbackPayload: basePayload,
      );

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
        onTap: _showImageSourcePicker,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          height: 190,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate_outlined, size: 44),
                SizedBox(height: 10),
                Text(
                  'Select clothing image',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                Text('A clean product photo works best'),
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
          borderRadius: BorderRadius.circular(28),
          child: Image.file(
            _selectedImageFile!,
            height: 220,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _showImageSourcePicker,
          child: const Text('Change Image'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F1),
      appBar: AppBar(title: const Text('Add Clothing'), centerTitle: true),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            _buildImagePreview(),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.86),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                children: [
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
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: categories
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
                        _selectedCategory = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedColor,
                    decoration: const InputDecoration(
                      labelText: 'Color',
                      border: OutlineInputBorder(),
                    ),
                    items: colors
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
                        _selectedColor = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedSeason,
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
                        _selectedSeason = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedOccasion,
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
                        _selectedOccasion = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedGenderTarget,
                    decoration: const InputDecoration(
                      labelText: 'Gender Target',
                      border: OutlineInputBorder(),
                    ),
                    items: genderTargets
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
                        _selectedGenderTarget = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _styleTagsController,
                    decoration: const InputDecoration(
                      labelText: 'Style Tags',
                      hintText: 'smart casual, minimal, premium',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notesController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      hintText: 'Fit, fabric, or when this piece works best',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _isLoading ? null : _saveItem,
              child: Text(_isLoading ? 'Saving...' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
