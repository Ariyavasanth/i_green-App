import 'package:flutter/material.dart';

Widget getWebNetworkImage({
  required String path,
  required BoxFit fit,
  required Widget Function(BuildContext) errorBuilder,
  required BuildContext context,
}) {
  return Image.network(
    path,
    fit: fit,
    filterQuality: FilterQuality.high,
    errorBuilder: (_, __, ___) => errorBuilder(context),
  );
}
