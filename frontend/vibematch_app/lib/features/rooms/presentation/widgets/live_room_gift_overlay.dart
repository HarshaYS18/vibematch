import 'dart:async';

import 'package:flutter/material.dart';

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
import 'live_room_event_carousel.dart';
import 'premium_gift_broadcast_overlay.dart';
import 'room_gifts.dart';

class LiveRoomGiftOverlay extends StatefulWidget {
  const LiveRoomGiftOverlay({
    super.key,
    required this.slides,
    required this.activeComboSlide,
    this.activeLuckyPacket,
    required this.bottomPadding,
    required this.onComboTap,
    required this.onComboButtonTap,
    required this.onVideoGiftFinished,
    this.onLuckyPacketGetTap,
    this.onLuckyPacketResultsDismiss,
  });

  final List<GiftSlide> slides;
  final GiftSlide? activeComboSlide;
  final LuckyPacketRoomEvent? activeLuckyPacket;
  final double bottomPadding;
  final ValueChanged<GiftSlide> onComboTap;
  final VoidCallback onComboButtonTap;
  final ValueChanged<GiftSlide> onVideoFinished;
  final VoidCallback? onLuckyPacketGetTap;
  final VoidCallback? onLuckyPacketResultsDismiss;

  @override
  State<LiveRoomGiftOverlay> createState() => _LiveRoomGiftOverlayState();
}

class _LiveRoomGiftOverlayState extends State<LiveRoomGiftOverlay> {
  static const int _premiumGiftMinCoins = 1000;

  final List<RibbonMessage> _ribbonMessages = <RibbonMessage>[];
  final List<GiftSlide> _backendGiftSlides = <GiftSlide>[];
  final Map<String, Timer> _backendGiftTimers = <String, Timer>{};
  final Set<String> _handledBackendGiftIds = <String>{};
  VoidCallback? _backendGiftListener;

  List<GiftItem> get _fullGiftCatalog => GiftPanel.withMockExtras(mockGiftItems);

  @override
  void initState() {
    super.initState();
    _backendGiftListener = _handleBackendRoomEvent;
    LiveRoomSystemEventBus.latestEvent.addListener(_backendGiftListener!);
  }

  @override
  void dispose() {
    final listener = _backendGiftListener;
    if (listener != null) {
      LiveRoomSystemEventBus.latestEvent.removeListener(listener);
    }
    for (final timer in _backendGiftTimers.values) {
      timer.cancel();
    }
    _backendGiftTimers.clear();
    super.dispose();
  }

  void _handleBackendRoomEvent() {
    final event = LiveRoomSystemEventBus.latestEvent.value;
    if (event == null || !event.isRoomGiftSent) return;
    if (!_handledBackendGiftIds.add(event.id)) return;

    final gift = _giftItemForEvent(event);
    final videoUrl = _clean(event.giftVideoUrl) ?? _clean(gift.videoUrl);
    final videoPath = _clean(event.giftVideoAssetPath) ??
        _clean(gift.videoAssetPath) ??
        _videoPathFromNormalizedId(_normalize(event.giftId)) ??
        _videoPathFromNormalizedId(_normalize(event.giftName));
    final assetUrl = _clean(event.giftAssetUrl) ?? _clean(gift.assetUrl);
    final assetPath = _clean(event.giftAssetPath) ?? _clean(gift.assetPath);

    final slide = GiftSlide(
      id: event.id,
      senderName: event.actorName.trim().isEmpty ? 'Vibe User' : event.actorName.trim(),
      receiverName: event.targetName.trim().isEmpty ? 'user' : event.targetName.trim(),
      giftName: _giftDisplayName(event, gift),
      giftIcon: gift.icon,
      giftAssetPath: assetPath,
      giftAssetUrl: assetUrl,
      videoAssetPath: videoPath,
      videoUrl: videoUrl,
      colors: _colorsForBackendEvent(event, gift),
      combo: event.giftQuantity <= 0 ? 1 : event.giftQuantity,
      baseCombo: event.giftQuantity <= 0 ? 1 : event.giftQuantity,
      remainingSeconds: (videoUrl == null && videoPath == null) ? 15 : 10,
    );

    if (event.showGiftSlide || slide.isVideoGift) {
      _startBackendGiftSlide(slide);
    }
    _publishBackendPremiumBroadcast(event, gift, slide);
    _publishBackendGiftFlight(event, gift, slide);
  }

