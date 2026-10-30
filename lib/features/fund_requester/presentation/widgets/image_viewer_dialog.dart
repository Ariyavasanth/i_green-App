import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/theme/app_colors.dart';

class BillImageItem {
  final String title;
  final String? url;
  final Uint8List? bytes;

  const BillImageItem({
    required this.title,
    this.url,
    this.bytes,
  });
}

class ImageViewerDialog extends StatefulWidget {
  final List<BillImageItem> images;
  final int initialIndex;
  final Function(int)? onDelete;

  const ImageViewerDialog({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.onDelete,
  });

  static Future<void> show({
    required BuildContext context,
    required List<BillImageItem> images,
    int initialIndex = 0,
    Function(int)? onDelete,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (ctx) => ImageViewerDialog(
        images: images,
        initialIndex: initialIndex,
        onDelete: onDelete,
      ),
    );
  }

  @override
  State<ImageViewerDialog> createState() => _ImageViewerDialogState();
}

class _ImageViewerDialogState extends State<ImageViewerDialog> {
  late int _currentIndex;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.images.isEmpty ? 0 : widget.images.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildImageWidget(BillImageItem item) {
    if (item.bytes != null) {
      return Image.memory(
        item.bytes!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildPlaceholder(item.title),
      );
    }
    if (item.url != null && item.url!.isNotEmpty && item.url!.startsWith('http')) {
      return Image.network(
        item.url!,
        fit: BoxFit.contain,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        },
        errorBuilder: (_, __, ___) => _buildPlaceholder(item.title),
      );
    }
    return _buildPlaceholder(item.title);
  }

  Widget _buildPlaceholder(String title) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_rounded, size: 64, color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Attached Document Receipt',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentImage = widget.images[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Interactive zoomable image carousel
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (idx) {
              setState(() => _currentIndex = idx);
            },
            itemBuilder: (ctx, idx) {
              final img = widget.images[idx];
              return InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 80, 16, 70),
                    child: _buildImageWidget(img),
                  ),
                ),
              );
            },
          ),

          // Top Header Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.black.withValues(alpha: 0.5),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close Viewer',
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            currentImage.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.images.length > 1)
                            Text(
                              '${_currentIndex + 1} of ${widget.images.length}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    if (widget.onDelete != null)
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFF87171), size: 24),
                        tooltip: 'Remove Attachment',
                        onPressed: () {
                          widget.onDelete!(_currentIndex);
                          Navigator.of(context).pop();
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Left Arrow Navigation (if multiple)
          if (widget.images.length > 1 && _currentIndex > 0)
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: Material(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 36),
                    onPressed: () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                ),
              ),
            ),

          // Right Arrow Navigation (if multiple)
          if (widget.images.length > 1 && _currentIndex < widget.images.length - 1)
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: Material(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 36),
                    onPressed: () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

