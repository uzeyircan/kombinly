class OutfitRequest {
  final String scenario;
  final String style;
  final String environment;
  final String gender;

  const OutfitRequest({
    required this.scenario,
    required this.style,
    required this.environment,
    required this.gender,
  });

  String get normalizedScenario => scenario.trim().toLowerCase();
  String get normalizedStyle => style.trim().toLowerCase();
  String get normalizedEnvironment => environment.trim().toLowerCase();
  String get normalizedGender => gender.trim().toLowerCase();

  Map<String, dynamic> toMap() {
    return {
      'scenario': scenario,
      'style': style,
      'environment': environment,
      'gender': gender,
    };
  }
}