  GiftItem _giftItemForEvent(LiveRoomSystemEvent event) {
    final cleanGiftId = _normalize(event.giftId);
    final cleanGiftName = _normalize(event.giftName);
    for (final gift in _fullGiftCatalog) {
      final giftId = _normalize(gift.id);
      final giftName = _normalize(gift.name);
      if (giftId == cleanGiftId || giftName == cleanGiftName) {
        return gift;
      }
    }

    final looksPremium = event.showPremiumBroadcast ||
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
      videoAssetPath: event.giftVideoAssetPath ??
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
    if (!event.isLuckyGift || event.luckyMultiplier <= 0) return base;
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

  void _startBackendGiftSlide(GiftSlide slide) {
    if (!mounted) return;
    setState(() {
      _backendGiftSlides.removeWhere((item) => item.id == slide.id);
      _backendGiftSlides.insert(0, slide);
    });
    _backendGiftTimers[slide.id]?.cancel();
    _backendGiftTimers[slide.id] = Timer.periodic(const Duration(seconds: 1), (timer) {
      final index = _backendGiftSlides.indexWhere((item) => item.id == slide.id);
      if (index < 0) {
        timer.cancel();
        _backendGiftTimers.remove(slide.id);
        return;
      }
      final active = _backendGiftSlides[index];
      if (active.remainingSeconds <= 0) {
        timer.cancel();
        _backendGiftTimers.remove(slide.id);
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

  void _publishBackendPremiumBroadcast(
    LiveRoomSystemEvent event,
    GiftItem gift,
    GiftSlide slide,
  ) {
    final shouldBroadcast = event.showPremiumBroadcast ||
        gift.category == GiftCategory.premium ||
        event.ribbonTier == 'premium' ||
        event.broadcastScope == 'global';
    if (!shouldBroadcast) return;
    PremiumGiftBroadcastBus.publish(
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
    GiftFlightBus.publish(
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

  @override
  Widget build(BuildContext context) {
    final normalSlides = _backendGiftSlides
        .where((slide) => !slide.isVideoGift)
        .toList(growable: false);
    final hasActiveVideoGift = _backendGiftSlides.any((slide) => slide.isVideoGift);
    final hasLuckyPacketDialog = widget.activeLuckyPacket != null &&
        widget.activeLuckyPacket!.phase != LuckyPacketPhase.countdown;

    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          const PremiumGiftBroadcastOverlay(),
          GiftSlideOverlay(
            slides: normalSlides,
            onComboTap: widget.onComboTap,
          ),
          CleanVideoGiftOverlay(
            slides: _backendGiftSlides,
            onVideoFinished: _finishBackendVideoGift,
          ),
          ValueListenableBuilder<GiftFlightEvent?>(
            valueListenable: GiftFlightBus.latest,
            builder: (context, event, _) {
              return GiftFlightOverlay(
                event: event,
                onCompleted: GiftFlightBus.clear,
              );
            },
          ),
          RibbonMessageOverlay(messages: _ribbonMessages),
          if (!hasActiveVideoGift && !hasLuckyPacketDialog)
            Positioned(
              right: 24,
              bottom: 104 + widget.bottomPadding,
              child: const LiveRoomEventCarousel(),
            ),
          Positioned(
            right: 18,
            bottom: 178 + widget.bottomPadding,
            child: ComboBuzzer(
              slide: null,
              onTap: widget.onComboButtonTap,
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

  void _finishBackendVideoGift(GiftSlide slide) {
    _backendGiftTimers.remove(slide.id)?.cancel();
    if (!mounted) return;
    setState(() => _backendGiftSlides.removeWhere((item) => item.id == slide.id));
  }
}
