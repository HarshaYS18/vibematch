import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../realtime/app_realtime_hub.dart';
import '../../data/live_room_system_event_bus.dart';
import '../../modules/gift_slide/presentation/gift_slide_overlay.dart';
import '../../modules/ribbon_chat/models/ribbon_message.dart';
import '../../modules/ribbon_chat/presentation/ribbon_message_overlay.dart';
import '../../modules/video_gift/presentation/clean_video_gift_overlay.dart';
import '../controllers/live_room_gift_controller.dart';
import '../live_room_models.dart';
import 'gift_flight_bus.dart';
import 'gift_flight_overlay.dart';
import 'gift_modules/lucky_packet_room_overlay.dart';
import 'premium_gift_broadcast_overlay.dart';
import 'room_gifts.dart';

/// Composes local and backend gift presentation for one mounted room.
///
/// Flight and premium queues are injected from the room's
/// [LiveRoomGiftController], preventing gift UI events from leaking between
/// rooms while preserving backend/local deduplication behavior.
class LiveRoomGiftOverlay extends StatefulWidget {
  const LiveRoomGiftOverlay({
    super.key,
    required this.roomPublicId,
    required this.slides,
    required this.activeComboSlide,
    this.activeLuckyPacket,
    required this.bottomPadding,
    required this.onComboTap,
    required this.onComboButtonTap,
    required this.onVideoGiftFinished,
    required this.giftFlightBus,
    required this.premiumGiftBroadcastBus,
    this.onLuckyPacketGetTap,
    this.onLuckyPacketResultsDismiss,
    this.currentUserId,
    this.systemEvents,
  });

  /// Canonical room scope supplied by LiveRoomControllerBundle.
  final String roomPublicId;
  final List<GiftSlide> slides;
  final GiftSlide? activeComboSlide;
  final LuckyPacketRoomEvent? activeLuckyPacket;
  final double bottomPadding;
  final ValueChanged<GiftSlide> onComboTap;
  final VoidCallback onComboButtonTap;
  final ValueChanged<GiftSlide> onVideoGiftFinished;
  final GiftFlightBus giftFlightBus;
  final PremiumGiftBroadcastBus premiumGiftBroadcastBus;
  final VoidCallback? onLuckyPacketGetTap;
  final VoidCallback? onLuckyPacketResultsDismiss;
  final String? currentUserId;
  final Stream<LiveRoomSystemEvent>? systemEvents;

  @override
  State<LiveRoomGiftOverlay> createState() => _LiveRoomGiftOverlayState();
}

class _LiveRoomGiftOverlayState extends State<LiveRoomGiftOverlay> {
  static const int _premiumGiftMinCoins = 1000;
  static const Duration _senderLuckyOutcomeLifetime = Duration(seconds: 20);

  final List<RibbonMessage> _ribbonMessages = <RibbonMessage>[];
  final List<GiftSlide> _backendGiftSlides = <GiftSlide>[];
  final Map<String, Timer> _backendGiftTimers = <String, Timer>{};
  final Map<String, String> _backendLuckySlideIdsBySession = <String, String>{};
  final Map<String, _SenderLuckyOutcome> _senderLuckyOutcomes =
      <String, _SenderLuckyOutcome>{};
  final Set<String> _handledBackendGiftIds = <String>{};
  StreamSubscription<dynamic>? _backendGiftSubscription;

  List<GiftItem> get _fullGiftCatalog => GiftPanel.withMockExtras(mockGiftItems);

  @override
  void initState() {
    super.initState();
    final injectedEvents = widget.systemEvents;
    if (injectedEvents != null) {
      _backendGiftSubscription = injectedEvents.listen(_handleBackendRoomEvent);
    } else {
      _backendGiftSubscription = AppRealtimeHub.shared.events.listen((envelope) {
        final event = decodeLiveRoomSystemEvent(
          envelope,
          roomId: widget.roomPublicId,
        );
        if (event != null) _handleBackendRoomEvent(event);
      });
      unawaited(AppRealtimeHub.shared.start());
    }
  }

  @override
  void dispose() {
    unawaited(_backendGiftSubscription?.cancel());
    for (final timer in _backendGiftTimers.values) {
      timer.cancel();
    }
    _backendGiftTimers.clear();
    _backendLuckySlideIdsBySession.clear();
    _senderLuckyOutcomes.clear();
    super.dispose();
  }

