import 'dart:async';

import 'package:flutter/material.dart';

import '../../../presentation/live_room_models.dart';
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
  const GiftSlideStackModule({
    super.key,
    required this.slides,
    required this.onComboTap,
  });

  final List<GiftSlide> slides;
  final ValueChanged<GiftSlide> onComboTap;

  @override
  State<GiftSlideStackModule> createState() => _GiftSlideStackModuleState();
}

class _GiftSlideStackModuleState extends State<GiftSlideStackModule> {
  static const int _maxVisibleSlides = 3;
  static const Duration _slideStagger = Duration(milliseconds: 220);

  final List<String> _visibleSlideKeys = <String>[];
  final List<String> _pendingSlideKeys = <String>[];
  final Set<String> _knownSlideKeys = <String>{};
  Timer? _dequeueTimer;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  void _syncSlides() {
    final currentKeys = widget.slides.map(_slideKey).toSet();
    var changed = false;

    _knownSlideKeys.removeWhere((key) => !currentKeys.contains(key));
    final visibleBefore = _visibleSlideKeys.length;
    final pendingBefore = _pendingSlideKeys.length;
    _visibleSlideKeys.removeWhere((key) => !currentKeys.contains(key));
    _pendingSlideKeys.removeWhere((key) => !currentKeys.contains(key));
    changed =
        visibleBefore != _visibleSlideKeys.length ||
        pendingBefore != _pendingSlideKeys.length;

    for (final slide in widget.slides) {
      final key = _slideKey(slide);
      if (_knownSlideKeys.add(key)) {
        if (_visibleSlideKeys.length < _maxVisibleSlides &&
            _pendingSlideKeys.isEmpty) {
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

  void _scheduleDequeue() {
    if (_dequeueTimer?.isActive == true) return;
    if (_pendingSlideKeys.isEmpty ||
        _visibleSlideKeys.length >= _maxVisibleSlides) {
      return;
    }
    _dequeueTimer = Timer(_slideStagger, () {
      if (!mounted) return;
      if (_pendingSlideKeys.isEmpty ||
          _visibleSlideKeys.length >= _maxVisibleSlides) {
        return;
      }
      setState(() => _visibleSlideKeys.add(_pendingSlideKeys.removeAt(0)));
      _scheduleDequeue();
    });
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
    this.stackIndex = 0,
  });

  final GiftSlide slide;
  final VoidCallback onComboTap;
  final int stackIndex;

  @override
  State<GiftSlideCardModule> createState() => _GiftSlideCardModuleState();
}

class _GiftSlideCardModuleState extends State<GiftSlideCardModule>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enterController;
  late final Animation<double> _enterCurve;

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 360 + (widget.stackIndex * 55)),
    );
    _enterCurve = CurvedAnimation(
      parent: _enterController,
      curve: Curves.easeOutCubic,
    );
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
    final multiplier = _luckyMultiplier(widget.slide);
    final isLucky = _isLuckySlide(widget.slide);
    final accent = _accentForMultiplier(multiplier, isLucky: isLucky);
    final giftName = _baseGiftName(widget.slide.giftName);

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
              width: 246,
              height: 54,
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
                    top: 4,
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
                    right: 76,
                    top: 7,
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
                        const SizedBox(height: 4),
                        Text(
                          '$giftName → ${widget.slide.receiverName}',
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
                      ],
                    ),
                  ),
                  Positioned(
                    right: 7,
                    top: 7,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 62),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: accent.withValues(alpha: isLucky ? 0.22 : 0.14),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.44),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        'Combo x${widget.slide.combo}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: accent,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                  if (isLucky && multiplier != null)
                    Positioned(
                      right: 8,
                      bottom: -4,
                      child: _LuckyOutcomeBadge(
                        multiplier: multiplier,
                        accent: accent,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LuckyOutcomeBadge extends StatelessWidget {
  const _LuckyOutcomeBadge({
    required this.multiplier,
    required this.accent,
  });

  final int multiplier;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final label = multiplier <= 0 ? 'TRY AGAIN' : 'WIN x$multiplier';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: const Color(0xFF171020).withValues(alpha: 0.94),
        border: Border.all(color: accent.withValues(alpha: 0.50), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          height: 1,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

String _slideKey(GiftSlide slide) => slide.id;

String _baseGiftName(String raw) {
  return raw.replaceAll(RegExp(r'\s+x\d+\s*$'), '').trim();
}

int? _luckyMultiplier(GiftSlide slide) {
  final match = RegExp(r'\s+x(\d+)\s*$').firstMatch(slide.giftName.trim());
  if (match == null) return null;
  return int.tryParse(match.group(1) ?? '');
}

bool _isLuckySlide(GiftSlide slide) {
  final name = slide.giftName.toLowerCase();
  final base = _baseGiftName(name);
  if (base.contains('lucky') ||
      base.contains('spin') ||
      base.contains('hunt') ||
      base.contains('fortune') ||
      base.contains('jackpot')) {
    return true;
  }
  final multiplier = _luckyMultiplier(slide);
  return multiplier != null &&
      <int>{0, 5, 10, 20, 50, 100, 500, 1000}.contains(multiplier);
}

Color _accentForMultiplier(int? multiplier, {required bool isLucky}) {
  final value = multiplier ?? 0;
  if (value >= 1000) return const Color(0xFF22D3EE);
  if (value >= 500) return const Color(0xFFFF2D95);
  if (value >= 100) return const Color(0xFFFFD166);
  if (isLucky && value <= 0) return const Color(0xFFB9ADC8);
  if (isLucky) return const Color(0xFFFFB545);
  return Colors.white;
}
