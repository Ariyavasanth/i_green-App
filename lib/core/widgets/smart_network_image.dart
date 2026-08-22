import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'smart_network_image_stub.dart'
    if (dart.library.html) 'smart_network_image_web.dart';

/// A cross-platform network image widget that uses native HTML <img> tags
/// on Web to bypass XHR CORS restrictions for Firebase Storage URLs.
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

    if (kIsWeb && (path.startsWith('http://') || path.startsWith('https://'))) {
      return getWebNetworkImage(
        path: path,
        fit: fit,
        errorBuilder: errorBuilder,
        context: context,
      );
    }

    return Image.network(
      path,
      fit: fit,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => errorBuilder(context),
    );
  }
}

