/// Stub implementation of WebCameraController/WebCameraPreview for non-web platforms.
/// These classes are no-ops on mobile — the calling code should use the `camera` package.
library;

import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Stub controller that does nothing on non-web platforms.
class WebCameraController {
  bool get isInitialized => false;

  Future<void> initialize() async {
    // No-op on non-web platforms
  }

  Future<Uint8List> takePicture() async {
    throw UnsupportedError('WebCameraController.takePicture is not available on this platform.');
  }

  void dispose() {
    // No-op
  }

  String get viewType => '';
}

/// Stub widget for non-web platforms — shows a placeholder.
class WebCameraPreview extends StatelessWidget {
  final WebCameraController controller;

  const WebCameraPreview({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person, size: 80, color: Colors.white54),
          SizedBox(height: 8),
          Text('Camera Feed Ready', style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}