  void _handleBackendRoomEvent(LiveRoomSystemEvent event) {
    final isGlobalBroadcast = event.type == 'global_gift_broadcast';
    if (!event.isRoomGiftSent && !isGlobalBroadcast) return;
    if (!_handledBackendGiftIds.add(event.id)) return;

    final gift = _giftItemForEvent(event);
    final videoUrl = _clean(event.giftVideoUrl) ?? _clean(gift.videoUrl);
    final videoPath =
        _clean(event.giftVideoAssetPath) ??
        _clean(gift.videoAssetPath) ??
        _videoPathFromNormalizedId(_normalize(event.giftId)) ??
        _videoPathFromNormalizedId(_normalize(event.giftName));
    final assetUrl = _clean(event.giftAssetUrl) ?? _clean(gift.assetUrl);
    final assetPath = _clean(event.giftAssetPath) ?? _clean(gift.assetPath);

    final slide = GiftSlide(
      id: event.id,
      senderName: event.actorName.trim().isEmpty
          ? 'Vibe User'
          : event.actorName.trim(),
      receiverName: event.targetName.trim().isEmpty
          ? 'user'
          : event.targetName.trim(),
      giftName: _giftDisplayName(event, gift),
      giftIcon: gift.icon,
      giftAssetPath: assetPath,
      giftAssetUrl: assetUrl,
      videoAssetPath: videoPath,
      videoUrl: videoUrl,
      colors: _colorsForBackendEvent(event, gift),
      combo: event.giftQuantity <= 0 ? 1 : event.giftQuantity,
      baseCombo: event.giftQuantity <= 0 ? 1 : event.giftQuantity,
      remainingSeconds: 10,
    );

    _publishBackendPremiumBroadcast(event, gift, slide);
    if (isGlobalBroadcast) return;

    // HTTP gift sends broadcast before the sender necessarily receives the
    // HTTP response that creates its local slide. Suppress every room echo
    // authored by this user, not only echoes for a slide that already exists.
    // For lucky gifts, retain the latest authoritative outcome so the local
    // slide shows the newest multiplier once it appears/updates.
    if (_sameRoomUserId(widget.currentUserId, event.actorUserId)) {
      if (event.isLuckyGift) {
        final key = _presentationSessionKey(
          receiverName: event.targetName,
          giftName: gift.name,
        );
        if (mounted) {
          setState(() {
            _senderLuckyOutcomes[key] = _SenderLuckyOutcome(
              multiplier: event.luckyMultiplier,
              colors: _colorsForBackendEvent(event, gift),
              receivedAt: DateTime.now(),
            );
          });
        }
      }
      return;
    }

    if (event.showGiftSlide || slide.isVideoGift) {
      _startBackendGiftSlide(
        slide,
        luckySessionKey: event.isLuckyGift ? _luckySessionKey(event) : null,
      );
    }
    _publishBackendGiftFlight(event, gift, slide);
  }

  bool _sameRoomUserId(String? left, String? right) {
    String normalizeId(String? value) {
      final text = value?.trim().toLowerCase() ?? '';
      if (text.startsWith('user_')) return text.substring(5);
      return text;
    }

    final a = normalizeId(left);
    final b = normalizeId(right);
    return a.isNotEmpty && a == b;
  }

  String _withoutMultiplier(String value) {
    return value.replaceAll(RegExp(r'(\s+x\d+)+\s*$'), '').trim();
  }

  String _presentationSessionKey({
    required String receiverName,
    required String giftName,
  }) {
    return '${_normalize(receiverName)}|${_normalize(_withoutMultiplier(giftName))}';
  }

  String _luckySessionKey(LiveRoomSystemEvent event) {
    final actor = event.actorUserId.trim().isNotEmpty
        ? event.actorUserId
        : event.actorName;
    final target = event.targetUserId.trim().isNotEmpty
        ? event.targetUserId
        : event.targetName;
    final gift = event.giftId.trim().isNotEmpty
        ? event.giftId
        : _withoutMultiplier(event.giftName);
    return '${_normalize(actor)}|${_normalize(target)}|${_normalize(gift)}';
  }

