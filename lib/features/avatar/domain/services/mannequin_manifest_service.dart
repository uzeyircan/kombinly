import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/mannequin_manifest.dart';

class MannequinManifestService {
  static const String standardManifestAsset =
      'assets/mannequin/standard_mannequin.v1.json';

  const MannequinManifestService();

  Future<MannequinManifest> loadStandardManifest() async {
    final raw = await rootBundle.loadString(standardManifestAsset);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return MannequinManifest.fromJson(json);
  }
}
