import '../../../wardrobe/domain/models/clothing_item.dart';
import '../models/outfit_recommendation.dart';
import '../models/outfit_request.dart';

class WardrobeRecommendationEngine {
  const WardrobeRecommendationEngine();

  OutfitRecommendation recommend({
    required OutfitRequest request,
    required List<ClothingItem> wardrobeItems,
    Set<String> lockedItemIds = const {},
  }) {
    final items = wardrobeItems
        .where((item) => item.renderImageUrl != null)
        .where((item) => item.renderImageUrl!.trim().isNotEmpty)
        .toList();

    final top = _pickBest(
      items: items,
      category: 'Top',
      request: request,
      lockedItemIds: lockedItemIds,
    );
    final bottom = _pickBest(
      items: items,
      category: 'Bottom',
      request: request,
      lockedItemIds: lockedItemIds,
      pairedItem: top,
    );
    final shoes = _pickBest(
      items: items,
      category: 'Shoes',
      request: request,
      lockedItemIds: lockedItemIds,
      pairedItem: bottom ?? top,
    );

    final outerwearNeeded = _needsOuterwear(request);
    final outerwear = outerwearNeeded
        ? _pickBest(
            items: items,
            category: 'Outerwear',
            request: request,
            lockedItemIds: lockedItemIds,
            pairedItem: top,
          )
        : null;

    final accessory = _pickBest(
      items: items,
      category: 'Accessory',
      request: request,
      lockedItemIds: lockedItemIds,
      pairedItem: top,
    );

    final missingItems = <String>[
      if (top == null) 'üst parça',
      if (bottom == null) 'alt parça',
      if (shoes == null) 'ayakkabı',
      if (outerwearNeeded && outerwear == null) 'dış giyim',
    ];

    final selected = <ClothingItem>[
      ?top,
      ?bottom,
      ?shoes,
      ?outerwear,
      ?accessory,
    ];
    final score = _scoreRecommendation(
      request: request,
      selectedItems: selected,
      missingItems: missingItems,
    );

    return OutfitRecommendation(
      request: request,
      top: top,
      bottom: bottom,
      shoes: shoes,
      outerwear: outerwear,
      accessory: accessory,
      score: score,
      missingItems: missingItems,
      reason: _buildReason(
        request: request,
        selectedItems: selected,
        missingItems: missingItems,
        score: score,
      ),
    );
  }

  ClothingItem? _pickBest({
    required List<ClothingItem> items,
    required String category,
    required OutfitRequest request,
    required Set<String> lockedItemIds,
    ClothingItem? pairedItem,
  }) {
    final exact = items
        .where((item) => _sameCategory(item.category, category))
        .toList();
    if (exact.isEmpty) return null;

    exact.sort((a, b) {
      final aLocked = lockedItemIds.contains(a.id);
      final bLocked = lockedItemIds.contains(b.id);
      if (aLocked != bLocked) return aLocked ? -1 : 1;

      return _scoreItem(
        item: b,
        request: request,
        pairedItem: pairedItem,
      ).compareTo(
        _scoreItem(item: a, request: request, pairedItem: pairedItem),
      );
    });

    return exact.first;
  }

  int _scoreItem({
    required ClothingItem item,
    required OutfitRequest request,
    ClothingItem? pairedItem,
  }) {
    var score = 0;
    final scenario = request.normalizedScenario;
    final style = request.normalizedStyle;
    final environment = request.normalizedEnvironment;
    final occasion = item.occasion.trim().toLowerCase();
    final season = item.season.trim().toLowerCase();
    final category = item.category.trim().toLowerCase();

    if (_matchesScenarioOccasion(scenario, occasion)) score += 32;
    if (_matchesStyle(style, occasion, category)) score += 22;
    score += _styleTagScore(item.styleTags, style);
    score += _genderTargetScore(item.genderTarget, request.normalizedGender);
    if (_matchesEnvironment(environment, season)) score += 18;
    if (item.isProcessed) score += 8;
    if (item.needsReview) score -= 8;

    if (pairedItem != null) {
      score += _colorHarmonyScore(item.color, pairedItem.color);
    }

    if (_isFormalScenario(scenario) && _isNeutralColor(item.color)) score += 6;
    if (_isNightEnvironment(environment) && _isDarkColor(item.color)) {
      score += 4;
    }
    if (_isWarmEnvironment(environment) && season == 'winter') score -= 10;
    if (_isColdEnvironment(environment) && season == 'summer') score -= 10;

    return score;
  }

