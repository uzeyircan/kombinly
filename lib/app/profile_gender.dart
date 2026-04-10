class ProfileGender {
  static const String male = 'male';
  static const String female = 'female';
  static const String unknown = 'User';

  static String normalize(String? value) {
    final normalized = value?.trim().toLowerCase();

    switch (normalized) {
      case 'male':
      case 'man':
      case 'men':
        return male;
      case 'female':
      case 'woman':
      case 'women':
        return female;
      default:
        return unknown;
    }
  }

  static String label(String? value) {
    switch (normalize(value)) {
      case male:
        return 'Men';
      case female:
        return 'Women';
      default:
        return unknown;
    }
  }

  static List<String> storageCandidates(String? value) {
    switch (normalize(value)) {
      case male:
        return const ['male', 'Male', 'men', 'Men', 'man', 'Man'];
      case female:
        return const [
          'female',
          'Female',
          'women',
          'Women',
          'woman',
          'Woman',
        ];
      default:
        return const [];
    }
  }
}
