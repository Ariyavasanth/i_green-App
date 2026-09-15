import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_background_provider.dart';

/// Wraps page body in custom wallpaper/photo background if configured by the user
class AppBackgroundWrapper extends ConsumerWidget {
  const AppBackgroundWrapper({
    required this.child,
    this.defaultBackgroundColor = const Color(0xFFF4F6F3),
    super.key,
  });

  final Widget child;
  final Color defaultBackgroundColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bgState = ref.watch(appBackgroundProvider);

    if (!bgState.hasBackground) {
      return Container(
        color: defaultBackgroundColor,
        child: child,
      );
    }

    Widget imageWidget;

    if (bgState.isBase64) {
      try {
        final cleanBase64 = bgState.imagePath!.contains(',')
            ? bgState.imagePath!.split(',').last
            : bgState.imagePath!;
        final bytes = base64Decode(cleanBase64.trim());
        imageWidget = Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (ctx, err, stack) => Container(color: defaultBackgroundColor),
        );
      } catch (e) {
        imageWidget = Container(color: defaultBackgroundColor);
      }
    } else if (bgState.isUrl) {
      imageWidget = Image.network(
        bgState.imagePath!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (ctx, err, stack) => Container(color: defaultBackgroundColor),
      );
    } else {
      imageWidget = Container(color: defaultBackgroundColor);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background photo
        imageWidget,

        // Translucent overlay for readability
        Container(
          color: Colors.black.withValues(alpha: bgState.opacity),
        ),

        // Screen content
        child,
      ],
    );
  }
}
