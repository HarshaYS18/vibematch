import 'package:flutter/material.dart';

class VmMotion {
  const VmMotion._();

  static const Duration tabDuration = Duration(milliseconds: 230);
  static const Duration pageDuration = Duration(milliseconds: 240);
  static const Duration pageReverseDuration = Duration(milliseconds: 190);
  static const Duration sheetDuration = Duration(milliseconds: 220);
  static const Duration sheetReverseDuration = Duration(milliseconds: 180);
  static const Duration sheetContentDuration = Duration(milliseconds: 190);
  static const Duration actionDuration = Duration(milliseconds: 150);

  static const Curve enterCurve = Curves.easeOutCubic;
  static const Curve exitCurve = Curves.easeInCubic;
  static const Curve standardCurve = Curves.easeInOutCubic;

  static const AnimationStyle sheetAnimationStyle = AnimationStyle(
    duration: sheetDuration,
    reverseDuration: sheetReverseDuration,
  );

  static PageRouteBuilder<T> pageRoute<T>({
    required RouteSettings settings,
    required Widget page,
    Offset beginOffset = const Offset(0.045, 0.012),
    bool opaque = true,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      opaque: opaque,
      transitionDuration: pageDuration,
      reverseTransitionDuration: pageReverseDuration,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: enterCurve,
          reverseCurve: exitCurve,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: beginOffset,
              end: Offset.zero,
            ).animate(curved),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.988, end: 1).animate(curved),
              child: child,
            ),
          ),
        );
      },
    );
  }

  static Widget tabTransition({
    required Widget child,
    required Animation<double> animation,
    required double direction,
  }) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: enterCurve,
      reverseCurve: exitCurve,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0.024 * direction, 0.006),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

class VmFadeSlide extends StatelessWidget {
  const VmFadeSlide({
    super.key,
    required this.child,
    this.beginOffset = const Offset(0, 0.035),
    this.beginScale = 0.985,
    this.duration = VmMotion.sheetContentDuration,
    this.curve = VmMotion.enterCurve,
    this.alignment = Alignment.bottomCenter,
  });

  final Widget child;
  final Offset beginOffset;
  final double beginScale;
  final Duration duration;
  final Curve curve;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: curve,
      child: child,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: FractionalTranslation(
            translation: beginOffset * (1 - value),
            child: Transform.scale(
              alignment: alignment,
              scale: beginScale + ((1 - beginScale) * value),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
