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
    // If opening directly via a specific route/deep link URL on web, skip the
    // non-router splash screen so GoRouter directly mounts and preserves the target URL.
    try {
      final uri = Uri.base;
      final full = uri.toString();
      final fragment = uri.fragment.trim();
      final path = uri.path.trim();

      final hasDirectRoute = full.contains('/employee/register') ||
          (fragment.isNotEmpty && fragment != '/' && !fragment.startsWith('/?')) ||
          (path.isNotEmpty && path != '/' && !path.startsWith('/?'));

      if (hasDirectRoute) {
        _splashCompleted = true;
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashCompleted) {
      return MaterialApp(
        title: 'Igreen',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        onGenerateRoute: (settings) => MaterialPageRoute(
          settings: settings,
          builder: (_) => SplashScreen(
            onFinish: () {
              if (mounted) {
                setState(() {
                  _splashCompleted = true;
                });
              }
            },
          ),
        ),
      );
    }

    return MaterialApp.router(
      title: 'Igreen',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
