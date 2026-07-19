import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class GarmentCropResult {
  final Uint8List bytes;
  final double aspectRatio;

  const GarmentCropResult({required this.bytes, required this.aspectRatio});
}

class GarmentProcessor {
  const GarmentProcessor();

  /// Arka planı silinmiş bir PNG'nin şeffaf olmayan (gerçek kıyafet)
  /// piksellerinin bounding box'ını bulup görseli o alana kırpar.
  ///
  /// Arka plan kaldırma servisleri genelde orijinal canvas boyutunu koruyup
  /// kenarlarda şeffaf boşluk bırakır. Bu boşluk, aspect ratio'yu bozup
  /// [SmartPlacementService]'in kıyafeti manken üzerinde yanlış ölçek/
  /// konumda göstermesine yol açıyordu — bu metod o kök nedeni çözer.
  Future<GarmentCropResult> cropToVisibleContent(Uint8List pngBytes) async {
    final codec = await ui.instantiateImageCodec(pngBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final width = image.width;
    final height = image.height;

    final fallbackRatio = height == 0 ? 1.0 : width / height;

    final byteData = await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (byteData == null) {
      return GarmentCropResult(bytes: pngBytes, aspectRatio: fallbackRatio);
    }

    final pixels = byteData.buffer.asUint8List();
    const alphaThreshold = 10;

    var minX = width;
    var minY = height;
    var maxX = -1;
    var maxY = -1;

    for (var y = 0; y < height; y++) {
      final rowOffset = y * width * 4;
      for (var x = 0; x < width; x++) {
        final alpha = pixels[rowOffset + x * 4 + 3];
        if (alpha > alphaThreshold) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }

    if (maxX < minX || maxY < minY) {
      return GarmentCropResult(bytes: pngBytes, aspectRatio: fallbackRatio);
    }

    final contentWidth = maxX - minX + 1;
    final contentHeight = maxY - minY + 1;
    final coverage = (contentWidth * contentHeight) / (width * height);

    if (coverage > 0.97) {
      return GarmentCropResult(bytes: pngBytes, aspectRatio: fallbackRatio);
    }

    const paddingRatio = 0.02;
    final padX = (contentWidth * paddingRatio).round();
    final padY = (contentHeight * paddingRatio).round();

    final cropLeft = (minX - padX).clamp(0, width);
    final cropTop = (minY - padY).clamp(0, height);
    final cropRight = (maxX + 1 + padX).clamp(0, width);
    final cropBottom = (maxY + 1 + padY).clamp(0, height);

    final cropWidth = cropRight - cropLeft;
    final cropHeight = cropBottom - cropTop;

    if (cropWidth <= 0 || cropHeight <= 0) {
      return GarmentCropResult(bytes: pngBytes, aspectRatio: fallbackRatio);
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final srcRect = Rect.fromLTWH(
      cropLeft.toDouble(),
      cropTop.toDouble(),
      cropWidth.toDouble(),
      cropHeight.toDouble(),
    );
    final dstRect = Rect.fromLTWH(0, 0, cropWidth.toDouble(), cropHeight.toDouble());
    canvas.drawImageRect(image, srcRect, dstRect, Paint());

    final picture = recorder.endRecording();
    final croppedImage = await picture.toImage(cropWidth, cropHeight);
    final croppedByteData = await croppedImage.toByteData(
      format: ui.ImageByteFormat.png,
    );

    if (croppedByteData == null) {
      return GarmentCropResult(bytes: pngBytes, aspectRatio: fallbackRatio);
    }

    return GarmentCropResult(
      bytes: croppedByteData.buffer.asUint8List(),
      aspectRatio: cropWidth / cropHeight,
    );
  }

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