  GiftSlide _decorateLocalSenderSlide(GiftSlide slide) {
    final key = _presentationSessionKey(
      receiverName: slide.receiverName,
      giftName: slide.giftName,
    );
    final outcome = _senderLuckyOutcomes[key];
    if (outcome == null) return slide;
    if (DateTime.now().difference(outcome.receivedAt) >
        _senderLuckyOutcomeLifetime) {
      _senderLuckyOutcomes.remove(key);
      return slide;
    }
    final baseName = _withoutMultiplier(slide.giftName);
    return GiftSlide(
      id: slide.id,
      senderName: slide.senderName,
      receiverName: slide.receiverName,
      giftName: '$baseName x${outcome.multiplier}',
      giftIcon: slide.giftIcon,
      giftAssetPath: slide.giftAssetPath,
      videoAssetPath: slide.videoAssetPath,
      giftAssetUrl: slide.giftAssetUrl,
      videoUrl: slide.videoUrl,
      colors: outcome.colors,
      combo: slide.combo,
      baseCombo: slide.baseCombo,
      remainingSeconds: slide.remainingSeconds,
    );
  }

  GiftItem _giftItemForEvent(LiveRoomSystemEvent event) {
    final cleanGiftId = _normalize(event.giftId);
    final cleanGiftName = _normalize(event.giftName);
    for (final gift in _fullGiftCatalog) {
      final giftId = _normalize(gift.id);
      final giftName = _normalize(gift.name);
      if (giftId == cleanGiftId || giftName == cleanGiftName) return gift;
    }

    final looksPremium =
        event.showPremiumBroadcast ||
        event.ribbonTier == 'premium' ||
        event.broadcastScope == 'global' ||
        event.giftTotalCoinValue >= _premiumGiftMinCoins ||
        event.giftCoinValue >= _premiumGiftMinCoins ||
        cleanGiftId.startsWith('premium_');

    return GiftItem(
      id: event.giftId.trim().isEmpty ? 'backend_gift' : event.giftId.trim(),
      name: event.giftName.trim().isEmpty ? 'Gift' : event.giftName.trim(),
      category: event.isLuckyGift
          ? GiftCategory.lucky
          : looksPremium
          ? GiftCategory.premium
          : GiftCategory.classic,
      coins: event.giftCoinValue,
      icon: looksPremium
          ? Icons.workspace_premium_rounded
          : Icons.card_giftcard_rounded,
      chatSymbol: looksPremium ? '👑' : '🎁',
      colors: looksPremium
          ? const <Color>[Color(0xFFFFD166), Color(0xFF8C5CF6)]
          : const <Color>[Color(0xFFFFC857), Color(0xFF12C7B7)],
      assetUrl: event.giftAssetUrl,
      videoUrl: event.giftVideoUrl,
      assetPath: event.giftAssetPath,
      videoAssetPath:
          event.giftVideoAssetPath ??
          _videoPathFromNormalizedId(cleanGiftId) ??
          _videoPathFromNormalizedId(cleanGiftName),
      giftType: event.giftType,
      animationType: event.animationType,
      categoryKey: event.giftCategory,
      version: event.giftVersion,
      catalogVersion: event.catalogVersion,
      showGiftSlide: event.showGiftSlide,
      showPremiumBroadcast: event.showPremiumBroadcast,
      showGiftFlight: event.showGiftFlight,
    );
  }

  String? _videoPathFromNormalizedId(String normalized) {
    switch (normalized) {
      case 'love_rocket':
        return 'assets/videos/gifts/love_rocket.mp4';
      case 'proposal':
      case 'propose':
      case 'boy_proposing_girl':
      case 'boy_proposing_girl_d_romantic':
      case 'romantic_proposal':
        return 'assets/videos/gifts/boy_proposing_girl_d_romantic.mp4';
      case 'butterfly':
      case 'pretty_girl_butterfly':
      case 'pretty_girl_butterfly_animation':
        return 'assets/videos/gifts/pretty_girl_butterfly_animation.mp4';
      case 'magic_1':
      case 'premium_magic_1':
        return 'assets/videos/gifts/premium_magic_1.mp4';
      case 'magic_2':
      case 'premium_magic_2':
        return 'assets/videos/gifts/premium_magic_2.mp4';
      case 'magic_3':
      case 'premium_magic_3':
        return 'assets/videos/gifts/premium_magic_3.mp4';
    }
    return null;
  }

  String? _clean(String? value) {
    final clean = value?.trim();
    if (clean == null || clean.isEmpty || clean == 'null') return null;
    return clean;
  }

  String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  String _giftDisplayName(LiveRoomSystemEvent event, GiftItem gift) {
    final base = event.giftName.trim().isEmpty ? gift.name : event.giftName.trim();
    if (!event.isLuckyGift) return base;
    return '$base x${event.luckyMultiplier}';
  }

