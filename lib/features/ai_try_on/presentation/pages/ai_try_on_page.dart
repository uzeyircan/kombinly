import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../wardrobe/domain/models/clothing_item.dart';
import '../../domain/ai_try_on_defaults.dart';
import '../../domain/models/ai_try_on_generation.dart';
import '../../domain/services/ai_try_on_service.dart';

enum GarmentSourceMode { wardrobe, upload }

class AiTryOnPage extends StatefulWidget {
  const AiTryOnPage({super.key});

  @override
  State<AiTryOnPage> createState() => _AiTryOnPageState();
}

class _AiTryOnPageState extends State<AiTryOnPage> {
  final _service = AiTryOnService(supabase: Supabase.instance.client);
  final _imagePicker = ImagePicker();
  final _promptController = TextEditingController(
    text: AiTryOnDefaults.defaultPrompt,
  );

  bool _isLoading = true;
  bool _isGenerating = false;

  GarmentSourceMode _sourceMode = GarmentSourceMode.wardrobe;
  ClothingItem? _selectedWardrobeItem;
  XFile? _uploadedGarmentImage;

  List<ClothingItem> _wardrobeItems = [];
  List<AiTryOnGeneration> _history = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final wardrobeItems = await _service.loadWardrobeItems();
      final history = await _service.loadGenerations();

      if (!mounted) return;
      setState(() {
        _wardrobeItems = wardrobeItems;
        _history = history;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load AI Try-On: $e')));
    }
  }

  Future<void> _pickGarmentUpload() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    if (picked == null) return;