  bool _sameCategory(String actual, String expected) {
    final normalized = actual.trim().toLowerCase();
    final target = expected.trim().toLowerCase();
    if (normalized == target) return true;
    if (target == 'accessory') {
      return normalized == 'accessories' || normalized == 'aksesuar';
    }
    return false;
  }

  bool _matchesScenarioOccasion(String scenario, String occasion) {
    if (occasion.isEmpty) return false;
    if (scenario.contains(occasion) || occasion.contains(scenario)) return true;

    if (_isFormalScenario(scenario)) {
      return occasion == 'office' ||
          occasion == 'formal' ||
          occasion == 'business' ||
          occasion == 'özel davet' ||
          occasion == 'special event';
    }
    if (scenario.contains('buluşma') || scenario.contains('date')) {
      return occasion == 'date' || occasion == 'casual';
    }
    if (scenario.contains('okul')) {
      return occasion == 'casual' || occasion == 'school';
    }
    if (scenario.contains('spor') || scenario.contains('yürüyüş')) {
      return occasion == 'sport' || occasion == 'casual';
    }
    if (scenario.contains('günlük') || scenario.contains('arkadaş')) {
      return occasion == 'casual';
    }

    return occasion == 'casual';
  }

  bool _matchesStyle(String style, String occasion, String category) {
    if (style.isEmpty) return false;

    if (style.contains('smart')) {
      return occasion == 'office' ||
          occasion == 'date' ||
          category == 'outerwear' ||
          category == 'shoes';
    }
    if (style.contains('klasik') || style.contains('classic')) {
      return occasion == 'office' || occasion == 'formal';
    }
    if (style.contains('casual') || style.contains('basic')) {
      return occasion == 'casual';
    }
    if (style.contains('sport')) {
      return occasion == 'sport' || occasion == 'casual';
    }
    if (style.contains('premium') || style.contains('elegant')) {
      return occasion == 'date' || occasion == 'office' || occasion == 'formal';
    }

    return false;
  }

  int _styleTagScore(List<String> tags, String requestedStyle) {
    if (tags.isEmpty || requestedStyle.isEmpty) return 0;

    final normalizedTags = tags
        .map((tag) => tag.trim().toLowerCase())
        .where((tag) => tag.isNotEmpty)
        .toList();

    if (normalizedTags.any(
      (tag) => tag == requestedStyle || requestedStyle.contains(tag),
    )) {
      return 28;
    }

    if (requestedStyle.contains('smart') &&
        normalizedTags.any(
          (tag) => tag.contains('classic') || tag.contains('klasik'),
        )) {
      return 16;
    }

    if (requestedStyle.contains('premium') &&
        normalizedTags.any(
          (tag) => tag.contains('elegant') || tag.contains('minimal'),
        )) {
      return 16;
    }

    if (requestedStyle.contains('casual') &&
        normalizedTags.any(
          (tag) => tag.contains('basic') || tag.contains('street'),
        )) {
      return 14;
    }

    return 0;
  }

  int _genderTargetScore(String? itemGenderTarget, String requestedGender) {
    final target = itemGenderTarget?.trim().toLowerCase();
    if (target == null || target.isEmpty || target == 'unisex') return 6;
    if (requestedGender.isEmpty || requestedGender == 'unisex') return 4;

    if (_genderMatches(target: target, requested: requestedGender)) return 14;
    return -18;
  }

  bool _genderMatches({required String target, required String requested}) {
    if (target == requested) return true;
    if (target == 'men' && requested == 'erkek') return true;
    if (target == 'male' && requested == 'erkek') return true;
    if (target == 'women' && requested == 'kadın') return true;
    if (target == 'female' && requested == 'kadın') return true;
    return false;
  }