  List<Color> _colorsForBackendEvent(LiveRoomSystemEvent event, GiftItem gift) {
    if (!event.isLuckyGift) return gift.colors;
    if (event.luckyMultiplier >= 1000) {
      return const <Color>[Color(0xFF8B5CF6), Color(0xFF22D3EE)];
    }
    if (event.luckyMultiplier >= 500) {
      return const <Color>[Color(0xFFFF2D95), Color(0xFF00E5FF)];
    }
    if (event.luckyMultiplier >= 100) {
      return const <Color>[Color(0xFFFFC857), Color(0xFFFF5F7E)];
    }
    return gift.colors;
  }

  void _startBackendGiftSlide(
    GiftSlide slide, {
    String? luckySessionKey,
  }) {
    if (!mounted) return;

    var activeSlideId = slide.id;
    setState(() {
      if (luckySessionKey != null) {
        final existingSlideId = _backendLuckySlideIdsBySession[luckySessionKey];
        final existingIndex = existingSlideId == null
            ? -1
            : _backendGiftSlides.indexWhere((item) => item.id == existingSlideId);
        if (existingIndex >= 0) {
          final existing = _backendGiftSlides[existingIndex];
          final merged = GiftSlide(
            id: existing.id,
            senderName: slide.senderName,
            receiverName: slide.receiverName,
            giftName: slide.giftName,
            giftIcon: slide.giftIcon,
            giftAssetPath: slide.giftAssetPath,
            videoAssetPath: slide.videoAssetPath,
            giftAssetUrl: slide.giftAssetUrl,
            videoUrl: slide.videoUrl,
            colors: slide.colors,
            combo: existing.combo + slide.combo,
            baseCombo: existing.baseCombo,
            remainingSeconds: 10,
          );
          activeSlideId = existing.id;
          _backendGiftSlides.removeAt(existingIndex);
          _backendGiftSlides.insert(0, merged);
        } else {
          _backendLuckySlideIdsBySession[luckySessionKey] = slide.id;
          _backendGiftSlides.removeWhere((item) => item.id == slide.id);
          _backendGiftSlides.insert(0, slide);
        }
      } else {
        _backendGiftSlides.removeWhere((item) => item.id == slide.id);
        _backendGiftSlides.insert(0, slide);
      }
    });

    _restartBackendGiftTimer(activeSlideId);
  }