    setState(() {
      _uploadedGarmentImage = picked;
    });
  }

  Future<void> _chooseWardrobeItem() async {
    final selected = await showModalBottomSheet<ClothingItem>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Text(
                    'Choose a wardrobe item',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: _wardrobeItems.isEmpty
                      ? const Center(
                          child: Text(
                            'No wardrobe items yet.\nAdd some clothes first.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _wardrobeItems.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = _wardrobeItems[index];
                            return ListTile(
                              leading: _RemoteThumbnail(
                                imageUrl: item.renderImageUrl,
                              ),
                              title: Text(item.title),
                              subtitle: Text(
                                '${item.category} • ${item.color} • ${item.occasion}',
                              ),
                              trailing: item.id == _selectedWardrobeItem?.id
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

    if (selected == null) return;

    setState(() {
      _selectedWardrobeItem = selected;
    });
  }

  Future<void> _generate() async {
    if (_sourceMode == GarmentSourceMode.wardrobe &&
        _selectedWardrobeItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a wardrobe item first')),
      );
      return;
    }

    if (_sourceMode == GarmentSourceMode.upload && _uploadedGarmentImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload a garment image first')),
      );
      return;
    }

    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Prompt cannot be empty')));
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final generation = await _service.createGeneration(
        prompt: prompt,
        sourceClothingItem: _sourceMode == GarmentSourceMode.wardrobe
            ? _selectedWardrobeItem
            : null,
        garmentUpload: _sourceMode == GarmentSourceMode.upload
            ? _uploadedGarmentImage
            : null,
      );

      final refreshedHistory = await _service.loadGenerations();

      if (!mounted) return;
      setState(() {
        _history = refreshedHistory;
      });

      final message = generation.isCompleted
          ? 'AI Try-On image generated'
          : generation.isFailed
          ? 'Generation failed. Check the latest card for details.'
          : 'Generation submitted. Refresh to check updated status.';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Generation failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Try-On'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Text(
                    'Create a realistic try-on image on the standard Kombinly mannequin using a wardrobe item or a new garment image.',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  _StaticInfoCard(
                    title: 'Standard mannequin',
                    subtitle:
                        'All generations use the same base mannequin for more consistent output and lower cost.',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 92,
                        height: 92,
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        child: Image.asset(
                          'assets/body.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<GarmentSourceMode>(
                    segments: const [
                      ButtonSegment(
                        value: GarmentSourceMode.wardrobe,
                        label: Text('Wardrobe'),
                        icon: Icon(Icons.checkroom_outlined),
                      ),
                      ButtonSegment(
                        value: GarmentSourceMode.upload,
                        label: Text('Upload'),
                        icon: Icon(Icons.upload_file_outlined),
                      ),
                    ],
                    selected: {_sourceMode},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _sourceMode = selection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_sourceMode == GarmentSourceMode.wardrobe)
                    _PickerCard(
                      title: 'Garment source',
                      subtitle: _selectedWardrobeItem == null
                          ? 'Choose an item from your wardrobe'
                          : _selectedWardrobeItem!.title,
                      onTap: _chooseWardrobeItem,
                      preview: _selectedWardrobeItem?.renderImageUrl == null
                          ? null
                          : Image.network(
                              _selectedWardrobeItem!.renderImageUrl!,
                              fit: BoxFit.contain,
                            ),
                    )
                  else
                    _PickerCard(
                      title: 'Garment upload',
                      subtitle: _uploadedGarmentImage == null
                          ? 'Choose a standalone clothing image'
                          : 'Tap to change uploaded garment image',
                      onTap: _pickGarmentUpload,
                      preview: _uploadedGarmentImage == null
                          ? null
                          : Image.file(
                              File(_uploadedGarmentImage!.path),
                              fit: BoxFit.cover,
                            ),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _promptController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Prompt',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _isGenerating ? null : _generate,
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(
                      _isGenerating ? 'Generating...' : 'Generate AI Try-On',
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Recent generations',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _loadData,
                        child: const Text('Refresh'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_history.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Text(
                        'No AI try-on results yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                    )
                  else
                    ..._history.map((generation) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _GenerationCard(generation: generation),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class _PickerCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? preview;

  const _PickerCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.preview,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 92,
                  height: 92,
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  child: preview ??
                      const Icon(Icons.add_photo_alternate_outlined, size: 36),
                ),
              ),
              const SizedBox(width: 16),
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
                    const SizedBox(height: 6),
                    Text(subtitle),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaticInfoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _StaticInfoCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            child,
            const SizedBox(width: 16),
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
                  const SizedBox(height: 6),
                  Text(subtitle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenerationCard extends StatelessWidget {
  final AiTryOnGeneration generation;

  const _GenerationCard({required this.generation});

  Color _statusColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (generation.status) {
      case 'completed':
        return scheme.primary;
      case 'failed':
        return scheme.error;
      case 'processing':
        return Colors.orange;
      case 'queued':
      default:
        return scheme.secondary;
    }
  }

  String _statusLabel() {
    switch (generation.status) {
      case 'completed':
        return 'Completed';
      case 'failed':
        return 'Failed';
      case 'processing':
        return 'Processing';
      case 'queued':
      default:
        return 'Queued';
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewUrl = generation.resultImageUrl ?? generation.mannequinImageUrl;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  child: Image.network(
                    previewUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Center(
                      child: Icon(Icons.broken_image_outlined, size: 42),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: _statusColor(context).withValues(alpha: 0.12),
                  ),
                  child: Text(
                    _statusLabel(),
                    style: TextStyle(
                      color: _statusColor(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${generation.createdAt.day.toString().padLeft(2, '0')}.${generation.createdAt.month.toString().padLeft(2, '0')}.${generation.createdAt.year}',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              generation.prompt,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (generation.errorMessage != null &&
                generation.errorMessage!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                generation.errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RemoteThumbnail extends StatelessWidget {
  final String? imageUrl;

  const _RemoteThumbnail({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 52,
        height: 52,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: imageUrl == null || imageUrl!.isEmpty
            ? const Icon(Icons.image_not_supported_outlined)
            : Image.network(
                imageUrl!,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.broken_image_outlined),
              ),
      ),
    );
  }
}
