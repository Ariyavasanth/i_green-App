import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/authentication/providers/authentication_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final email = ref.read(currentUserEmailProvider);
      if (email != null && email.trim().isNotEmpty) {
        context.go('/module-dashboard');
      } else {
        context.go('/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Image.asset(
            'assets/green_logo_static.png',
            width: 360.0,
            fit: BoxFit.contain,
          ),
        ),
      );
}
