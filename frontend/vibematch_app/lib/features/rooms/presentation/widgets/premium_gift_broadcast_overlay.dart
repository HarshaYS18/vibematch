import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class PremiumGiftBroadcastEvent {
  const PremiumGiftBroadcastEvent({
    required this.id,
    required this.senderName,
    required this.targetName,
    required this.giftName,
    required this.combo,
    this.senderAvatarUrl,
    this.giftAssetPath,
  });

  final String id;
  final String senderName;
  final String targetName;
  final String giftName;
  final int combo;
  final String? senderAvatarUrl;
  final String? giftAssetPath;
}

class PremiumGiftBroadcastBus {
  const PremiumGiftBroadcastBus._();

  static final ValueNotifier<PremiumGiftBroadcastEvent?> latest = ValueNotifier<PremiumGiftBroadcastEvent?>(null);

  static void publish(PremiumGiftBroadcastEvent event) {
    latest.value = event;
  }

  static void clear() {
    latest.value = null;
  }
}

class PremiumGiftBroadcastOverlay extends StatelessWidget {
  const PremiumGiftBroadcastOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PremiumGiftBroadcastEvent?>(
      valueListenable: PremiumGiftBroadcastBus.latest,
      builder: (context, event, _) {
        if (event == null) return const SizedBox.shrink();
        return Positioned(
          top: MediaQuery.paddingOf(context).top + 8,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: _PremiumGiftBroadcastCard(
              key: ValueKey(event.id),
              event: event,
              onCompleted: PremiumGiftBroadcastBus.clear,
            ),
          ),
        );
      },
    );
  }
}

class _PremiumGiftBroadcastCard extends StatefulWidget {
  const _PremiumGiftBroadcastCard({
    super.key,
    required this.event,
    required this.onCompleted,
  });

  final PremiumGiftBroadcastEvent event;
  final VoidCallback onCompleted;

  @override
  State<_PremiumGiftBroadcastCard> createState() => _PremiumGiftBroadcastCardState();
}

class _PremiumGiftBroadcastCardState extends State<_PremiumGiftBroadcastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4700),
    );
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0, end: 1).chain(CurveTween(curve: Curves.easeOutCubic)), weight: 18),
      TweenSequenceItem(tween: ConstantTween<double>(1), weight: 58),
      TweenSequenceItem(tween: Tween<double>(begin: 1, end: 0).chain(CurveTween(curve: Curves.easeInCubic)), weight: 24),
    ]).animate(_controller);
    _offset = TweenSequence<Offset>([
      TweenSequenceItem(tween: Tween<Offset>(begin: const Offset(0, -0.35), end: Offset.zero).chain(CurveTween(curve: Curves.easeOutCubic)), weight: 22),
      TweenSequenceItem(tween: ConstantTween<Offset>(Offset.zero), weight: 54),
      TweenSequenceItem(tween: Tween<Offset>(begin: Offset.zero, end: const Offset(0, -0.10)).chain(CurveTween(curve: Curves.easeInCubic)), weight: 24),
    ]).animate(_controller);
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.94, end: 1).chain(CurveTween(curve: Curves.easeOutBack)), weight: 24),
      TweenSequenceItem(tween: ConstantTween<double>(1), weight: 76),
    ]).animate(_controller);
    _controller
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onCompleted();
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final frameWidth = width.clamp(320.0, 760.0);
    final frameHeight = frameWidth * 0.235;

    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _offset,
        child: ScaleTransition(
          scale: _scale,
          child: Center(
            child: SizedBox(
              width: frameWidth,
              height: frameHeight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: frameWidth * 0.105,
                        vertical: frameHeight * 0.29,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              const Color(0xFFFFF8D9).withValues(alpha: 0.00),
                              const Color(0xFFFFF5C8).withValues(alpha: 0.18),
                              const Color(0xFFE8EEF8).withValues(alpha: 0.22),
                              const Color(0xFFFFF5C8).withValues(alpha: 0.18),
                              const Color(0xFFFFF8D9).withValues(alpha: 0.00),
                            ],
                            stops: const [0, 0.16, 0.50, 0.84, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Image.asset(
                      'assets/gifts/broadcast/premium_gift_broadcast_frame.png',
                      fit: BoxFit.fill,
                      errorBuilder: (context, error, stackTrace) => _FallbackPremiumFrame(),
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: frameWidth * 0.18,
                        right: frameWidth * 0.18,
                        top: frameHeight * 0.30,
                        bottom: frameHeight * 0.20,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _BroadcastAvatar(
                            name: widget.event.senderName,
                            avatarUrl: widget.event.senderAvatarUrl,
                          ),
                          const SizedBox(width: 9),
                          Flexible(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.event.senderName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFFFFFFF),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                    height: 1.0,
                                    shadows: [
                                      Shadow(color: Colors.black87, blurRadius: 6),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'sent ${widget.event.giftName} to ${widget.event.targetName} x${widget.event.combo}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFFFF2BF),
                                    fontSize: 10.8,
                                    fontWeight: FontWeight.w800,
                                    height: 1.0,
                                    shadows: [
                                      Shadow(color: Colors.black87, blurRadius: 6),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.event.giftAssetPath?.trim().isNotEmpty ?? false) ...[
                            const SizedBox(width: 7),
                            Image.asset(
                              widget.event.giftAssetPath!,
                              width: 34,
                              height: 34,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => const Icon(
                                Icons.card_giftcard_rounded,
                                color: Color(0xFFFFD166),
                                size: 26,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BroadcastAvatar extends StatelessWidget {
  const _BroadcastAvatar({required this.name, this.avatarUrl});

  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final cleanUrl = avatarUrl?.trim();
    return Container(
      width: 33,
      height: 33,
      padding: const EdgeInsets.all(1.4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD166), Color(0xFFE8EEF8)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD166).withValues(alpha: 0.26),
            blurRadius: 10,
          ),
        ],
      ),
      child: ClipOval(
        child: cleanUrl == null || cleanUrl.isEmpty
            ? Container(
                alignment: Alignment.center,
                color: const Color(0xFF251538),
                child: Text(
                  name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              )
            : Image.network(
                cleanUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  alignment: Alignment.center,
                  color: const Color(0xFF251538),
                  child: Text(
                    name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _FallbackPremiumFrame extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFFD166), width: 2.2),
        gradient: LinearGradient(
          colors: [
            Colors.black.withValues(alpha: 0.00),
            Colors.black.withValues(alpha: 0.55),
            Colors.black.withValues(alpha: 0.55),
            Colors.black.withValues(alpha: 0.00),
          ],
        ),
      ),
    );
  }
}
