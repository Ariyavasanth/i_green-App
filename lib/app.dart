import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'screens/splash_screen.dart';

class BooksApp extends ConsumerStatefulWidget {
  const BooksApp({super.key});

  @override
  ConsumerState<BooksApp> createState() => _BooksAppState();
}

class _BooksAppState extends ConsumerState<BooksApp> {
  bool _splashCompleted = false;

  @override
  void initState() {
    super.initState();
    // If opening directly via a public registration link, skip the non-router splash screen
    // so GoRouter directly mounts and preserves the registration form URL.
    try {
      final uri = Uri.base;
      final full = uri.toString();
      if (full.contains('/employee/register')) {
        _splashCompleted = true;
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashCompleted) {
      return MaterialApp(
        title: 'Books',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: SplashScreen(
          onFinish: () {
            if (mounted) {
              setState(() {
                _splashCompleted = true;
              });
            }
          },
        ),
      );
    }

    return MaterialApp.router(
      title: 'Books',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
