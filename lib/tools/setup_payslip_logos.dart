import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

void setupPayslipLogosDirect() {
  try {
    const sourceTech = r'C:\Users\USER\.gemini\antigravity-ide\brain\d98f8e46-17af-4fbb-93f0-ab0c1b6a9b8b\.user_uploaded\media_1790885314876.png';
    const sourceTec = r'C:\Users\USER\.gemini\antigravity-ide\brain\d98f8e46-17af-4fbb-93f0-ab0c1b6a9b8b\.user_uploaded\media_1790885317771.png';

    if (!File(sourceTech).existsSync() || !File(sourceTec).existsSync()) {
      return;
    }

    final techBytes = File(sourceTech).readAsBytesSync();
    final tecBytes = File(sourceTec).readAsBytesSync();

    final techB64 = base64Encode(techBytes);
    final tecB64 = base64Encode(tecBytes);

    final targetFile = File(r'e:\f_projects\I_green_technology\lib\core\theme\payslip_logo_assets.dart');

    final buffer = StringBuffer();
    buffer.writeln("import 'dart:convert';");
    buffer.writeln("import 'dart:typed_data';");
    buffer.writeln();
    buffer.writeln("class PayslipLogoAssets {");
    buffer.writeln("  static const String tecLogoPath = 'assets/igreen_tec_engineering_logo.png';");
    buffer.writeln("  static const String techLogoPath = 'assets/igreen_technologies_logo.png';");
    buffer.writeln();
    buffer.writeln("  static final Uint8List kTechnologiesLogoBytes = base64Decode('$techB64');");
    buffer.writeln("  static final Uint8List kTecEngineeringLogoBytes = base64Decode('$tecB64');");
    buffer.writeln();
    buffer.writeln("  static Uint8List getTechnologiesLogo() => kTechnologiesLogoBytes;");
    buffer.writeln("  static Uint8List getTecEngineeringLogo() => kTecEngineeringLogoBytes;");
    buffer.writeln("}");

    targetFile.writeAsStringSync(buffer.toString());
    debugPrint('✅ [PayslipLogoAssets] Successfully embedded high-res logo bytes in payslip_logo_assets.dart');
  } catch (e) {
    debugPrint('Logo setup notice: $e');
  }
}
