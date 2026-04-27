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

/// İlk sürüm için oran bazlı sabit slot tanımları.
/// Amaç: farklı ekran boyutlarında tutarlı davranmak ve
/// kıyafetleri avatar üzerinde daha doğal bölgelere yerleştirmek.
class AvatarSlots {
  static const AvatarSlot upperBody = AvatarSlot(
    id: 'upper_body',
    centerX: 0.50,
    centerY: 0.285,
    widthRatio: 0.48,
    heightRatio: 0.30,
    zIndex: 20,
  );

  static const AvatarSlot lowerBody = AvatarSlot(
    id: 'lower_body',
    centerX: 0.50,
    centerY: 0.60,
    widthRatio: 0.36,
    heightRatio: 0.30,
    zIndex: 15,
  );

  static const AvatarSlot outerwear = AvatarSlot(
    id: 'outerwear',
    centerX: 0.50,
    centerY: 0.36,
    widthRatio: 0.46,
    heightRatio: 0.44,
    zIndex: 25,
  );

  static const AvatarSlot feet = AvatarSlot(
    id: 'feet',
    centerX: 0.50,
    centerY: 0.89,
    widthRatio: 0.28,
    heightRatio: 0.10,
    zIndex: 10,
  );

  static const AvatarSlot accessories = AvatarSlot(
    id: 'accessories',
    centerX: 0.50,
    centerY: 0.22,
    widthRatio: 0.32,
    heightRatio: 0.16,
    zIndex: 30,
  );

  static const List<AvatarSlot> all = [
    upperBody,
    lowerBody,
    outerwear,
    feet,
    accessories,
  ];

  static AvatarSlot? byId(String id) {
    for (final slot in all) {
      if (slot.id == id) return slot;
    }
    return null;
  }
}
