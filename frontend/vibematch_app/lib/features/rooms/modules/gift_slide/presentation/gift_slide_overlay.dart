import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../presentation/live_room_models.dart';
import '../../../presentation/widgets/gift_flight_bus.dart';
import '../../../presentation/widgets/gift_flight_overlay.dart';
import '../../../presentation/widgets/gift_modules/gift_visual.dart';

class GiftSlideOverlay extends StatelessWidget {
  const GiftSlideOverlay({
    super.key,
    required this.slides,
    required this.onComboTap,
    this.topFactor = 0.39,
  });

  final List<GiftSlide> slides;
  final ValueChanged<GiftSlide> onComboTap;
  final double topFactor;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Positioned(
      left: 0,
      right: 0,
      top: size.height * topFactor,
      child: GiftSlideStackModule(slides: slides, onComboTap: onComboTap),
    );
  }
}

class GiftSlideStackModule extends StatefulWidget {
  const GiftSlideStackModule({super.key, required this.slides, required this.onComboTap});

  final List<GiftSlide> slides;
  final ValueChanged<GiftSlide> onComboTap;

  @override
  State<GiftSlideStackModule> createState() => _GiftSlideStackModuleState();
}

class _GiftSlideStackModuleState extends State<GiftSlideStackModule> {
  final Map<String, int> _luckyComboTotals = <String, int>{};
  final Map<String, int> _luckyRewardTotals = <String, int>{};
  final Set<String> _handledFlightIds = <String>{};
  VoidCallback? _flightListener;

  @override
  void initState() {
    super.initState();
    _flightListener = _handleGiftFlight;
    GiftFlightBus.latest.addListener(_flightListener!);
  }

  @override
  void dispose() {
    final listener = _flightListener;
    if (listener != null) {
      GiftFlightBus.latest.removeListener(listener);
    }
    super.dispose();
  }

  void _handleGiftFlight() {
    final event = GiftFlightBus.latest.value;
    if (event == null) return;
    if (!_handledFlightIds.add(event.id)) return;
    if (event.multiplier == null) return;

    final key = _eventKey(event);
    _luckyComboTotals[key] = (_luckyComboTotals[key] ?? 0) + math.max(1, event.combo);
    _luckyRewardTotals[key] = (_luckyRewardTotals[key] ?? 0) + math.max(0, event.rewardCoinAmount ?? 0);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final visibleSlides = widget.slides.where((slide) {
      final ageSeconds = (15 - slide.remainingSeconds).clamp(0, 15);
      return ageSeconds <= 5;
    }).take(1).toList(growable: false);
    if (visibleSlides.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      ignoring: false,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final slide in visibleSlides)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: GiftSlideCardModule(
                    key: ValueKey(slide.id),
                    slide: slide,
                    displayCombo: math.max(slide.combo, _luckyComboTotals[_slideKey(slide)] ?? slide.combo),
                    rewardCoins: _luckyRewardTotals[_slideKey(slide)] ?? _rewardCoinsFromSlide(slide),
                    onComboTap: () => widget.onComboTap(slide),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class GiftSlideCardModule extends StatelessWidget {
  const GiftSlideCardModule({
    super.key,
    required this.slide,
    required this.onComboTap,
    required this.displayCombo,
    required this.rewardCoins,
  });

  final GiftSlide slide;
  final VoidCallback onComboTap;
  final int displayCombo;
  final int rewardCoins;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final ageSeconds = (15 - slide.remainingSeconds).clamp(0, 15).toDouble();
    const holdSeconds = 3.6;
    final exitProgress = ageSeconds <= holdSeconds
        ? 0.0
        : ((ageSeconds - holdSeconds) / 1.10).clamp(0.0, 1.0).toDouble();
    final accent = _accentForSlide(slide);
    final isLucky = _isLuckySlide(slide);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0 + exitProgress),
      duration: const Duration(milliseconds: 560),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final enter = value.clamp(0.0, 1.0).toDouble();
        final exit = (value - 1.0).clamp(0.0, 1.0).toDouble();
        final enterCurve = Curves.easeOutCubic.transform(enter);
        final exitCurve = Curves.easeInCubic.transform(exit);
        final opacity = exit > 0 ? 1 - exitCurve : enterCurve;
        final startDx = (size.width * 0.50) - 10;
        final dx = exit > 0 ? -235 * exitCurve : startDx * (1 - enterCurve);
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(dx, 0),
            child: Transform.scale(scale: 0.985 + (0.015 * enterCurve), child: child),
          ),
        );
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onComboTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 236,
              height: 52,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    left: 18,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.00),
                            const Color(0xEE171020),
                            const Color(0xF0221730),
                            Colors.black.withValues(alpha: 0.00),
                          ],
                          stops: const [0, 0.14, 0.82, 1],
                        ),
                        border: Border.all(
                          color: accent.withValues(alpha: isLucky ? 0.42 : 0.20),
                          width: 0.75,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.26),
                            blurRadius: 16,
                            offset: const Offset(0, 7),
                          ),
                          if (isLucky)
                            BoxShadow(
                              color: accent.withValues(alpha: 0.20),
                              blurRadius: 22,
                              offset: const Offset(0, 3),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 2,
                    child: GiftVisual(
                      icon: slide.giftIcon,
                      colors: slide.colors,
                      assetPath: slide.giftAssetPath,
                      assetUrl: slide.giftAssetUrl,
                      size: 48,
                      padding: 2,
                    ),
                  ),
                  Positioned(
                    left: 55,
                    right: 58,
                    top: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          slide.senderName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(Icons.arrow_forward_rounded, color: accent, size: 12),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                slide.receiverName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.74),
                                  fontSize: 10,
                                  height: 1,
                                  fontWeight: FontWeight.w800,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 9,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 170),
                      transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                      child: Container(
                        key: ValueKey('combo-${slide.id}-$displayCombo'),
                        constraints: const BoxConstraints(minWidth: 44),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: accent.withValues(alpha: isLucky ? 0.22 : 0.15),
                          border: Border.all(color: accent.withValues(alpha: 0.48), width: 0.8),
                        ),
                        child: Text(
                          'x$displayCombo',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            height: 1,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (isLucky) Positioned(right: 49, top: -3, child: _LuckyPulse(color: accent)),
                ],
              ),
            ),
            if (isLucky)
              _LuckyRewardTicker(
                rewardCoins: rewardCoins,
                accent: accent,
              ),
          ],
        ),
      ),
    );
  }

  bool _isLuckySlide(GiftSlide slide) {
    final text = '${slide.giftName} ${slide.giftName.toLowerCase()}';
    return text.contains('lucky') ||
        text.contains('packet') ||
        text.contains('spin') ||
        RegExp(r'x(0|1|2|5|10|20|50|100|500|1000)').hasMatch(text.toLowerCase());
  }

  Color _accentForSlide(GiftSlide slide) {
    final name = slide.giftName.toLowerCase();
    if (name.contains('x1000')) return const Color(0xFF22D3EE);
    if (name.contains('x500')) return const Color(0xFFFF2D95);
    if (name.contains('x100')) return const Color(0xFFFFD166);
    if (name.contains('x0') || name.contains('try again')) return const Color(0xFFB9ADC8);
    if (name.contains('lucky') || name.contains('packet') || name.contains('spin')) {
      return const Color(0xFFFFB545);
    }
    return Colors.white;
  }
}

