import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Full-screen clean, WhatsApp-style profile photo viewer.
/// View-only with pinch-to-zoom, pan, double-tap zoom, and hero transition.
/// Contains no edit or change controls.
class ProfilePhotoViewerDialog extends StatefulWidget {
  const ProfilePhotoViewerDialog({
    required this.displayName,
    required this.initial,
    this.photoBytes,
    this.photoUrl,
    this.heroTag = 'profile_photo_hero',
    super.key,
  });

  final String displayName;
  final String initial;
  final Uint8List? photoBytes;
  final String? photoUrl;
  final String heroTag;

  static Future<void> show({
    required BuildContext context,
    required String displayName,
    required String initial,
    Uint8List? photoBytes,
    String? photoUrl,
    String heroTag = 'profile_photo_hero',
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black,
        pageBuilder: (context, animation, secondaryAnimation) {
          return ProfilePhotoViewerDialog(
            displayName: displayName,
            initial: initial,
            photoBytes: photoBytes,
            photoUrl: photoUrl,
            heroTag: heroTag,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  State<ProfilePhotoViewerDialog> createState() => _ProfilePhotoViewerDialogState();
}

class _ProfilePhotoViewerDialogState extends State<ProfilePhotoViewerDialog>
    with SingleTickerProviderStateMixin {
  late final TransformationController _transformationController;
  late final AnimationController _animationController;
  Animation<Matrix4>? _animation;
  TapDownDetails? _doubleTapDetails;
  bool _showTopBar = true;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
        if (_animation != null) {
          _transformationController.value = _animation!.value;
        }
      });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    if (_animationController.isAnimating) return;

    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    final isZoomed = currentScale > 1.05;

    final Matrix4 targetMatrix;
    if (isZoomed) {
      targetMatrix = Matrix4.identity();
    } else {
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      const double zoomFactor = 2.5;
      final x = -position.dx * (zoomFactor - 1);
      final y = -position.dy * (zoomFactor - 1);
      targetMatrix = Matrix4.identity()
        ..translate(x, y)
        ..scale(zoomFactor);
    }

    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: targetMatrix,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward(from: 0);
  }

  void _toggleTopBar() {
    setState(() {
      _showTopBar = !_showTopBar;
    });
  }

  bool get _hasPhoto {
    if (widget.photoBytes != null && widget.photoBytes!.isNotEmpty) return true;
    final url = widget.photoUrl?.trim() ?? '';
    return url.isNotEmpty;
  }

  Widget _buildImageContent() {
    if (widget.photoBytes != null && widget.photoBytes!.isNotEmpty) {
      return Image.memory(
        widget.photoBytes!,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      );
    }

    final url = widget.photoUrl?.trim() ?? '';
    if (url.isNotEmpty) {
      if (url.startsWith('data:')) {
        try {
          final commaIdx = url.indexOf(',');
          final bytes = base64Decode(
            commaIdx != -1 ? url.substring(commaIdx + 1) : url,
          );
          return Image.memory(
            bytes,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          );
        } catch (_) {
          return _buildDefaultAvatarView();
        }
      } else if (url.startsWith('http://') || url.startsWith('https://')) {
        return Image.network(
          url,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            final expected = loadingProgress.expectedTotalBytes;
            final loaded = loadingProgress.cumulativeBytesLoaded;
            return Center(
              child: CircularProgressIndicator(
                value: expected != null && expected > 0 ? loaded / expected : null,
                color: AppColors.primary,
                strokeWidth: 2.5,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => _buildDefaultAvatarView(),
        );
      }
    }

    return _buildDefaultAvatarView();
  }

  Widget _buildDefaultAvatarView() {
    final initial = widget.initial.trim().isNotEmpty
        ? widget.initial.trim()[0].toUpperCase()
        : 'U';

    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.85),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 96,
            letterSpacing: -1,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.displayName.trim().isNotEmpty
        ? widget.displayName.trim()
        : 'Profile photo';

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AnimatedOpacity(
          opacity: _showTopBar ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: AppBar(
            backgroundColor: Colors.black.withValues(alpha: 0.7),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            actions: const [], // Clean view-only: no edit or change controls
          ),
        ),
      ),
      body: GestureDetector(
        onTap: _toggleTopBar,
        onDoubleTapDown: _handleDoubleTapDown,
        onDoubleTap: _handleDoubleTap,
        child: Container(
          color: Colors.black,
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: 1.0,
              maxScale: 4.0,
              clipBehavior: Clip.none,
              child: Hero(
                tag: widget.heroTag,
                child: Material(
                  color: Colors.transparent,
                  shape: _hasPhoto ? null : const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: math.min(MediaQuery.of(context).size.width, 600),
                      maxHeight: math.min(MediaQuery.of(context).size.height, 600),
                    ),
                    child: _buildImageContent(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
