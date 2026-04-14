import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../wardrobe/domain/models/clothing_item.dart';
import '../../domain/ai_try_on_defaults.dart';
import '../../domain/models/ai_try_on_generation.dart';
import '../../domain/services/ai_try_on_service.dart';

class AiTryOnPage extends StatefulWidget {
  const AiTryOnPage({super.key});

  @override
  State<AiTryOnPage> createState() => _AiTryOnPageState();
}

class _AiTryOnPageState extends State<AiTryOnPage> {
  final _service = AiTryOnService(supabase: Supabase.instance.client);
  final _promptController = TextEditingController(
    text: AiTryOnDefaults.defaultPrompt,
  );

  bool _isLoading = true;
  bool _isGenerating = false;

  ClothingItem? _selectedWardrobeItem;

  List<ClothingItem> _wardrobeItems = [];
  List<AiTryOnGeneration> _history = [];

  List<AiTryOnGeneration> get _visibleHistory {
    final visible = <AiTryOnGeneration>[];
    var hasVisibleFailure = false;

    for (final generation in _history) {
      if (generation.isFailed) {
        if (hasVisibleFailure) continue;
        hasVisibleFailure = true;
      }

      visible.add(generation);
    }

    return visible;
  }

  String _friendlyErrorMessage(AiTryOnGeneration generation) {
    final message = (generation.errorMessage ?? '').toLowerCase();
    if (message.contains('429') ||
        message.contains('quota') ||
        message.contains('rate-limit')) {
      return 'AI generation is temporarily unavailable. Please try again later.';
    }
    if (message.contains('jwt') || message.contains('unauthorized')) {
      return 'Your session needs to be refreshed before using AI Try-On again.';
    }
    if (message.trim().isEmpty) {
      return 'AI generation failed. Please try again.';
    }
    return 'AI generation failed. Please try again later.';
  }

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

  Future<void> _chooseWardrobeItem() async {
    final selected = await showModalBottomSheet<ClothingItem>(
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
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Text(
                    'Choose a wardrobe item',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
    if (_selectedWardrobeItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a wardrobe item first')),
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
        sourceClothingItem: _selectedWardrobeItem,
      );

      final refreshedHistory = await _service.loadGenerations();

      if (!mounted) return;
      setState(() {
        _history = refreshedHistory;
      });

      final message = generation.isCompleted
          ? 'AI Try-On image generated'
          : generation.isFailed
          ? _friendlyErrorMessage(generation)
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
    final visibleHistory = _visibleHistory;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F1),
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
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                children: [
                  _AiHeroCard(
                    selectedItem: _selectedWardrobeItem,
                    onPickItem: _chooseWardrobeItem,
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
                  const _AiUsageNoticeCard(),
                  const SizedBox(height: 16),
                  _PickerCard(
                    title: 'Garment source',
                    subtitle: _selectedWardrobeItem == null
                        ? 'Choose a processed item from your wardrobe'
                        : _selectedWardrobeItem!.title,
                    onTap: _chooseWardrobeItem,
                    preview: _selectedWardrobeItem?.renderImageUrl == null
                        ? null
                        : Image.network(
                            _selectedWardrobeItem!.renderImageUrl!,
                            fit: BoxFit.contain,
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
                    onPressed: _isGenerating || _selectedWardrobeItem == null
                        ? null
                        : _generate,
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
                  if (visibleHistory.isEmpty)
                    const _AiEmptyState()
                  else
                    ...visibleHistory.map((generation) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _GenerationCard(
                          generation: generation,
                          errorMessage: _friendlyErrorMessage(generation),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class _AiUsageNoticeCard extends StatelessWidget {
  const _AiUsageNoticeCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: colorScheme.primary.withValues(alpha: 0.10),
            ),
            child: Icon(
              Icons.auto_awesome_outlined,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'AI Try-On may be limited while Gemini quota is unavailable. Manual Studio stays free and instant.',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiEmptyState extends StatelessWidget {
  const _AiEmptyState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          children: [
            Icon(
              Icons.image_search_outlined,
              size: 38,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 12),
            const Text(
              'No AI try-on results yet',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose a wardrobe item and generate your first mannequin preview.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiHeroCard extends StatelessWidget {
  final ClothingItem? selectedItem;
  final VoidCallback onPickItem;

  const _AiHeroCard({required this.selectedItem, required this.onPickItem});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2F2A25), Color(0xFF9C583C), Color(0xFFE7B86F)],
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
              'AI-powered preview',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Generate a realistic try-on image',
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
            'Pick one piece from your wardrobe. Kombinly uses the shared mannequin and creates a clean visual preview.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.84),
              fontSize: 16,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.tonalIcon(
            onPressed: onPickItem,
            icon: const Icon(Icons.checkroom_outlined),
            label: Text(
              selectedItem == null ? 'Choose garment' : 'Change garment',
            ),
          ),
        ],
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
                  child:
                      preview ??
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
  final String errorMessage;

  const _GenerationCard({required this.generation, required this.errorMessage});

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
    final previewUrl =
        generation.resultImageUrl ?? generation.mannequinImageUrl;
    final imageFit = generation.resultImageUrl != null
        ? BoxFit.contain
        : BoxFit.contain;

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
              child: SizedBox(
                height: 220,
                child: Container(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  child: Image.network(
                    previewUrl,
                    fit: imageFit,
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Theme.of(
                    context,
                  ).colorScheme.errorContainer.withValues(alpha: 0.55),
                ),
                child: Text(
                  errorMessage,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    height: 1.35,
                  ),
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