class _LuckyRewardTicker extends StatelessWidget {
  const _LuckyRewardTicker({required this.rewardCoins, required this.accent});

  final int rewardCoins;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 210),
      transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
      child: Container(
        key: ValueKey(rewardCoins),
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: const Color(0xFF171020).withValues(alpha: 0.88),
          border: Border.all(color: accent.withValues(alpha: 0.42), width: 0.8),
          boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.20), blurRadius: 14)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.toll_rounded, color: accent, size: 13),
            const SizedBox(width: 4),
            Text(
              '+${_compact(rewardCoins)}',
              style: TextStyle(
                color: accent,
                fontSize: 11,
                height: 1,
                fontWeight: FontWeight.w900,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _compact(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
    return '$value';
  }
}

class _LuckyPulse extends StatelessWidget {
  const _LuckyPulse({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.72, end: 1.0),
      duration: const Duration(milliseconds: 620),
      curve: Curves.easeInOut,
      builder: (context, value, child) => Opacity(
        opacity: 1 - ((value - 0.72) / 0.28).clamp(0.0, 1.0) * 0.45,
        child: Transform.scale(scale: value, child: child),
      ),
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.55), width: 1.2),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 9)],
        ),
      ),
    );
  }
}

String _slideKey(GiftSlide slide) {
  return '${slide.senderName.trim().toLowerCase()}|${slide.receiverName.trim().toLowerCase()}|${_baseGiftName(slide.giftName)}';
}

String _eventKey(GiftFlightEvent event) {
  return '${event.senderName.trim().toLowerCase()}|${event.receiverName.trim().toLowerCase()}|${event.gift.name.trim().toLowerCase()}';
}

String _baseGiftName(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+x\d+'), '')
      .replaceAll(RegExp(r'\s+\+\d+'), '')
      .trim();
}

int _rewardCoinsFromSlide(GiftSlide slide) {
  final match = RegExp(r'\+(\d+)').firstMatch(slide.giftName.replaceAll(',', ''));
  return int.tryParse(match?.group(1) ?? '') ?? 0;
}