import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kombinly/features/wardrobe/domain/services/garment_processor.dart';

Future<Uint8List> _buildPaddedSquarePng() async {
  // 200x200 canvas, fully transparent, with an opaque 40x100 rectangle
  // roughly centered — mimics an un-cropped background-removed garment
  // photo with lots of empty margin.
  const canvasSize = 200;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final paint = ui.Paint()..color = const ui.Color(0xFFFF0000);
  canvas.drawRect(const ui.Rect.fromLTWH(80, 50, 40, 100), paint);
  final picture = recorder.endRecording();
  final image = await picture.toImage(canvasSize, canvasSize);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cropToVisibleContent trims transparent padding and fixes aspect ratio', () async {
    final paddedPng = await _buildPaddedSquarePng();
    const processor = GarmentProcessor();

    final uncroppedRatio = 200 / 200; // what the old code would have used
    final result = await processor.cropToVisibleContent(paddedPng);

    // Real content is 40 wide x 100 tall -> aspect ratio ~0.4, nowhere near
    // the padded canvas ratio of 1.0.
    expect(result.aspectRatio, closeTo(40 / 100, 0.05));
    expect(result.aspectRatio, isNot(closeTo(uncroppedRatio, 0.05)));

    // Decode the cropped bytes back to confirm dimensions actually shrank.
    final codec = await ui.instantiateImageCodec(result.bytes);
    final frame = await codec.getNextFrame();
    expect(frame.image.width, lessThan(200));
    expect(frame.image.height, lessThan(200));
  });
}
