class AvatarSlot {
  final String id;
  final double centerX;
  final double centerY;
  final double widthRatio;
  final double heightRatio;
  final int zIndex;

  const AvatarSlot({
    required this.id,
    required this.centerX,
    required this.centerY,
    required this.widthRatio,
    required this.heightRatio,
    required this.zIndex,
  });
}

/// Uygulamanın ilk sürümü için sabit slot tanımları.
/// Oran bazlı tutulduğu için farklı ekran boyutlarında daha stabil çalışır.
class AvatarSlots {
  static const AvatarSlot upperBody = AvatarSlot(
    id: 'upper_body',
    centerX: 0.50,
    centerY: 0.30,
    widthRatio: 0.42,
    heightRatio: 0.26,
    zIndex: 20,
  );

  static const AvatarSlot lowerBody = AvatarSlot(
    id: 'lower_body',
    centerX: 0.50,
    centerY: 0.58,
    widthRatio: 0.34,
    heightRatio: 0.26,
    zIndex: 15,
  );

  static const AvatarSlot outerwear = AvatarSlot(
    id: 'outerwear',
    centerX: 0.50,
    centerY: 0.38,
    widthRatio: 0.42,
    heightRatio: 0.48,
    zIndex: 25,
  );
  static const AvatarSlot feet = AvatarSlot(
    id: 'feet',
    centerX: 0.50,
    centerY: 0.88,
    widthRatio: 0.30,
    heightRatio: 0.12,
    zIndex: 10,
  );

  static const List<AvatarSlot> all = [upperBody, lowerBody, outerwear, feet];

  static AvatarSlot? byId(String id) {
    for (final slot in all) {
      if (slot.id == id) return slot;
    }
    return null;
  }
}
