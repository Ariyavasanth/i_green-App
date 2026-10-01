import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'brand_logo_data.dart';

class PayslipLogoAssets {
  static const String tecLogoPath = 'assets/igreen_logo_engineering.png';
  static const String techLogoPath = 'assets/igreen_logo_technology.png';

  static Uint8List? _cachedTecBytes;
  static Uint8List? _cachedTechBytes;

  static void ensureAssetsExist() {}

  static Future<Uint8List> getTecEngineeringLogoBytes() async {
    if (_cachedTecBytes != null && _cachedTecBytes!.isNotEmpty) {
      return _cachedTecBytes!;
    }
    try {
      final data = await rootBundle.load(tecLogoPath);
      _cachedTecBytes = data.buffer.asUint8List();
      return _cachedTecBytes!;
    } catch (_) {}
    return kBrandLogoBytes;
  }

  static Future<Uint8List> getTechnologiesLogoBytes() async {
    if (_cachedTechBytes != null && _cachedTechBytes!.isNotEmpty) {
      return _cachedTechBytes!;
    }
    try {
      final data = await rootBundle.load(techLogoPath);
      _cachedTechBytes = data.buffer.asUint8List();
      return _cachedTechBytes!;
    } catch (_) {}
    return kBrandLogoBytes;
  }
}