  void _restartBackendGiftTimer(String slideId) {
    _backendGiftTimers.remove(slideId)?.cancel();
    _backendGiftTimers[slideId] = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) {
      final index = _backendGiftSlides.indexWhere((item) => item.id == slideId);
      if (index < 0) {
        timer.cancel();
        _backendGiftTimers.remove(slideId);
        _removeLuckySessionForSlide(slideId);
        return;
      }
      final active = _backendGiftSlides[index];
      if (active.remainingSeconds <= 1) {
        timer.cancel();
        _backendGiftTimers.remove(slideId);
        _removeLuckySessionForSlide(slideId);
        if (!mounted) return;
        setState(() => _backendGiftSlides.removeAt(index));
        return;
      }
      if (!mounted) return;
      setState(() {
        _backendGiftSlides[index] = active.copyWith(
          remainingSeconds: active.remainingSeconds - 1,
        );
      });
    });
  }

  void _removeLuckySessionForSlide(String slideId) {
    _backendLuckySlideIdsBySession.removeWhere((_, value) => value == slideId);
  }

  void _publishBackendPremiumBroadcast(
    LiveRoomSystemEvent event,
    GiftItem gift,
    GiftSlide slide,
  ) {
    final shouldBroadcast =
        event.showPremiumBroadcast ||
        gift.category == GiftCategory.premium ||
        event.ribbonTier == 'premium' ||
        event.broadcastScope == 'global';
    if (!shouldBroadcast) return;
    widget.premiumGiftBroadcastBus.publish(
      PremiumGiftBroadcastEvent(
        id: 'premium-${event.id}',
        senderName: slide.senderName,
        senderAvatarUrl: event.actorAvatarUrl,
        targetName: slide.receiverName,
        giftName: gift.name,
        combo: slide.combo,
        giftAssetPath: slide.giftAssetPath,
        giftAssetUrl: slide.giftAssetUrl,
      ),
    );
  }

  void _publishBackendGiftFlight(
    LiveRoomSystemEvent event,
    GiftItem gift,
    GiftSlide slide,
  ) {
    if (!event.showGiftFlight) return;
    final totalCoins = event.giftTotalCoinValue > 0
        ? event.giftTotalCoinValue
        : gift.coins * slide.combo;
    if (totalCoins >= LiveRoomGiftController.smallGiftFlightThreshold) return;
    widget.giftFlightBus.publish(
      GiftFlightEvent(
        id: 'flight-${event.id}',
        gift: gift,
        senderName: slide.senderName,
        receiverName: slide.receiverName,
        combo: slide.combo,
        multiplier: event.luckyMultiplier <= 0 ? null : event.luckyMultiplier,
        rewardCoinAmount: event.luckyRewardCoinAmount <= 0
            ? null
            : event.luckyRewardCoinAmount,
        endAlignment: Alignment.center,
      ),
    );
  }

  bool _samePresentation(GiftSlide local, GiftSlide backend) {
    return _normalize(local.senderName) == _normalize(backend.senderName) &&
        _normalize(local.receiverName) == _normalize(backend.receiverName) &&
        _normalize(local.giftName) == _normalize(backend.giftName) &&
        local.combo == backend.combo;
  }

  bool _isBackendSlide(GiftSlide slide) =>
      _backendGiftSlides.any((item) => item.id == slide.id);

  @override
  Widget build(BuildContext context) {
    final localSlides = widget.slides
        .map(_decorateLocalSenderSlide)
        .toList(growable: false);
    final combinedSlides = <GiftSlide>[
      ...localSlides,
      ..._backendGiftSlides.where(
        (backendSlide) => !localSlides.any(
          (localSlide) =>
              localSlide.id == backendSlide.id ||
              _samePresentation(localSlide, backendSlide),
        ),
      ),
    ];
    final normalSlides = combinedSlides
        .where((slide) => !slide.isVideoGift)
        .toList(growable: false);
    final videoSlides = combinedSlides
        .where((slide) => slide.isVideoGift)
        .toList(growable: false);
    final rawComboSlide = widget.activeComboSlide;
    final comboSlide = _comboDisplaySlide(rawComboSlide);

    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          PremiumGiftBroadcastOverlay(bus: widget.premiumGiftBroadcastBus),
          GiftSlideOverlay(
            slides: normalSlides,
            onComboTap: (slide) {
              if (_isBackendSlide(slide)) return;
              final localSlide = widget.slides
                  .where((item) => item.id == slide.id)
                  .firstOrNull;
              widget.onComboTap(localSlide ?? slide);
            },
          ),
          CleanVideoGiftOverlay(
            roomPublicId: widget.roomPublicId,
            slides: videoSlides,
            onVideoFinished: _finishVideoGift,
          ),
          ValueListenableBuilder<GiftFlightEvent?>(
            valueListenable: widget.giftFlightBus.latest,
            builder: (context, event, _) {
              return GiftFlightOverlay(
                event: event,
                onCompleted: widget.giftFlightBus.clear,
              );
            },
          ),
          RibbonMessageOverlay(messages: _ribbonMessages),
          if (comboSlide != null)
            Positioned(
              right: 18,
              bottom: 178 + widget.bottomPadding,
              child: ComboBuzzer(
                slide: comboSlide,
                onTap: () => widget.onComboTap(rawComboSlide!),
              ),
            ),
          LuckyPacketRoomOverlay(
            packet: widget.activeLuckyPacket,
            onGetTap: widget.onLuckyPacketGetTap ?? () {},
            onDismissResults: widget.onLuckyPacketResultsDismiss ?? () {},
          ),
        ],
      ),
    );
  }

  GiftSlide? _comboDisplaySlide(GiftSlide? slide) {
    if (slide == null || slide.remainingSeconds <= 0) return null;
    return slide;
  }

  void _finishVideoGift(GiftSlide slide) {
    if (_backendGiftSlides.any((item) => item.id == slide.id)) {
      _backendGiftTimers.remove(slide.id)?.cancel();
      _removeLuckySessionForSlide(slide.id);
      if (!mounted) return;
      setState(
        () => _backendGiftSlides.removeWhere((item) => item.id == slide.id),
      );
      return;
    }
    final localSlide = widget.slides.where((item) => item.id == slide.id).firstOrNull;
    widget.onVideoGiftFinished(localSlide ?? slide);
  }
}

class _SenderLuckyOutcome {
  const _SenderLuckyOutcome({
    required this.multiplier,
    required this.colors,
    required this.receivedAt,
  });

  final int multiplier;
  final List<Color> colors;
  final DateTime receivedAt;
}
