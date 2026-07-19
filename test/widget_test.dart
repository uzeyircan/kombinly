import 'package:flutter_test/flutter_test.dart';
import 'package:kombinly/features/avatar/domain/models/avatar_slot.dart';
import 'package:kombinly/features/avatar/domain/services/smart_placement_service.dart';

void main() {
  group('2D avatar placement', () {
    test('maps garment categories to separate anatomical slots', () {
      expect(AvatarSlots.forCategory('Top'), AvatarSlots.upperBody);
      expect(AvatarSlots.forCategory('Bottom'), AvatarSlots.lowerBody);
      expect(AvatarSlots.forCategory('Outerwear'), AvatarSlots.outerwear);
      expect(AvatarSlots.forCategory('Shoes'), AvatarSlots.feet);
    });

    test('uses aspect ratio and fit profile for automatic placement', () {
      const service = SmartPlacementService();

      final regularTop = service.resolve(category: 'Top', aspectRatio: 1);
      final wideTop = service.resolve(category: 'Top', aspectRatio: 1.8);
      final longBottom = service.resolve(
        category: 'Bottom',
        aspectRatio: 0.45,
        fitProfile: 'long_bottom',
      );

      expect(wideTop.cropScale, lessThan(regularTop.cropScale));
      expect(wideTop.offsetX, isNegative);
      expect(longBottom.cropScale, closeTo(0.94, 0.001));
      expect(longBottom.offsetY, closeTo(24, 0.001));
      expect(longBottom.rotation, 0);
    });

    test('normalizes invalid aspect ratios', () {
      const service = SmartPlacementService();
      final result = service.resolve(
        category: 'Shoes',
        aspectRatio: double.nan,
      );

      expect(result.cropScale, 0.82);
      expect(result.offsetY, 10);
    });
  });
}
