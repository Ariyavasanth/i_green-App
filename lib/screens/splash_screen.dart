import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../features/authentication/providers/authentication_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const double _feather = 0.14;

  late AnimationController _controller;
  late Animation<double> _reveal;
  late Animation<double> _fadeIn;
  late Animation<double> _scalePop;
  late Animation<double> _slideIn;
  late Animation<double> _wheelRotation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _reveal = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.00, 0.78, curve: Curves.easeInOutCubic),
    );

    _fadeIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.00, 0.18, curve: Curves.easeOut),
    );

    _scalePop = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.94, end: 1.03)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 78,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.03, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 22,
      ),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.00, 0.92),
    ));

    _slideIn = Tween<double>(begin: -16.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.00, 0.62, curve: Curves.easeOutCubic),
      ),
    );

    _wheelRotation = Tween<double>(begin: 0.0, end: math.pi * 2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.10, 0.58, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          final email = ref.read(currentUserEmailProvider);
          if (email != null && email.trim().isNotEmpty) {
            context.go('/module-dashboard');
          } else {
            context.go('/login');
          }
        });
      }
    });
  }

  Widget _featheredReveal(Widget child, double progress) {
    final t = progress.clamp(0.0, 1.0);
    final stop2 = (t + _feather).clamp(0.0, 1.0);
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: const [Colors.white, Colors.white, Colors.transparent],
        stops: [0.0, t, stop2],
      ).createShader(bounds),
      child: child,
    );
  }

  static const double _logoWidth = 360.0;
  static const double _logoHeight = _logoWidth * 1468.0 / 2912.0;
  static const double _wheelLeft = _logoWidth * 570.1766 / 2912.0;
  static const double _wheelTop = _logoHeight * 881.2847 / 1468.0;
  static const double _wheelSize = _logoWidth * 575.2028 / 2912.0;

  Widget _buildStaticLogo() => Image.asset(
        'assets/green_logo_static.png',
        width: _logoWidth,
        height: _logoHeight,
        fit: BoxFit.fill,
      );

  Widget _buildRotatingWheel() => Positioned(
        left: _wheelLeft,
        top: _wheelTop,
        width: _wheelSize,
        height: _wheelSize,
        child: Transform.rotate(
          angle: _wheelRotation.value,
          alignment: Alignment.center,
          child: SvgPicture.asset(
            'assets/logo_wheel.svg',
            width: _wheelSize,
            height: _wheelSize,
            fit: BoxFit.contain,
          ),
        ),
      );

  Widget _buildLogo() => Opacity(
        opacity: _fadeIn.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(_slideIn.value, 0),
          child: Transform.scale(
            scale: _scalePop.value,
            child: _featheredReveal(
              Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    width: _logoWidth,
                    height: _logoHeight,
                    child: _buildStaticLogo(),
                  ),
                  _buildRotatingWheel(),
                ],
              ),
              _reveal.value,
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => _buildLogo(),
          ),
        ),
      );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
