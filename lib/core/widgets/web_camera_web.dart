// ignore_for_file: avoid_web_libraries_in_flutter
/// Web camera preview using dart:html getUserMedia API.
/// This file is only imported on web via conditional import.
library;

import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Controller for managing the web camera lifecycle.
class WebCameraController {
  html.VideoElement? _videoElement;
  html.MediaStream? _stream;
  bool _isInitialized = false;
  final String _viewType;

  bool get isInitialized => _isInitialized;

  WebCameraController() : _viewType = 'webcam-${DateTime.now().millisecondsSinceEpoch}';

  /// Initialize the camera by requesting getUserMedia.
  Future<void> initialize() async {
    _videoElement = html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..setAttribute('playsinline', 'true')
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover'
      ..style.transform = 'scaleX(-1)'; // Mirror for front camera

    try {
      _stream = await html.window.navigator.mediaDevices!.getUserMedia({
        'video': {
          'facingMode': 'user', // Front camera
          'width': {'ideal': 640},
          'height': {'ideal': 480},
        },
        'audio': false,
      });

      _videoElement!.srcObject = _stream;
      await _videoElement!.play();

      // Register the platform view
      // ignore: undefined_prefixed_name
      ui_web.platformViewRegistry.registerViewFactory(
        _viewType,
        (int viewId) => _videoElement!,
      );

      _isInitialized = true;
    } catch (e) {
      debugPrint('Web camera initialization error: $e');
      rethrow;
    }
  }

  /// Capture a frame from the video as JPEG bytes.
  Future<Uint8List> takePicture() async {
    if (!_isInitialized || _videoElement == null) {
      throw Exception('Camera not initialized');
    }

    final canvas = html.CanvasElement(
      width: _videoElement!.videoWidth,
      height: _videoElement!.videoHeight,
    );
    final ctx = canvas.context2D;

    // Mirror the image to match the preview
    ctx.translate(canvas.width!.toDouble(), 0);
    ctx.scale(-1, 1);
    ctx.drawImage(_videoElement!, 0, 0);

    final dataUrl = canvas.toDataUrl('image/jpeg', 0.85);
    final base64 = dataUrl.split(',').last;
    final bytes = Uint8List.fromList(
      html.window.atob(base64).codeUnits,
    );

    return bytes;
  }

  /// Dispose camera resources.
  void dispose() {
    _stream?.getTracks().forEach((track) => track.stop());
    _videoElement?.pause();
    _videoElement?.srcObject = null;
    _videoElement = null;
    _stream = null;
    _isInitialized = false;
  }

  /// The registered platform view type for HtmlElementView.
  String get viewType => _viewType;
}

/// A widget that displays the web camera preview using HtmlElementView.
class WebCameraPreview extends StatelessWidget {
  final WebCameraController controller;

  const WebCameraPreview({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (!controller.isInitialized) {
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

    return HtmlElementView(viewType: controller.viewType);
  }
}
