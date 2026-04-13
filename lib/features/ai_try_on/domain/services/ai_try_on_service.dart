import 'dart:io';
import 'dart:math';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../wardrobe/domain/models/clothing_item.dart';
import '../ai_try_on_defaults.dart';
import '../models/ai_try_on_generation.dart';

class AiTryOnService {
  static const String _inputBucket = 'ai-try-on-inputs';
  static const String _generationTable = 'ai_try_on_generations';
  static const String _functionName = 'ai-try-on';

  final SupabaseClient supabase;

  const AiTryOnService({required this.supabase});

  Future<List<ClothingItem>> loadWardrobeItems() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User session not found');
    }

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
        // Old rows can be partially missing after schema experiments.
      }
    }

    return items;
  }

  Future<List<AiTryOnGeneration>> loadGenerations() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User session not found');
    }

    final data = await supabase
        .from(_generationTable)
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return (data as List)
        .map((item) => AiTryOnGeneration.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  Future<AiTryOnGeneration> fetchGeneration(String id) async {
    final data = await supabase
        .from(_generationTable)
        .select()
        .eq('id', id)
        .single();

    return AiTryOnGeneration.fromMap(data);
  }

  Future<AiTryOnGeneration> createGeneration({
    required String prompt,
    ClothingItem? sourceClothingItem,
    XFile? garmentUpload,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User session not found');
    }

    if (sourceClothingItem == null && garmentUpload == null) {
      throw Exception('Choose a clothing image first');
    }

    final mannequinImageUrl = AiTryOnDefaults.standardMannequinImageUrl;
    if (mannequinImageUrl.contains('example.com')) {
      throw Exception(
        'Set AiTryOnDefaults.standardMannequinImageUrl before using AI Try-On',
      );
    }

    final garmentImageUrl =
        sourceClothingItem?.renderImageUrl ??
        await _uploadFile(
          userId: user.id,
          folder: 'garment',
          file: File(garmentUpload!.path),
          extension: _extractExtension(garmentUpload.path, fallback: 'jpg'),
        );

    final inserted = await supabase
        .from(_generationTable)
        .insert({
          'user_id': user.id,
          'mannequin_image_url': mannequinImageUrl,
          'garment_image_url': garmentImageUrl,
          'prompt': prompt,
          'status': 'queued',
          'source_clothing_id': sourceClothingItem?.id,
        })
        .select()
        .single();

    final generation = AiTryOnGeneration.fromMap(inserted);

    try {
      final accessToken = supabase.auth.currentSession?.accessToken;

      await supabase.functions.invoke(
        _functionName,
        headers: {
          if (accessToken != null && accessToken.isNotEmpty)
            'Authorization': 'Bearer $accessToken',
        },
        body: {
          'generationId': generation.id,
          'mannequinImageUrl': mannequinImageUrl,
          'garmentImageUrl': garmentImageUrl,
          'prompt': prompt,
        },
      );
    } catch (e) {
      await supabase
          .from(_generationTable)
          .update({'status': 'failed', 'error_message': e.toString()})
          .eq('id', generation.id);
    }

    return fetchGeneration(generation.id);
  }

  Future<String> _uploadFile({
    required String userId,
    required String folder,
    required File file,
    required String extension,
  }) async {
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}.$extension';
    final path = '$userId/$folder/$fileName';

    await supabase.storage
        .from(_inputBucket)
        .upload(
          path,
          file,
          fileOptions: FileOptions(
            upsert: true,
            contentType: _contentTypeForExtension(extension),
          ),
        );

    return supabase.storage.from(_inputBucket).getPublicUrl(path);
  }

  String _extractExtension(String path, {required String fallback}) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == path.length - 1) {
      return fallback;
    }

    return path.substring(dotIndex + 1).toLowerCase();
  }

  String _contentTypeForExtension(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'jpeg':
      case 'jpg':
      default:
        return 'image/jpeg';
    }
  }
}
