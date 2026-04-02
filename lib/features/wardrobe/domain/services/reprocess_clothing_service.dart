import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'garment_processor.dart';
import '../../../avatar/domain/services/smart_placement_service.dart';

class ReprocessClothingService {
  final SupabaseClient supabase;
  final GarmentProcessor garmentProcessor;
  final SmartPlacementService smartPlacementService;

  const ReprocessClothingService({
    required this.supabase,
    required this.garmentProcessor,
    required this.smartPlacementService,
  });

  Future<void> reprocess({
    required String itemId,
    required String category,
    required String originalImageUrl,
  }) async {
    final response = await supabase.functions.invoke(
      'remove-background',
      body: {'imageUrl': originalImageUrl},
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

    final bytes = base64Decode(base64Image);

    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User session not found');
    }

    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${category.toLowerCase()}_reprocessed.png';
    final path = '${user.id}/processed/$fileName';

    await supabase.storage
        .from('clothes-images')
        .uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/png',
          ),
        );

    final processedImageUrl = supabase.storage
        .from('clothes-images')
        .getPublicUrl(path);

    double aspectRatio = 1.0;
    try {
      aspectRatio = await garmentProcessor.detectAspectRatio(processedImageUrl);
    } catch (_) {
      aspectRatio = 1.0;
    }

    final fitProfile = garmentProcessor.resolveFitProfile(
      category,
      aspectRatio,
    );

    final smartPlacement = smartPlacementService.resolve(
      category: category,
      aspectRatio: aspectRatio,
      fitProfile: fitProfile,
    );

    await supabase
        .from('clothes')
        .update({
          'image_url': processedImageUrl,
          'processed_image_url': processedImageUrl,
          'aspect_ratio': aspectRatio,
          'fit_profile': fitProfile,
          'crop_scale': smartPlacement.cropScale,
          'offset_x': smartPlacement.offsetX,
          'offset_y': smartPlacement.offsetY,
          'rotation': smartPlacement.rotation,
          'is_processed': true,
          'needs_review': false,
          'last_processed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', itemId);
  }
}
