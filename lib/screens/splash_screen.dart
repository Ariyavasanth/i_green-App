import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/authentication/providers/authentication_providers.dart';
import 'splash_logo_data.dart';

class SplashScreen extends ConsumerStatefulWidget {
  /// The screen to navigate to after the animation finishes (e.g., HomeScreen or LoginScreen).
  final Widget? nextScreen;

  /// Optional custom callback when animation completes.
  final VoidCallback? onFinish;

  const SplashScreen({
    super.key,
    this.nextScreen,
    this.onFinish,
  });

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const double feather = 0.14;

  late AnimationController controller;

  late Animation<double> reveal;
  late Animation<double> fadeIn;
  late Animation<double> scalePop;
  late Animation<double> slideIn;
  late Animation<double> wheelRotation;
  late Animation<double> wheelOpacity;

  // Exact logo dimensions
  static const double logoWidth = 360.0;
  static const double logoHeight = logoWidth * 890.0 / 1767.0;

  // Exact wheel placement
  static const double wheelLeft = logoWidth * 254.0 / 1767.0;
  static const double wheelTop = logoHeight * 488.0 / 890.0;
  static const double wheelSize = logoWidth * 333.0 / 1767.0;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    // Left -> right reveal
    reveal = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.00, 0.78, curve: Curves.easeInOutCubic),
    );

    // Fade-in
    fadeIn = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.00, 0.18, curve: Curves.easeOut),
    );

    // Scale pop
    scalePop = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.94, end: 1.03).chain(
          CurveTween(curve: Curves.easeOutCubic),
        ),
        weight: 78,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.03, end: 1.0).chain(
          CurveTween(curve: Curves.easeOutBack),
        ),
        weight: 22,
      ),
    ]).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.00, 0.92),
      ),
    );

    // Slight left-to-center slide
    slideIn = Tween<double>(
      begin: -16.0,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.00, 0.62, curve: Curves.easeOutCubic),
      ),
    );

    // Wheel rotation
    wheelRotation = Tween<double>(
      begin: 0.0,
      end: math.pi * 2,
    ).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.10, 0.58, curve: Curves.easeOutCubic),
      ),
    );

    // Wheel fade-in
    wheelOpacity = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.10, 0.18, curve: Curves.easeOut),
    );

    // Auto-navigate to next screen when animation finishes
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _navigateNext();
      }
    });

    controller.forward();
  }

  void _navigateNext() {
    if (!mounted) return;

    if (widget.onFinish != null) {
      widget.onFinish!();
      return;
    }

    if (widget.nextScreen != null) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => widget.nextScreen!,
          transitionsBuilder: (_, animation, _, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
      return;
    }

    // Default GoRouter flow based on auth state
    final email = ref.read(currentUserEmailProvider);
    if (email != null && email.trim().isNotEmpty) {
      context.go('/module-dashboard');
    } else {
      context.go('/login');
    }
  }

  Widget featheredReveal(Widget child, double progress) {
    if (progress >= 1.0) return child;

    final t = progress.clamp(0.0, 1.0);
    final stop2 = (t + feather).clamp(0.0, 1.0);

    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [0.0, t, stop2],
        ).createShader(bounds);
      },
      child: child,
    );
  }

  Widget buildStaticLogo() {
    return Image.memory(
      kSplashLogoBaseBytes,
      width: logoWidth,
      height: logoHeight,
      fit: BoxFit.fill,
      errorBuilder: (_, _, _) => Image.asset(
        'assets/reference_logo_base.png',
        width: logoWidth,
        height: logoHeight,
        fit: BoxFit.fill,
      ),
    );
  }

  Widget buildRotatingWheel() {
    return Positioned(
      left: wheelLeft,
      top: wheelTop,
      width: wheelSize,
      height: wheelSize,
      child: Opacity(
        opacity: wheelOpacity.value.clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: wheelRotation.value,
          alignment: Alignment.center,
          child: Image.memory(
            kSplashWheelBytes,
            width: wheelSize,
            height: wheelSize,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Image.asset(
              'assets/inner_wheel_rotating.png',
              width: wheelSize,
              height: wheelSize,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildLogo() {
    return Opacity(
      opacity: fadeIn.value.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(slideIn.value, 0),
        child: Transform.scale(
          scale: scalePop.value,
          child: featheredReveal(
            Stack(
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  width: logoWidth,
                  height: logoHeight,
                  child: buildStaticLogo(),
                ),
                buildRotatingWheel(),
              ],
            ),
            reveal.value,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (controller.isAnimating) {
              controller.stop();
              _navigateNext();
            }
          },
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              return buildLogo();
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
