import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

Widget getWebNetworkImage({
  required String path,
  required BoxFit fit,
  required Widget Function(BuildContext) errorBuilder,
  required BuildContext context,
}) {
  final viewId = 'img_${path.hashCode}';
  ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) {
    final img = html.ImageElement()
      ..src = path
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = fit == BoxFit.contain ? 'contain' : 'cover'
      ..style.border = 'none';
    return img;
  });
  return HtmlElementView(viewType: viewId);
}
