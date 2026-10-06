import 'package:flutter/material.dart';

class VmMotion {
  const VmMotion._();

  static const Duration tabDuration = Duration(milliseconds: 210);
  static const Duration pageDuration = Duration(milliseconds: 260);
  static const Duration pageReverseDuration = Duration(milliseconds: 220);
  static const Duration sheetDuration = Duration(milliseconds: 220);
  static const Duration sheetReverseDuration = Duration(milliseconds: 180);
  static const Duration sheetContentDuration = Duration(milliseconds: 190);
  static const Duration actionDuration = Duration(milliseconds: 150);

  static const Curve enterCurve = Cubic(0.16, 1, 0.30, 1);
  static const Curve exitCurve = Cubic(0.40, 0, 0.20, 1);
  static const Curve standardCurve = Curves.easeInOutCubic;

  static const AnimationStyle sheetAnimationStyle = AnimationStyle(
    duration: sheetDuration,
    reverseDuration: sheetReverseDuration,
  );

  static PageRouteBuilder<T> pageRoute<T>({
    required RouteSettings settings,
    required Widget page,
    Offset beginOffset = const Offset(0.035, 0.006),
    bool opaque = true,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      opaque: opaque,
      transitionDuration: pageDuration,
      reverseTransitionDuration: pageReverseDuration,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return buildPageTransition(
          context: context,
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          child: child,
          beginOffset: beginOffset,
        );
      },
    );
  }

  static Widget buildPageTransition({
    required BuildContext context,
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    required Widget child,
    Offset beginOffset = const Offset(0.035, 0.006),
  }) {
    final media = MediaQuery.maybeOf(context);
    if (media?.disableAnimations == true) {
      return FadeTransition(opacity: animation, child: child);
    }

    final primary = CurvedAnimation(
      parent: animation,
      curve: enterCurve,
      reverseCurve: exitCurve,
    );
    final covered = CurvedAnimation(
      parent: secondaryAnimation,
      curve: enterCurve,
      reverseCurve: exitCurve,
    );

    final incomingOpacity = Tween<double>(
      begin: 0.86,
      end: 1,
    ).animate(primary);
    final incomingSlide = Tween<Offset>(
      begin: beginOffset,
      end: Offset.zero,
    ).animate(primary);
    final incomingScale = Tween<double>(
      begin: 0.992,
      end: 1,
    ).animate(primary);

    final coveredSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.012, 0),
    ).animate(covered);
    final coveredScale = Tween<double>(
      begin: 1,
      end: 0.996,
    ).animate(covered);

    return SlideTransition(
      position: coveredSlide,
      child: ScaleTransition(
        scale: coveredScale,
        child: FadeTransition(
          opacity: incomingOpacity,
          child: SlideTransition(
            position: incomingSlide,
            child: ScaleTransition(
              scale: incomingScale,
              alignment: Alignment.center,
              child: child,
            ),
          ),
        ),
      ),
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
      opacity: Tween<double>(begin: 0.90, end: 1).animate(curved),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0.018 * direction, 0.004),
          end: Offset.zero,
        ).animate(curved),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.996, end: 1).animate(curved),
          child: child,
        ),
      ),
    );
  }
}

/// Applies the same FunKey route choreography to every MaterialPageRoute,
/// including legacy direct pushes that have not yet migrated to named routes.
class FunKeyPageTransitionsBuilder extends PageTransitionsBuilder {
  const FunKeyPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return VmMotion.buildPageTransition(
      context: context,
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
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
    if (MediaQuery.maybeOf(context)?.disableAnimations == true) {
      return child;
    }

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
