import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../presentation/live_room_models.dart';
import '../../../presentation/widgets/gift_flight_bus.dart';
import '../../../presentation/widgets/gift_flight_overlay.dart';
import '../../../presentation/widgets/gift_modules/gift_visual.dart';
import '../../../presentation/widgets/room_theme.dart';

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
  static const int _maxVisibleSlides = 3;
  static const Duration _slideStagger = Duration(milliseconds: 220);

  final Map<String, int> _luckyComboTotals = <String, int>{};
  final Map<String, int> _luckyRewardTotals = <String, int>{};
  final Set<String> _handledFlightIds = <String>{};
  final List<String> _visibleSlideKeys = <String>[];
  final List<String> _pendingSlideKeys = <String>[];
  final Set<String> _knownSlideKeys = <String>{};
  Timer? _dequeueTimer;
  VoidCallback? _flightListener;

  @override
  void initState() {
    super.initState();
    _flightListener = _handleGiftFlight;
    GiftFlightBus.latest.addListener(_flightListener!);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncSlides());
  }

  @override
  void didUpdateWidget(covariant GiftSlideStackModule oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSlides();
  }

  @override
  void dispose() {
    _dequeueTimer?.cancel();
    final listener = _flightListener;
    if (listener != null) {
      GiftFlightBus.latest.removeListener(listener);
    }
    super.dispose();
  }

  void _syncSlides() {
    final currentKeys = widget.slides.map(_slideKey).toSet();
    var changed = false;

    final expiredKeys = _knownSlideKeys
        .where((key) => !currentKeys.contains(key))
        .toList(growable: false);
    for (final key in expiredKeys) {
      _resetComboSession(key);
    }

    _knownSlideKeys.removeWhere((key) => !currentKeys.contains(key));
    final visibleBefore = _visibleSlideKeys.length;
    final pendingBefore = _pendingSlideKeys.length;
    _visibleSlideKeys.removeWhere((key) => !currentKeys.contains(key));
    _pendingSlideKeys.removeWhere((key) => !currentKeys.contains(key));
    changed = visibleBefore != _visibleSlideKeys.length || pendingBefore != _pendingSlideKeys.length || expiredKeys.isNotEmpty;

    for (final slide in widget.slides) {
      final key = _slideKey(slide);
      if (_knownSlideKeys.add(key)) {
        if (_visibleSlideKeys.length < _maxVisibleSlides && _pendingSlideKeys.isEmpty) {
          _visibleSlideKeys.add(key);
        } else if (!_pendingSlideKeys.contains(key)) {
          _pendingSlideKeys.add(key);
        }
        changed = true;
      }
    }

    if (changed && mounted) setState(() {});
    _scheduleDequeue();
  }

  void _resetComboSession(String key) {
    _luckyComboTotals.remove(key);
    _luckyRewardTotals.remove(key);
  }

  void _scheduleDequeue() {
    if (_dequeueTimer?.isActive == true) return;
    if (_pendingSlideKeys.isEmpty || _visibleSlideKeys.length >= _maxVisibleSlides) return;
    _dequeueTimer = Timer(_slideStagger, () {
      if (!mounted) return;
      if (_pendingSlideKeys.isEmpty || _visibleSlideKeys.length >= _maxVisibleSlides) return;
      setState(() => _visibleSlideKeys.add(_pendingSlideKeys.removeAt(0)));
      _scheduleDequeue();
    });
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
    final byKey = <String, GiftSlide>{};
    for (final slide in widget.slides) {
      byKey[_slideKey(slide)] = slide;
    }
    final visibleSlides = _visibleSlideKeys
        .map((key) => byKey[key])
        .whereType<GiftSlide>()
        .take(_maxVisibleSlides)
        .toList(growable: false);
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
              for (var index = 0; index < visibleSlides.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: GiftSlideCardModule(
                    key: ValueKey(_slideKey(visibleSlides[index])),
                    slide: visibleSlides[index],
                    stackIndex: index,
                    displayCombo: math.max(
                      visibleSlides[index].combo,
                      _luckyComboTotals[_slideKey(visibleSlides[index])] ?? visibleSlides[index].combo,
                    ),
                    rewardCoins: _luckyRewardTotals[_slideKey(visibleSlides[index])] ?? _rewardCoinsFromSlide(visibleSlides[index]),
                    onComboTap: () => widget.onComboTap(visibleSlides[index]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class GiftSlideCardModule extends StatefulWidget {
  const GiftSlideCardModule({
    super.key,
    required this.slide,
    required this.onComboTap,
    required this.displayCombo,
    required this.rewardCoins,
    this.stackIndex = 0,
  });

  final GiftSlide slide;
  final VoidCallback onComboTap;
  final int displayCombo;
  final int rewardCoins;
  final int stackIndex;

  @override
  State<GiftSlideCardModule> createState() => _GiftSlideCardModuleState();
}

class _GiftSlideCardModuleState extends State<GiftSlideCardModule> with SingleTickerProviderStateMixin {
  late final AnimationController _enterController;
  late final Animation<double> _enterCurve;

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 360 + (widget.stackIndex * 55)),
    );
    _enterCurve = CurvedAnimation(parent: _enterController, curve: Curves.easeOutCubic);
    _enterController.forward();
  }

  @override
  void dispose() {
    _enterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final accent = _accentForSlide(widget.slide);
    final isLucky = _isLuckySlide(widget.slide);

    return AnimatedBuilder(
      animation: _enterCurve,
      builder: (context, child) {
        final t = _enterCurve.value;
        final dx = (screenWidth * 0.46) * (1 - t);
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(dx, 0),
            child: Transform.scale(
              scale: 0.98 + (0.02 * t),
              alignment: Alignment.centerLeft,
              child: child,
            ),
          ),
        );
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.onComboTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 232,
              height: 50,
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
                            const Color(0xE6161020),
                            const Color(0xF01F172D),
                            Colors.black.withValues(alpha: 0.00),
                          ],
                          stops: const [0, 0.14, 0.82, 1],
                        ),
                        border: Border.all(
                          color: accent.withValues(alpha: isLucky ? 0.44 : 0.18),
                          width: 0.75,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.22),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                          if (isLucky)
                            BoxShadow(
                              color: accent.withValues(alpha: 0.18),
                              blurRadius: 18,
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
                      icon: widget.slide.giftIcon,
                      colors: widget.slide.colors,
                      assetPath: widget.slide.giftAssetPath,
                      assetUrl: widget.slide.giftAssetUrl,
                      size: 46,
                      padding: 2,
                    ),
                  ),
                  Positioned(
                    left: 54,
                    right: 56,
                    top: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.slide.senderName,
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
                                widget.slide.receiverName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.72),
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
                    top: 8,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                      child: Container(
                        key: ValueKey('combo-${_slideKey(widget.slide)}-${widget.displayCombo}'),
                        constraints: const BoxConstraints(minWidth: 43),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: accent.withValues(alpha: isLucky ? 0.22 : 0.14),
                          border: Border.all(color: accent.withValues(alpha: 0.44), width: 0.8),
                        ),
                        child: Text(
                          'x${widget.displayCombo}',
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
                  if (isLucky) Positioned(right: 48, top: -3, child: _LuckyPulse(color: accent)),
                ],
              ),
            ),
            if (isLucky)
              _LuckyRewardTicker(
                rewardCoins: widget.rewardCoins,
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
      duration: const Duration(milliseconds: 170),
      transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
      child: Container(
        key: ValueKey(rewardCoins),
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: const Color(0xFF171020).withValues(alpha: 0.88),
          border: Border.all(color: RoomColors.gold.withValues(alpha: 0.42), width: 0.8),
          boxShadow: [BoxShadow(color: RoomColors.gold.withValues(alpha: 0.16), blurRadius: 12)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.toll_rounded, color: RoomColors.gold, size: 13),
            const SizedBox(width: 4),
            Text(
              '+${_compact(rewardCoins)}',
              style: const TextStyle(
                color: RoomColors.gold,
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
      tween: Tween<double>(begin: 0.74, end: 1.0),
      duration: const Duration(milliseconds: 720),
      curve: Curves.easeInOut,
      builder: (context, value, child) => Opacity(
        opacity: 1 - ((value - 0.74) / 0.26).clamp(0.0, 1.0) * 0.40,
        child: Transform.scale(scale: value, child: child),
      ),
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.55), width: 1.2),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.22), blurRadius: 8)],
        ),
      ),
    );
  }
}

String _slideKey(GiftSlide slide) => slide.id;

String _eventKey(GiftFlightEvent event) {
  return event.id.startsWith('flight-')
      ? event.id.substring('flight-'.length)
      : event.id;
}

int _rewardCoinsFromSlide(GiftSlide slide) {
  final match = RegExp(r'\+(\d+)').firstMatch(slide.giftName.replaceAll(',', ''));
  return int.tryParse(match?.group(1) ?? '') ?? 0;
}
