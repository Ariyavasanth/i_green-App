import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'smart_network_image_stub.dart'
    if (dart.library.html) 'smart_network_image_web.dart';

/// A cross-platform image widget that handles network URLs (HTTP/HTTPS),
/// Data URLs (base64), Blob URLs, and local file paths (mobile/desktop).
class SmartNetworkImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final Widget Function(BuildContext) errorBuilder;

  const SmartNetworkImage({
    required this.url,
    required this.errorBuilder,
    this.fit = BoxFit.contain,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final path = url.trim();
    if (path.isEmpty) return errorBuilder(context);

    if (path.startsWith('data:')) {
      try {
        final data = Uri.parse(path).data;
        if (data != null) {
          return Image.memory(
            data.contentAsBytes(),
            fit: fit,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => errorBuilder(context),
          );
        }
      } catch (_) {}
    }

    if (kIsWeb && (path.startsWith('http://') || path.startsWith('https://') || path.startsWith('blob:'))) {
      return getWebNetworkImage(
        path: path,
        fit: fit,
        errorBuilder: errorBuilder,
        context: context,
      );
    }

    if (path.startsWith('http://') || path.startsWith('https://') || path.startsWith('blob:')) {
      return Image.network(
        path,
        fit: fit,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => errorBuilder(context),
      );
    }

    if (!kIsWeb) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: fit,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => errorBuilder(context),
          );
        }
      } catch (_) {}
    }

    return errorBuilder(context);
  }
}