  bool _matchesEnvironment(String environment, String season) {
    if (environment.isEmpty || season == 'all seasons') return true;
    if (_isWarmEnvironment(environment)) {
      return season == 'summer' ||
          season == 'spring' ||
          season == 'all seasons';
    }
    if (_isColdEnvironment(environment)) {
      return season == 'winter' ||
          season == 'autumn' ||
          season == 'all seasons';
    }
    if (environment.contains('bahar')) {
      return season == 'spring' ||
          season == 'autumn' ||
          season == 'all seasons';
    }
    return true;
  }

  int _colorHarmonyScore(String colorA, String colorB) {
    final a = colorA.trim().toLowerCase();
    final b = colorB.trim().toLowerCase();
    if (a.isEmpty || b.isEmpty) return 0;
    if (a == b) return 7;
    if (_isNeutralColor(a) || _isNeutralColor(b)) return 12;

    const goodPairs = {
      'blue-white',
      'white-blue',
      'blue-black',
      'black-blue',
      'beige-black',
      'black-beige',
      'red-black',
      'black-red',
      'red-white',
      'white-red',
      'gray-blue',
      'blue-gray',
    };

    return goodPairs.contains('$a-$b') ? 14 : 2;
  }

  int _scoreRecommendation({
    required OutfitRequest request,
    required List<ClothingItem> selectedItems,
    required List<String> missingItems,
  }) {
    if (selectedItems.isEmpty) return 0;

    var score = 45 + (selectedItems.length * 12) - (missingItems.length * 14);
    if (selectedItems.any(
      (item) => _matchesScenarioOccasion(
        request.normalizedScenario,
        item.occasion.trim().toLowerCase(),
      ),
    )) {
      score += 12;
    }
    if (selectedItems.any(
      (item) => _matchesEnvironment(
        request.normalizedEnvironment,
        item.season.trim().toLowerCase(),
      ),
    )) {
      score += 8;
    }

    return score.clamp(0, 100);
  }

  String _buildReason({
    required OutfitRequest request,
    required List<ClothingItem> selectedItems,
    required List<String> missingItems,
    required int score,
  }) {
    if (selectedItems.isEmpty) {
      return 'Bu kriterlere göre gardıropta kullanılabilir parça bulunamadı.';
    }

    final itemNames = selectedItems.map((item) => item.title).join(', ');
    final base =
        '${request.scenario} senaryosu için ${request.style} stile yakın, ${request.environment} koşullarına uyabilecek parçalar seçildi: $itemNames.';

    if (missingItems.isEmpty) {
      return '$base Kombin dengeli görünüyor ve gardıroptaki mevcut bilgilerle $score/100 uygunluk aldı.';
    }

    return '$base Kombin kullanılabilir, ancak ${missingItems.join(', ')} eksik olduğu için uygunluk $score/100 seviyesinde kaldı.';
  }

  bool _needsOuterwear(OutfitRequest request) {
    final environment = request.normalizedEnvironment;
    return _isColdEnvironment(environment) ||
        environment.contains('yağmur') ||
        environment.contains('açık hava');
  }

  bool _isFormalScenario(String scenario) {
    return scenario.contains('iş') ||
        scenario.contains('ofis') ||
        scenario.contains('düğün') ||
        scenario.contains('davet') ||
        scenario.contains('görüşme') ||
        scenario.contains('akşam yemeği');
  }

  bool _isWarmEnvironment(String environment) {
    return environment.contains('sıcak') ||
        environment.contains('yaz') ||
        environment.contains('summer');
  }

  bool _isColdEnvironment(String environment) {
    return environment.contains('soğuk') ||
        environment.contains('kış') ||
        environment.contains('winter');
  }

  bool _isNightEnvironment(String environment) {
    return environment.contains('gece') || environment.contains('night');
  }

  bool _isNeutralColor(String color) {
    final normalized = color.trim().toLowerCase();
    return normalized == 'black' ||
        normalized == 'white' ||
        normalized == 'gray' ||
        normalized == 'grey' ||
        normalized == 'beige';
  }

  bool _isDarkColor(String color) {
    final normalized = color.trim().toLowerCase();
    return normalized == 'black' ||
        normalized == 'navy' ||
        normalized == 'brown' ||
        normalized == 'gray' ||
        normalized == 'grey';
  }
}
