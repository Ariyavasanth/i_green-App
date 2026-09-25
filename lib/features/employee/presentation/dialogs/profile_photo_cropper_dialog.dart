import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../../../core/theme/app_colors.dart';

/// WhatsApp-style responsive profile photo cropper:
/// - Desktop / Laptop (width >= 650): WhatsApp Web style with circular cutout,
///   "Drag the image to adjust" title, Upload button, zoom pill (+ / -), and green checkmark button.
/// - Mobile (width < 650): WhatsApp Mobile style with 1:1 square crop box, corner brackets,
///   3x3 rule-of-thirds grid, Cancel button, Rotate button, and Done button.
class ProfilePhotoCropperDialog extends StatefulWidget {
  const ProfilePhotoCropperDialog({
    required this.initialBytes,
    super.key,
  });

  final Uint8List initialBytes;

  static Future<Uint8List?> show({
    required BuildContext context,
    required Uint8List rawBytes,
  }) {
    return Navigator.of(context, rootNavigator: true).push<Uint8List>(
      PageRouteBuilder<Uint8List>(
        opaque: false,
        barrierDismissible: false,
        barrierColor: Colors.black,
        pageBuilder: (context, animation, secondaryAnimation) {
          return ProfilePhotoCropperDialog(initialBytes: rawBytes);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<ProfilePhotoCropperDialog> createState() => _ProfilePhotoCropperDialogState();
}

class _ProfilePhotoCropperDialogState extends State<ProfilePhotoCropperDialog> {
  ui.Image? _uiImage;
  bool _isLoading = true;
  bool _isExporting = false;

  Offset _offset = Offset.zero;
  Offset _lastFocalPoint = Offset.zero;
  double _scale = 1.0;
  double _baseScale = 1.0;
  double _minScale = 1.0;
  double _maxScale = 5.0;
  int _rotation = 0; // 0, 90, 180, 270

  Size _viewportSize = Size.zero;
  double _cropSize = 280.0;
  bool _hasInitializedScale = false;

  @override
  void initState() {
    super.initState();
    _loadImage(widget.initialBytes);
  }

  Future<void> _loadImage(Uint8List bytes) async {
    setState(() => _isLoading = true);
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() {
        _uiImage = frame.image;
        _isLoading = false;
        _offset = Offset.zero;
        _rotation = 0;
        _hasInitializedScale = false;
      });
      _recalculateConstraints();
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pop(null);
      }
    }
  }

  void _recalculateConstraints() {
    if (_uiImage == null || _viewportSize == Size.zero) return;

    final isRotated = (_rotation % 180) != 0;
    final imgW = isRotated ? _uiImage!.height.toDouble() : _uiImage!.width.toDouble();
    final imgH = isRotated ? _uiImage!.width.toDouble() : _uiImage!.height.toDouble();

    final scaleX = _cropSize / imgW;
    final scaleY = _cropSize / imgH;
    final fitScale = math.max(scaleX, scaleY);
    _minScale = fitScale * 0.6; // Allow zooming out slightly
    _maxScale = fitScale * 6.0; // Allow close-up framing

    if (!_hasInitializedScale || _scale < _minScale || _scale > _maxScale) {
      _scale = fitScale;
      _hasInitializedScale = true;
    }
    _clampOffset();
  }

  void _clampOffset() {
    if (_uiImage == null) return;

    final isRotated = (_rotation % 180) != 0;
    final imgW = (isRotated ? _uiImage!.height : _uiImage!.width).toDouble();
    final imgH = (isRotated ? _uiImage!.width : _uiImage!.height).toDouble();

    final halfW = (imgW / 2) * _scale;
    final halfH = (imgH / 2) * _scale;
    final cropHalf = _cropSize / 2;

    // Allow flexible panning so the user can easily center their face or subject
    final maxDx = halfW + cropHalf * 0.35;
    final maxDy = halfH + cropHalf * 0.35;

    _offset = Offset(
      _offset.dx.clamp(-maxDx, maxDx),
      _offset.dy.clamp(-maxDy, maxDy),
    );
  }

  Future<void> _pickAnotherPhoto() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      final file = result?.files.firstOrNull;
      if (file != null && file.bytes != null) {
        await _loadImage(file.bytes!);
      }
    } catch (_) {}
  }

  void _rotateCounterClockwise() {
    setState(() {
      _rotation = (_rotation - 90) % 360;
      if (_rotation < 0) _rotation += 360;
      _offset = Offset.zero;
      _hasInitializedScale = false;
      _recalculateConstraints();
    });
  }

  Future<void> _exportCroppedImage() async {
    if (_uiImage == null || _isExporting) return;

    setState(() => _isExporting = true);
    try {
      // 720x720 canvas gives crystal-clear, razor-sharp clarity while keeping compressed size ~50-70KB
      const double outputSize = 720.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, outputSize, outputSize));

      final double s = outputSize / _cropSize;

      canvas.save();
      // Center of output square
      canvas.translate(outputSize / 2, outputSize / 2);
      // Offset scaled precisely to output coordinates
      canvas.translate(_offset.dx * s, _offset.dy * s);

      if (_rotation != 0) {
        canvas.rotate(_rotation * math.pi / 180);
      }

      canvas.scale(_scale * s, _scale * s);

      final paint = Paint()
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high;

      canvas.drawImage(
        _uiImage!,
        Offset(-_uiImage!.width / 2, -_uiImage!.height / 2),
        paint,
      );

      canvas.restore();

      final picture = recorder.endRecording();
      final imgResult = await picture.toImage(outputSize.toInt(), outputSize.toInt());
      final byteData = await imgResult.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        if (mounted) setState(() => _isExporting = false);
        return;
      }

      // Convert to compressed JPEG (quality 85) to prevent exceeding Firestore 1MB document limit
      final pngBytes = byteData.buffer.asUint8List();
      final decoded = img.decodeImage(pngBytes);
      Uint8List finalBytes;
      if (decoded != null) {
        finalBytes = Uint8List.fromList(img.encodeJpg(decoded, quality: 85));
      } else {
        finalBytes = pngBytes;
      }

      if (mounted) {
        Navigator.of(context).pop(finalBytes);
      }
    } catch (_) {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;
        return isMobile ? _buildMobileCropper() : _buildDesktopCropper();
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ── 1. Desktop / Laptop (WhatsApp Web Style - Image 2) ──────
  // ─────────────────────────────────────────────────────────────
  Widget _buildDesktopCropper() {
    return Scaffold(
      backgroundColor: const Color(0xFF222E35),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Container(
              height: 56,
              color: const Color(0xFF111B21),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                    tooltip: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(null),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Drag the image to adjust',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _pickAnotherPhoto,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.upload_rounded, color: Colors.white, size: 19),
                          SizedBox(width: 6),
                          Text(
                            'Upload',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Viewport with circular mask & zoom controls
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
                  _cropSize = math.min(
                    math.min(constraints.maxWidth * 0.75, constraints.maxHeight * 0.72),
                    380.0,
                  );
                  _recalculateConstraints();

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Interactive image area
                      _buildInteractiveImage(),

                      // Circular mask overlay
                      IgnorePointer(
                        child: CustomPaint(
                          size: _viewportSize,
                          painter: _CircleCropMaskPainter(
                            cropCenter: Offset(_viewportSize.width / 2, _viewportSize.height / 2),
                            cropRadius: _cropSize / 2,
                          ),
                        ),
                      ),

                      // Zoom controls pill on the right
                      Positioned(
                        right: 24,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F2C34).withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.add, color: Colors.white, size: 20),
                                tooltip: 'Zoom In',
                                onPressed: () {
                                  setState(() {
                                    _scale = (_scale * 1.15).clamp(_minScale, _maxScale);
                                    _clampOffset();
                                  });
                                },
                              ),
                              Container(
                                width: 22,
                                height: 1,
                                color: Colors.white24,
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove, color: Colors.white, size: 20),
                                tooltip: 'Zoom Out',
                                onPressed: () {
                                  setState(() {
                                    _scale = (_scale / 1.15).clamp(_minScale, _maxScale);
                                    _clampOffset();
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Green checkmark FAB at bottom-right
                      Positioned(
                        right: 28,
                        bottom: 28,
                        child: Material(
                          color: const Color(0xFF25D366),
                          shape: const CircleBorder(),
                          elevation: 6,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _isExporting ? null : _exportCroppedImage,
                            child: Container(
                              width: 56,
                              height: 56,
                              alignment: Alignment.center,
                              child: _isExporting
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.check_rounded,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ── 2. Mobile (WhatsApp Mobile Style - Image 3) ──────────────
  // ─────────────────────────────────────────────────────────────
  Widget _buildMobileCropper() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Center crop box viewport
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
                  _cropSize = math.min(constraints.maxWidth * 0.88, constraints.maxHeight * 0.75);
                  _recalculateConstraints();

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Interactive image
                      _buildInteractiveImage(),

                      // Square crop mask with corner brackets & 3x3 grid
                      IgnorePointer(
                        child: CustomPaint(
                          size: _viewportSize,
                          painter: _SquareCropMaskPainter(
                            cropCenter: Offset(_viewportSize.width / 2, _viewportSize.height / 2),
                            cropSize: _cropSize,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Bottom Action Bar: Cancel, Rotate, Done
            Container(
              height: 64,
              color: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Color(0xFF25D366),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.rotate_90_degrees_ccw_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                    tooltip: 'Rotate',
                    onPressed: _rotateCounterClockwise,
                  ),
                  TextButton(
                    onPressed: _isExporting ? null : _exportCroppedImage,
                    child: _isExporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Color(0xFF25D366),
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Done',
                            style: TextStyle(
                              color: Color(0xFF25D366),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
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

  // ─────────────────────────────────────────────────────────────
  // ── Gesture handling & image painter ─────────────────────────
  // ─────────────────────────────────────────────────────────────
  Widget _buildInteractiveImage() {
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          setState(() {
            final delta = event.scrollDelta.dy;
            final factor = delta > 0 ? 0.92 : 1.08;
            _scale = (_scale * factor).clamp(_minScale, _maxScale);
            _clampOffset();
          });
        }
      },
      child: GestureDetector(
        onScaleStart: (details) {
          _baseScale = _scale;
          _lastFocalPoint = details.focalPoint;
        },
        onScaleUpdate: (details) {
          setState(() {
            _scale = (_baseScale * details.scale).clamp(_minScale, _maxScale);
            _offset += details.focalPoint - _lastFocalPoint;
            _lastFocalPoint = details.focalPoint;
            _clampOffset();
          });
        },
        child: Container(
          color: Colors.transparent,
          width: _viewportSize.width,
          height: _viewportSize.height,
          child: CustomPaint(
            size: _viewportSize,
            painter: _ImageCanvasPainter(
              image: _uiImage!,
              offset: _offset,
              scale: _scale,
              rotation: _rotation,
              center: Offset(_viewportSize.width / 2, _viewportSize.height / 2),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ── Custom Painters ──────────────────────────────────────────
// ─────────────────────────────────────────────────────────────

/// Paints the user's image with offset, scale, and rotation.
class _ImageCanvasPainter extends CustomPainter {
  _ImageCanvasPainter({
    required this.image,
    required this.offset,
    required this.scale,
    required this.rotation,
    required this.center,
  });

  final ui.Image image;
  final Offset offset;
  final double scale;
  final int rotation;
  final Offset center;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(center.dx + offset.dx, center.dy + offset.dy);

    if (rotation != 0) {
      canvas.rotate(rotation * math.pi / 180);
    }

    canvas.scale(scale, scale);

    final paint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;

    canvas.drawImage(
      image,
      Offset(-image.width / 2, -image.height / 2),
      paint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ImageCanvasPainter oldDelegate) {
    return oldDelegate.offset != offset ||
        oldDelegate.scale != scale ||
        oldDelegate.rotation != rotation ||
        oldDelegate.image != image;
  }
}

/// Circular mask for Desktop / Laptop (WhatsApp Web style).
class _CircleCropMaskPainter extends CustomPainter {
  _CircleCropMaskPainter({
    required this.cropCenter,
    required this.cropRadius,
  });

  final Offset cropCenter;
  final double cropRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCircle(center: cropCenter, radius: cropRadius))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: 0.65),
    );

    canvas.drawCircle(
      cropCenter,
      cropRadius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _CircleCropMaskPainter oldDelegate) {
    return oldDelegate.cropCenter != cropCenter || oldDelegate.cropRadius != cropRadius;
  }
}

/// Square 1:1 crop mask with corner brackets & 3x3 grid for Mobile (WhatsApp Mobile style).
class _SquareCropMaskPainter extends CustomPainter {
  _SquareCropMaskPainter({
    required this.cropCenter,
    required this.cropSize,
  });

  final Offset cropCenter;
  final double cropSize;

  @override
  void paint(Canvas canvas, Size size) {
    final cropRect = Rect.fromCenter(center: cropCenter, width: cropSize, height: cropSize);

    // Darkened outer area
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(cropRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: 0.65),
    );

    // Subtle square border
    canvas.drawRect(
      cropRect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // 3x3 rule of thirds grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final third = cropSize / 3;
    canvas.drawLine(
      Offset(cropRect.left + third, cropRect.top),
      Offset(cropRect.left + third, cropRect.bottom),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left + 2 * third, cropRect.top),
      Offset(cropRect.left + 2 * third, cropRect.bottom),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + third),
      Offset(cropRect.right, cropRect.top + third),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + 2 * third),
      Offset(cropRect.right, cropRect.top + 2 * third),
      gridPaint,
    );

    // 4 Corner Brackets (White, thick 3.5px, length 28px)
    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.square;

    const double cl = 28.0;

    // Top-left corner
    canvas.drawLine(Offset(cropRect.left, cropRect.top), Offset(cropRect.left + cl, cropRect.top), cornerPaint);
    canvas.drawLine(Offset(cropRect.left, cropRect.top), Offset(cropRect.left, cropRect.top + cl), cornerPaint);

    // Top-right corner
    canvas.drawLine(Offset(cropRect.right, cropRect.top), Offset(cropRect.right - cl, cropRect.top), cornerPaint);
    canvas.drawLine(Offset(cropRect.right, cropRect.top), Offset(cropRect.right, cropRect.top + cl), cornerPaint);

    // Bottom-left corner
    canvas.drawLine(Offset(cropRect.left, cropRect.bottom), Offset(cropRect.left + cl, cropRect.bottom), cornerPaint);
    canvas.drawLine(Offset(cropRect.left, cropRect.bottom), Offset(cropRect.left, cropRect.bottom - cl), cornerPaint);

    // Bottom-right corner
    canvas.drawLine(Offset(cropRect.right, cropRect.bottom), Offset(cropRect.right - cl, cropRect.bottom), cornerPaint);
    canvas.drawLine(Offset(cropRect.right, cropRect.bottom), Offset(cropRect.right, cropRect.bottom - cl), cornerPaint);

    // 4 Edge center markers (tick marks)
    const double ml = 18.0;
    // Top edge
    canvas.drawLine(Offset(cropCenter.dx - ml / 2, cropRect.top), Offset(cropCenter.dx + ml / 2, cropRect.top), cornerPaint);
    // Bottom edge
    canvas.drawLine(Offset(cropCenter.dx - ml / 2, cropRect.bottom), Offset(cropCenter.dx + ml / 2, cropRect.bottom), cornerPaint);
    // Left edge
    canvas.drawLine(Offset(cropRect.left, cropCenter.dy - ml / 2), Offset(cropRect.left, cropCenter.dy + ml / 2), cornerPaint);
    // Right edge
    canvas.drawLine(Offset(cropRect.right, cropCenter.dy - ml / 2), Offset(cropRect.right, cropCenter.dy + ml / 2), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _SquareCropMaskPainter oldDelegate) {
    return oldDelegate.cropCenter != cropCenter || oldDelegate.cropSize != cropSize;
  }
}
