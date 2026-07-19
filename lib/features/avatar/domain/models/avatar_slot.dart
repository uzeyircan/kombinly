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
  /// Omuz çizgisini merkez alır. Üst kıyafetin kendi üst ankrajı bu çizgiye
  /// oturduğu için farklı en/boy oranlarında yaka konumu sabit kalır.
  static const AvatarSlot upperBody = AvatarSlot(
    id: 'upper_body',
    centerX: 0.50,
    centerY: 0.300,
    widthRatio: 0.50,
    heightRatio: 0.32,
    zIndex: 20,
  );

  /// Bel çizgisinden bacakların altına uzanan anatomik alan.
  static const AvatarSlot lowerBody = AvatarSlot(
    id: 'lower_body',
    centerX: 0.50,
    centerY: 0.625,
    widthRatio: 0.38,
    heightRatio: 0.40,
    zIndex: 15,
  );

  /// Omuzlardan dize kadar uzayabilen, üstlerden daha geniş dış giyim alanı.
  static const AvatarSlot outerwear = AvatarSlot(
    id: 'outerwear',
    centerX: 0.50,
    centerY: 0.405,
    widthRatio: 0.54,
    heightRatio: 0.55,
    zIndex: 25,
  );

  /// Ayak tabanı çizgisini çevreleyen yatay alan.
  static const AvatarSlot feet = AvatarSlot(
    id: 'feet',
    centerX: 0.50,
    centerY: 0.910,
    widthRatio: 0.34,
    heightRatio: 0.12,
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

  static AvatarSlot forCategory(String category) {
    switch (category.trim().toLowerCase()) {
      case 'bottom':
        return lowerBody;
      case 'outerwear':
        return outerwear;
      case 'shoes':
        return feet;
      case 'accessory':
      case 'accessories':
      case 'aksesuar':
        return accessories;
      case 'top':
      default:
        return upperBody;
    }
  }
}
