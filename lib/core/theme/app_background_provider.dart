import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class BackgroundState {
  final String? imagePath; // Base64 data string, network URL, or local path
  final bool isBase64;
  final bool isUrl;
  final double opacity; // Dark overlay opacity (0.0 = full picture, 0.6 = dark overlay for high contrast)
  final String presetKey; // 'none', 'custom', or preset name
  final String? currentEmployeeId;

  const BackgroundState({
    this.imagePath,
    this.isBase64 = false,
    this.isUrl = false,
    this.opacity = 0.25,
    this.presetKey = 'none',
    this.currentEmployeeId,
  });

  bool get hasBackground => imagePath != null && imagePath!.isNotEmpty;

  BackgroundState copyWith({
    String? imagePath,
    bool? isBase64,
    bool? isUrl,
    double? opacity,
    String? presetKey,
    String? currentEmployeeId,
    bool resetImage = false,
  }) {
    return BackgroundState(
      imagePath: resetImage ? null : (imagePath ?? this.imagePath),
      isBase64: resetImage ? false : (isBase64 ?? this.isBase64),
      isUrl: resetImage ? false : (isUrl ?? this.isUrl),
      opacity: opacity ?? this.opacity,
      presetKey: resetImage ? 'none' : (presetKey ?? this.presetKey),
      currentEmployeeId: currentEmployeeId ?? this.currentEmployeeId,
    );
  }
}

class BackgroundNotifier extends StateNotifier<BackgroundState> {
  BackgroundNotifier() : super(const BackgroundState());

  Future<void> loadSettingsForEmployee(String employeeId) async {
    if (employeeId.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('employee_theme_settings')
          .doc(employeeId)
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        state = BackgroundState(
          imagePath: data['image_path'] as String?,
          isBase64: data['is_base64'] as bool? ?? false,
          isUrl: data['is_url'] as bool? ?? false,
          opacity: (data['opacity'] as num?)?.toDouble() ?? 0.25,
          presetKey: data['preset_key'] as String? ?? 'none',
          currentEmployeeId: employeeId,
        );
      } else {
        state = state.copyWith(currentEmployeeId: employeeId);
      }
    } catch (e) {
      debugPrint('Error loading employee background: $e');
    }
  }

  Future<void> _persistCurrentState() async {
    final empId = state.currentEmployeeId;
    if (empId == null || empId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('employee_theme_settings')
          .doc(empId)
          .set({
        'employee_id': empId,
        'image_path': state.imagePath,
        'is_base64': state.isBase64,
        'is_url': state.isUrl,
        'opacity': state.opacity,
        'preset_key': state.presetKey,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving employee background: $e');
    }
  }

  void applyConfig({
    String? imagePath,
    bool isBase64 = false,
    bool isUrl = false,
    double opacity = 0.25,
    String presetKey = 'none',
  }) {
    if (imagePath == null || imagePath.isEmpty) {
      state = state.copyWith(resetImage: true, opacity: opacity);
    } else {
      state = state.copyWith(
        imagePath: imagePath,
        isBase64: isBase64,
        isUrl: isUrl,
        opacity: opacity,
        presetKey: presetKey,
      );
    }
    _persistCurrentState();
  }

  void setCustomBase64Image(String base64Str) {
    state = state.copyWith(
      imagePath: base64Str,
      isBase64: true,
      isUrl: false,
      presetKey: 'custom',
    );
    _persistCurrentState();
  }

  void setImageUrl(String url) {
    state = state.copyWith(
      imagePath: url,
      isBase64: false,
      isUrl: true,
      presetKey: 'custom_url',
    );
    _persistCurrentState();
  }

  void setPreset(String url, String key) {
    state = state.copyWith(
      imagePath: url,
      isBase64: false,
      isUrl: true,
      presetKey: key,
    );
    _persistCurrentState();
  }

  void updateOpacity(double opacity) {
    state = state.copyWith(opacity: opacity);
    _persistCurrentState();
  }

  void resetBackground() {
    state = state.copyWith(resetImage: true, opacity: 0.25);
    _persistCurrentState();
  }

  Future<bool> pickCustomImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final base64String = base64Encode(bytes);
        final ext = pickedFile.name.toLowerCase();
        final mimeType = ext.endsWith('.png')
            ? 'image/png'
            : (ext.endsWith('.webp') ? 'image/webp' : 'image/jpeg');
        setCustomBase64Image('data:$mimeType;base64,$base64String');
        return true;
      }
    } catch (e) {
      debugPrint('Error picking background image: $e');
    }
    return false;
  }
}

final appBackgroundProvider =
    StateNotifierProvider<BackgroundNotifier, BackgroundState>((ref) {
  return BackgroundNotifier();
});

/// Curated background wallpapers
class WallpaperPreset {
  final String key;
  final String title;
  final String url;
  final Color previewColor;

  const WallpaperPreset(this.key, this.title, this.url, this.previewColor);
}

const List<WallpaperPreset> kWallpaperPresets = [
  WallpaperPreset(
    'nature_forest',
    'Green Nature',
    'https://images.unsplash.com/photo-1518531933037-91b2f5f229cc?q=80&w=1200&auto=format&fit=crop',
    Color(0xFF2D5A27),
  ),
  WallpaperPreset(
    'modern_office',
    'Modern Office',
    'https://images.unsplash.com/photo-1497366216548-37526070297c?q=80&w=1200&auto=format&fit=crop',
    Color(0xFF34495E),
  ),
  WallpaperPreset(
    'soft_gradient',
    'Aura Glow',
    'https://images.unsplash.com/photo-1557683316-973673baf926?q=80&w=1200&auto=format&fit=crop',
    Color(0xFF8E44AD),
  ),
  WallpaperPreset(
    'minimal_arch',
    'Architecture',
    'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?q=80&w=1200&auto=format&fit=crop',
    Color(0xFF2C3E50),
  ),
  WallpaperPreset(
    'dark_space',
    'Dark Luxury',
    'https://images.unsplash.com/photo-1506703719100-a0f3a48c0f86?q=80&w=1200&auto=format&fit=crop',
    Color(0xFF111827),
  ),
];
