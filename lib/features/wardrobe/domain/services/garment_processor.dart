import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class GarmentProcessor {
  const GarmentProcessor();

  Future<double> detectAspectRatio(String imageUrl) async {
    final imageProvider = NetworkImage(imageUrl);
    final completer = Completer<ui.Image>();

    final stream = imageProvider.resolve(const ImageConfiguration());

    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        if (!completer.isCompleted) {
          completer.complete(info.image);
        }
        stream.removeListener(listener);
      },
      onError: (Object error, StackTrace? stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
        stream.removeListener(listener);
      },
    );

    stream.addListener(listener);

    final image = await completer.future;

    if (image.height == 0) {
      return 1.0;
    }

    return image.width / image.height;
  }

  String resolveFitProfile(String category, double aspectRatio) {
    final normalizedCategory = category.trim().toLowerCase();

    switch (normalizedCategory) {
      case 'top':
        if (aspectRatio < 0.50) return 'long_top';
        if (aspectRatio > 1.10) return 'oversized_top';
        return 'regular_top';

      case 'bottom':
        if (aspectRatio < 0.55) return 'long_bottom';
        if (aspectRatio > 0.95) return 'wide_bottom';
        return 'regular_bottom';

      case 'shoes':
        if (aspectRatio > 2.20) return 'chunky_shoes';
        return 'normal_shoes';

      case 'outerwear':
        if (aspectRatio < 0.50) return 'long_outerwear';
        return 'regular_outerwear';

      default:
        return 'default';
    }
  }
}
