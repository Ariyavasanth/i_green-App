import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../core/theme/app_background_provider.dart';

class BackgroundPickerModal extends ConsumerStatefulWidget {
  const BackgroundPickerModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const BackgroundPickerModal(),
    );
  }

  @override
  ConsumerState<BackgroundPickerModal> createState() => _BackgroundPickerModalState();
}

class _BackgroundPickerModalState extends ConsumerState<BackgroundPickerModal> {
  late TextEditingController _urlController;
  bool _isUploading = false;

  // Local draft state — only committed when "Apply Overall Background" is pressed
  String? _draftImagePath;
  bool _draftIsBase64 = false;
  bool _draftIsUrl = false;
  double _draftOpacity = 0.25;
  String _draftPresetKey = 'none';

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();

    // Initialize draft state from current active provider state
    final currentState = ref.read(appBackgroundProvider);
    _draftImagePath = currentState.imagePath;
    _draftIsBase64 = currentState.isBase64;
    _draftIsUrl = currentState.isUrl;
    _draftOpacity = currentState.opacity;
    _draftPresetKey = currentState.presetKey;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pickImageDraft(ImageSource source) async {
    try {
      setState(() => _isUploading = true);
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
        setState(() {
          _draftImagePath = 'data:$mimeType;base64,$base64String';
          _draftIsBase64 = true;
          _draftIsUrl = false;
          _draftPresetKey = 'custom';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo selected! Tap "Apply Overall Background" below to apply.'),
              backgroundColor: Color(0xFF2563EB),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(appBackgroundProvider.notifier);
    final hasDraftBackground = _draftImagePath != null && _draftImagePath!.isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9CC70A).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.wallpaper_rounded,
                    color: Color(0xFF9CC70A),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Customize Background Photo',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        'Set your personal background or choose a preset',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Option 1: Upload Custom Photo ──
            const Text(
              'UPLOAD YOUR PHOTO',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: Color(0xFF9CC70A),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.photo_library_rounded,
                    label: 'Choose Photo',
                    subtitle: 'Pick from Gallery',
                    color: const Color(0xFF2563EB),
                    onTap: _isUploading ? null : () => _pickImageDraft(ImageSource.gallery),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Take Photo',
                    subtitle: 'Use Camera',
                    color: const Color(0xFFD97706),
                    onTap: _isUploading ? null : () => _pickImageDraft(ImageSource.camera),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── URL Option ──
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      hintText: 'Or paste image URL (https://...)',
                      hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final text = _urlController.text.trim();
                    if (text.isNotEmpty) {
                      setState(() {
                        _draftImagePath = text;
                        _draftIsBase64 = false;
                        _draftIsUrl = true;
                        _draftPresetKey = 'custom_url';
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('URL selected! Tap "Apply Overall Background" below to apply.'),
                          backgroundColor: Color(0xFF2563EB),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9CC70A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Option 2: Curated Wallpapers ──
            const Text(
              'CURATED WALLPAPERS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: Color(0xFF9CC70A),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: kWallpaperPresets.length,
                separatorBuilder: (ctx, i) => const SizedBox(width: 10),
                itemBuilder: (ctx, index) {
                  final preset = kWallpaperPresets[index];
                  final isSelected = _draftPresetKey == preset.key;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _draftImagePath = preset.url;
                        _draftIsBase64 = false;
                        _draftIsUrl = true;
                        _draftPresetKey = preset.key;
                      });
                    },
                    child: Container(
                      width: 90,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF9CC70A) : const Color(0xFFCBD5E1),
                          width: isSelected ? 2.5 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF9CC70A).withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : [],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              preset.url,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(color: preset.previewColor),
                            ),
                            Container(
                              color: Colors.black.withValues(alpha: 0.25),
                            ),
                            Center(
                              child: Text(
                                preset.title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  shadows: [Shadow(blurRadius: 3, color: Colors.black)],
                                ),
                              ),
                            ),
                            if (isSelected)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF9CC70A),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check, size: 12, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // ── Option 3: Overlay Dimming Slider (if background is selected) ──
            if (hasDraftBackground) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'OVERLAY DARKNESS (CONTRAST)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: Color(0xFF9CC70A),
                    ),
                  ),
                  Text(
                    '${(_draftOpacity * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              Slider(
                value: _draftOpacity,
                min: 0.0,
                max: 0.85,
                divisions: 17,
                activeColor: const Color(0xFF9CC70A),
                inactiveColor: const Color(0xFFE2E8F0),
                onChanged: (val) => setState(() => _draftOpacity = val),
              ),
              const SizedBox(height: 12),
            ],

            // ── Apply Overall Button ──
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final text = _urlController.text.trim();
                  if (text.isNotEmpty) {
                    _draftImagePath = text;
                    _draftIsBase64 = false;
                    _draftIsUrl = true;
                    _draftPresetKey = 'custom_url';
                  }

                  // Apply draft configuration to app background
                  notifier.applyConfig(
                    imagePath: _draftImagePath,
                    isBase64: _draftIsBase64,
                    isUrl: _draftIsUrl,
                    opacity: _draftOpacity,
                    presetKey: _draftPresetKey,
                  );

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Background applied overall across HRMS, Inventory & all modules!',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Color(0xFF16A34A),
                      duration: Duration(seconds: 3),
                    ),
                  );
                },
                icon: const Icon(Icons.check_circle_rounded, size: 20),
                label: const Text(
                  'Apply Overall Background',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9CC70A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // ── Reset Button ──
            if (hasDraftBackground)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _draftImagePath = null;
                      _draftIsBase64 = false;
                      _draftIsUrl = false;
                      _draftPresetKey = 'none';
                      _draftOpacity = 0.25;
                    });
                    notifier.resetBackground();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Background reset to default theme.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFFDC2626)),
                  label: const Text('Remove Background / Reset', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
