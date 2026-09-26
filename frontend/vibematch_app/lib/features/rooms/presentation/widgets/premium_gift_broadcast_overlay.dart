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
    this.giftAssetUrl,
  });

  final String id;
  final String senderName;
  final String targetName;
  final String giftName;
  final int combo;
  final String? senderAvatarUrl;
  final String? giftAssetPath;
  final String? giftAssetUrl;
}

/// Room-scoped queue for premium gift broadcast presentation.
///
/// Ownership: [LiveRoomGiftController]. This queue is ephemeral UI state only;
/// authoritative gift send/results come from backend room events. The queue is
/// disposed with the room controller so broadcasts cannot leak across rooms.
class PremiumGiftBroadcastBus {
  PremiumGiftBroadcastBus();

  final ValueNotifier<int> queueVersion = ValueNotifier<int>(0);
  final List<PremiumGiftBroadcastEvent> _queue =
      <PremiumGiftBroadcastEvent>[];
  PremiumGiftBroadcastEvent? _active;

  PremiumGiftBroadcastEvent? get active => _active;

  bool _isBackend(PremiumGiftBroadcastEvent event) =>
      event.id.startsWith('premium-gift_');

  String _key(PremiumGiftBroadcastEvent event) =>
      '${event.senderName.trim().toLowerCase()}|'
      '${event.targetName.trim().toLowerCase()}|'
      '${event.giftName.trim().toLowerCase()}|${event.combo}';

  bool _same(
    PremiumGiftBroadcastEvent left,
    PremiumGiftBroadcastEvent right,
  ) => _key(left) == _key(right);

  void publish(PremiumGiftBroadcastEvent event) {
    final active = _active;
    final incomingIsBackend = _isBackend(event);

    if (!incomingIsBackend) {
      if (active != null && _isBackend(active) && _same(active, event)) return;
      if (_queue.any((item) => _isBackend(item) && _same(item, event))) return;
    } else if (active != null && !_isBackend(active) && _same(active, event)) {
      _active = event;
      queueVersion.value++;
      return;
    }

    if (incomingIsBackend) {
      _queue.removeWhere((item) => !_isBackend(item) && _same(item, event));
    }

    if (_active == null) {
      _active = event;
    } else {
      _queue.add(event);
    }
    queueVersion.value++;
  }

  void completeActive() {
    _active = _queue.isEmpty ? null : _queue.removeAt(0);
    queueVersion.value++;
  }

  void clearAll() {
    _active = null;
    _queue.clear();
    queueVersion.value++;
  }

  void dispose() {
    _active = null;
    _queue.clear();
    queueVersion.dispose();
  }
}

/// Renders the currently active premium broadcast from a room-scoped queue.
class PremiumGiftBroadcastOverlay extends StatelessWidget {
  const PremiumGiftBroadcastOverlay({
    super.key,
    required this.bus,
  });

  final PremiumGiftBroadcastBus bus;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: bus.queueVersion,
      builder: (context, _, child) {
        final event = bus.active;
        if (event == null) return const SizedBox.shrink();
        return Positioned(
          top: MediaQuery.paddingOf(context).top + 8,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: _PremiumGiftBroadcastCard(
              key: ValueKey(event.id),
              event: event,
              onCompleted: bus.completeActive,
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
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 1).chain(
          CurveTween(curve: Curves.easeOutCubic),
        ),
        weight: 18,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1), weight: 58),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 0).chain(
          CurveTween(curve: Curves.easeInCubic),
        ),
        weight: 24,
      ),
    ]).animate(_controller);
    _offset = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: const Offset(0, -0.35),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 22,
      ),
      TweenSequenceItem(
        tween: ConstantTween<Offset>(Offset.zero),
        weight: 54,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(0, -0.10),
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 24,
      ),
    ]).animate(_controller);
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.94, end: 1).chain(
          CurveTween(curve: Curves.easeOutBack),
        ),
        weight: 24,
      ),
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
                        horizontal: frameWidth * 0.112,
                        vertical: frameHeight * 0.315,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.black.withValues(alpha: 0.00),
                              const Color(0xFF101827).withValues(alpha: 0.76),
                              const Color(0xFF0B1020).withValues(alpha: 0.88),
                              const Color(0xFF101827).withValues(alpha: 0.76),
                              Colors.black.withValues(alpha: 0.00),
                            ],
                            stops: const [0.0, 0.13, 0.50, 0.87, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Image.asset(
                      'assets/gifts/broadcast/premium_gift_broadcast_frame.png',
                      fit: BoxFit.fill,
                      errorBuilder: (context, error, stackTrace) =>
                          const _FallbackPremiumFrame(),
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: frameWidth * 0.145,
                        right: frameWidth * 0.185,
                        top: frameHeight * 0.245,
                        bottom: frameHeight * 0.205,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _BroadcastAvatar(
                            name: widget.event.senderName,
                            avatarUrl: widget.event.senderAvatarUrl,
                          ),
                          const SizedBox(width: 8),
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
                                    decoration: TextDecoration.none,
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
                                    decoration: TextDecoration.none,
                                    shadows: [
                                      Shadow(color: Colors.black87, blurRadius: 6),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if ((widget.event.giftAssetUrl?.trim().isNotEmpty ?? false) ||
                              (widget.event.giftAssetPath?.trim().isNotEmpty ?? false)) ...[
                            const SizedBox(width: 7),
                            _BroadcastGiftImage(
                              assetUrl: widget.event.giftAssetUrl,
                              assetPath: widget.event.giftAssetPath,
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

class _FallbackPremiumFrame extends StatelessWidget {
  const _FallbackPremiumFrame();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFFD166), width: 1.2),
        gradient: const LinearGradient(
          colors: [Color(0x00231236), Color(0xCC231236), Color(0x00231236)],
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
    final url = avatarUrl?.trim();
    return Container(
      width: 31,
      height: 31,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD166), Color(0xFF8C5CF6)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72), width: 1),
      ),
      padding: const EdgeInsets.all(1.5),
      child: ClipOval(
        child: url != null && url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _avatarFallback(),
              )
            : _avatarFallback(),
      ),
    );
  }

  Widget _avatarFallback() {
    final initial = name.trim().isEmpty ? 'V' : name.trim()[0].toUpperCase();
    return ColoredBox(
      color: const Color(0xFF181325),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

class _BroadcastGiftImage extends StatelessWidget {
  const _BroadcastGiftImage({this.assetUrl, this.assetPath});

  final String? assetUrl;
  final String? assetPath;

  @override
  Widget build(BuildContext context) {
    final url = assetUrl?.trim();
    final path = assetPath?.trim();
    Widget fallback() => const Icon(
      Icons.card_giftcard_rounded,
      color: Color(0xFFFFE7A1),
      size: 25,
    );
    return SizedBox(
      width: 31,
      height: 31,
      child: url != null && url.isNotEmpty
          ? Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => fallback(),
            )
          : path != null && path.isNotEmpty
          ? Image.asset(
              path,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => fallback(),
            )
          : fallback(),
    );
  }
}
