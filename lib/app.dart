import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class BooksApp extends ConsumerWidget {
  const BooksApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'Books',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    builder: (context, child) {
      final media = MediaQuery.of(context);
      // Scale typography gently by viewport width while respecting accessibility.
      final deviceScale = (media.size.width / 390).clamp(.92, 1.16);
      return MediaQuery(
        data: media.copyWith(
          textScaler: TextScaler.linear(
            media.textScaler.scale(1) * deviceScale,
          ),
        ),
        child: child!,
      );
    },
    routerConfig: ref.watch(appRouterProvider),
  );
}
