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

  String resolveFitProfile(String category) {
    switch (category.trim().toLowerCase()) {
      case 'top':
        return 'regular_top';
      case 'bottom':
        return 'regular_bottom';
      case 'shoes':
        return 'normal_shoes';
      case 'outerwear':
        return 'regular_outerwear';
      default:
        return 'default';
    }
  }
}
