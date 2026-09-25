import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Alignment, Color;

import '../../../auth/data/auth_api_service.dart';
import '../../../auth/models/current_user.dart';
import '../../../gifts/data/lucky_gifts_api_service.dart';
import '../../../relationships/data/relationship_exp_api_service.dart';
import '../../../wallet/data/wallet_api_service.dart';
import '../../data/gift_api_service.dart';
import '../../data/live_room_media_signaling_service.dart';
import '../../data/mini_profile_economy_service.dart';
import '../live_room_models.dart';
import '../widgets/gift_flight_bus.dart';
import '../widgets/gift_flight_overlay.dart';
import '../widgets/premium_gift_broadcast_overlay.dart';

enum LuckyPacketPhase { countdown, claim, results }

class LuckyPacketRoomEvent {
  const LuckyPacketRoomEvent({
    required this.id,
    required this.senderName,
    required this.coinAmount,
    required this.winnerCount,
    required this.message,
    required this.phase,
    required this.remainingSeconds,
    this.claimedByCurrentUser = false,
    this.currentUserReward,
    this.distributions = const <String, int>{},
  });

  final String id;
  final String senderName;
  final int coinAmount;
  final int winnerCount;
  final String message;
  final LuckyPacketPhase phase;
  final int remainingSeconds;
  final bool claimedByCurrentUser;
  final int? currentUserReward;
  final Map<String, int> distributions;

  LuckyPacketRoomEvent copyWith({
    LuckyPacketPhase? phase,
    int? remainingSeconds,
    bool? claimedByCurrentUser,
    int? currentUserReward,
    Map<String, int>? distributions,
  }) {
    return LuckyPacketRoomEvent(
      id: id,
      senderName: senderName,
      coinAmount: coinAmount,
      winnerCount: winnerCount,
      message: message,
      phase: phase ?? this.phase,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      claimedByCurrentUser: claimedByCurrentUser ?? this.claimedByCurrentUser,
      currentUserReward: currentUserReward ?? this.currentUserReward,
      distributions: distributions ?? this.distributions,
    );
  }
}

/// Room-scoped owner for gift interaction and gift presentation state.
///
/// Backend services remain authoritative for wallet/gift outcomes. The
/// controller owns only one mounted room's transient slides, combo state,
/// flying-gift queue and premium-broadcast queue; all are disposed on room exit.
class LiveRoomGiftController {
  /// Optional only for isolated controller tests. Production room bundles pass
  /// their canonical room id explicitly; no process-global room cache is read.

  LiveRoomGiftController({
    required SeatUser currentUser,
    this.roomPublicId,
    required this.onChanged,
    required this.onFinalGiftMessage,
    required this.onToast,
    bool refreshCoinBalanceOnCreate = true,
  }) : currentUser = LiveRoomMediaSignalingService.instance
           .effectiveCurrentUser(currentUser) {
    _userRealtimeSub = AuthUserRealtimeService.instance.users.listen(
      _handleRealtimeUser,
    );
    if (refreshCoinBalanceOnCreate) {
      unawaited(refreshCoinBalance());
    }
  }

  final String? roomPublicId;

  static const int smallGiftFlightThreshold = 200000;
  static const int comboTriggerSeconds = 15;

  final SeatUser currentUser;
  final VoidCallbackLike onChanged;
  final ValueChangedLike<ChatEntry> onFinalGiftMessage;
  final ValueChangedLike<String> onToast;
  final WalletApiService _walletApi = const WalletApiService();
  final GiftApiService _giftApi = const GiftApiService();
  final LuckyGiftsApiService _luckyGiftsApi = const LuckyGiftsApiService();
  final RelationshipExpApiService _relationshipExpApi =
      const RelationshipExpApiService();

  /// Ephemeral flight animations scoped to this room controller.
  final GiftFlightBus giftFlightBus = GiftFlightBus();

  /// Ephemeral premium broadcasts scoped to this room controller.
  final PremiumGiftBroadcastBus premiumGiftBroadcastBus =
      PremiumGiftBroadcastBus();

  StreamSubscription<CurrentUser>? _userRealtimeSub;

  GiftCategory selectedCategory = GiftCategory.premium;
  GiftItem? selectedGift;
  final Set<String> selectedReceiverIds = <String>{};
  int selectedCombo = 1;
  int coinBalance = 0;
  bool giftSendInProgress = false;
  bool luckyGiftSendInProgress = false;

  final List<GiftSlide> giftSlides = <GiftSlide>[];
  final Map<String, Timer> _giftTimers = <String, Timer>{};
  final Set<String> _finishedGiftMessageIds = <String>{};
  final Map<String, _LuckyComboContext> _luckyComboContexts =
      <String, _LuckyComboContext>{};
  final Set<String> _luckyComboProcessingSlideIds = <String>{};
  final Set<String> _luckyComboProcessingKeys = <String>{};
  final Map<String, DateTime> _lastComboTapBySlideId = <String, DateTime>{};

  LuckyPacketRoomEvent? activeLuckyPacket;
  Timer? _luckyPacketTimer;
  final Random _random = Random();

  bool get selectedGiftIsLuckyPacket => selectedGift?.id == 'lucky_packet';
  bool get selectedGiftIsFromPremiumSection =>
      selectedCategory == GiftCategory.premium ||
      selectedGift?.category == GiftCategory.premium ||
      selectedGift?.categoryKey == 'premium' ||
      selectedGift?.showPremiumBroadcast == true;

  Future<void> refreshCoinBalance() async {
    try {
      final wallet = await _walletApi.getWallet();
      coinBalance = wallet.coinBalance;
      onChanged();
    } catch (_) {
      // Keep the current visible value. Do not fall back to mock coins.
    }
  }

  void _handleRealtimeUser(CurrentUser user) {
    final currentPublicUserId = _publicUserIdFromSeatUser(currentUser);
    if (currentPublicUserId == null ||
        currentPublicUserId != user.publicUserId) {
      return;
    }
    final nextBalance = user.wallet.coinBalance;
    if (coinBalance == nextBalance) return;
    coinBalance = nextBalance;
    onChanged();
  }

  GiftSlide? get activeComboSlide {
    final normalSlides = giftSlides
        .where(
          (slide) => !slide.isVideoGift && slide.giftName != 'Lucky Packet',
        )
        .toList(growable: false);
    return normalSlides.isEmpty ? null : normalSlides.first;
  }

  bool _isLuckyGiftSlide(GiftSlide slide) {
    final name = slide.giftName.toLowerCase();
    return name.contains('lucky') ||
        name.contains('spin') ||
        _luckyComboContexts.containsKey(slide.id);
  }

  void ensureDefaultReceiver(List<SeatUser> roomUsers) {
    if (selectedReceiverIds.isEmpty && roomUsers.isNotEmpty) {
      selectedReceiverIds.add(roomUsers.first.id);
    }
  }

  void selectCategory(GiftCategory category) {
    selectedCategory = category;
    selectedCombo = category == GiftCategory.lucky ? 9 : 1;
    if (selectedGiftIsLuckyPacket) selectedCombo = 1;
    onChanged();
  }

  void selectGift(GiftItem gift) {
    selectedGift = gift;
    selectedCategory = gift.category;
    selectedCombo = gift.id == 'lucky_packet'
        ? 1
        : ((gift.categoryKey == 'lucky' || gift.category == GiftCategory.lucky)
              ? 9
              : 1);
    onChanged();
  }

  void toggleReceiver(String id, List<SeatUser> roomUsers) {
    if (id == '__all__') {
      if (selectedReceiverIds.length == roomUsers.length) {
        selectedReceiverIds.clear();
      } else {
        selectedReceiverIds
          ..clear()
          ..addAll(roomUsers.map((user) => user.id));
      }
      onChanged();
      return;
    }
    if (selectedReceiverIds.contains(id)) {
      selectedReceiverIds.remove(id);
    } else {
      selectedReceiverIds.add(id);
    }
    onChanged();
  }

  void setCombo(int combo) {
    if (selectedGiftIsLuckyPacket) {
      selectedCombo = 1;
      onChanged();
      return;
    }
    selectedCombo = combo;
    onChanged();
  }

  void sendGift(List<SeatUser> roomUsers) {
    final gift = selectedGift;
    if (gift == null) {
      onToast('No gift selected');
      return;
    }
    if (gift.id == 'lucky_packet') {
      onToast('Choose Lucky Packet amount first');
      return;
    }
    final receivers = roomUsers
        .where((user) => selectedReceiverIds.contains(user.id))
        .toList();
    if (receivers.isEmpty) {
      onToast('Select a receiver');
      return;
    }
    final effectiveCombo = selectedCombo;
    final totalCost = gift.coins * effectiveCombo * receivers.length;
    if (coinBalance < totalCost) {
      onToast('Not enough coins');
      unawaited(refreshCoinBalance());
      return;
    }

    if (gift.categoryKey == 'lucky' || gift.category == GiftCategory.lucky) {
      unawaited(
        _sendLuckyGift(
          gift: gift,
          receivers: receivers,
          roomUsers: roomUsers,
          effectiveCombo: effectiveCombo,
        ),
      );
      return;
    }

    unawaited(
      _sendNormalGift(
        gift: gift,
        receivers: receivers,
        roomUsers: roomUsers,
        effectiveCombo: effectiveCombo,
      ),
    );
  }

  Future<void> _sendNormalGift({
    required GiftItem gift,
    required List<SeatUser> receivers,
    required List<SeatUser> roomUsers,
    required int effectiveCombo,
  }) async {
    if (giftSendInProgress) {
      onToast('Gift is processing');
      return;
    }
    giftSendInProgress = true;
    onChanged();

    try {
      final shouldPublishPremiumBroadcast = selectedGiftIsFromPremiumSection;
      final sentToAll =
          !gift.isVideoGift &&
          receivers.length == roomUsers.length &&
          roomUsers.isNotEmpty;
      final deliveredCombo = sentToAll
          ? effectiveCombo * receivers.length
          : effectiveCombo;

      for (final receiver in receivers) {
        final receiverPublicUserId = _publicUserIdFromSeatUser(receiver);
        if (receiverPublicUserId == null) {
          onToast('${receiver.name} does not have a valid public user ID yet');
          continue;
        }

        final result = await _giftApi.sendGiftPublic(
          receiverPublicUserId: receiverPublicUserId,
          giftId: gift.id,
          coinValue: gift.coins,
          quantity: effectiveCombo,
          roomPublicId: roomPublicId,
        );
        coinBalance = result.senderCoinBalance;
        unawaited(
          _recordRelationshipGiftExpSilently(
            gift: gift,
            quantity: effectiveCombo,
            receiverPublicUserId: receiverPublicUserId,
            eventType: 'gift_sent',
          ),
        );
      }

      final targets = sentToAll
          ? <SeatUser?>[null]
          : receivers.cast<SeatUser?>();
      for (final receiver in targets) {
        _showCommittedGiftSlide(
          gift: gift,
          receiver: receiver,
          receiverName: receiver?.name ?? 'all',
          combo: deliveredCombo,
          roomUsers: roomUsers,
          shouldPublishPremiumBroadcast: shouldPublishPremiumBroadcast,
        );
      }

      MiniProfileEconomyService.instance.clearCache();
      unawaited(refreshCoinBalance());
    } catch (error) {
      onToast(error.toString().replaceFirst('Exception: ', ''));
      unawaited(refreshCoinBalance());
    } finally {
      giftSendInProgress = false;
      onChanged();
    }
  }

  void _showCommittedGiftSlide({
    required GiftItem gift,
    required SeatUser? receiver,
    required String receiverName,
    required int combo,
    required List<SeatUser> roomUsers,
    required bool shouldPublishPremiumBroadcast,
  }) {
    final slide = GiftSlide(
      id: '${receiver?.id ?? 'all'}-${DateTime.now().microsecondsSinceEpoch}',
      senderName: currentUser.name,
      receiverName: receiverName,
      giftName: gift.name,
      giftIcon: gift.icon,
      giftAssetPath: gift.assetPath,
      giftAssetUrl: gift.assetUrl,
      videoAssetPath: gift.videoAssetPath,
      videoUrl: gift.videoUrl,
      colors: gift.colors,
      combo: combo,
      baseCombo: combo,
      remainingSeconds: gift.isVideoGift ? 10 : comboTriggerSeconds,
    );
    _startGiftSlide(slide);
    _publishPremiumBroadcastIfNeeded(
      gift: gift,
      receiverName: receiverName,
      combo: combo,
      shouldPublish: shouldPublishPremiumBroadcast,
    );

    final shouldFly = (gift.coins * combo) < smallGiftFlightThreshold;
    if (shouldFly) {
      giftFlightBus.publish(
        GiftFlightEvent(
          id: 'flight-${slide.id}',
          gift: gift,
          senderName: currentUser.name,
          receiverName: receiverName,
          combo: combo,
          endAlignment: _receiverAlignment(receiver, roomUsers),
        ),
      );
    }
  }

  Future<void> _sendLuckyGift({
    required GiftItem gift,
    required List<SeatUser> receivers,
    required List<SeatUser> roomUsers,
    required int effectiveCombo,
  }) async {
    if (luckyGiftSendInProgress) {
      onToast('Lucky gift is processing');
      return;
    }
    luckyGiftSendInProgress = true;
    onChanged();

    try {
      for (final receiver in receivers) {
        final receiverPublicUserId = _publicUserIdFromSeatUser(receiver);
        if (receiverPublicUserId == null) {
          onToast('${receiver.name} does not have a valid public user ID yet');
          continue;
        }

        final result = await _giftApi.sendLuckyGiftPublic(
          receiverPublicUserId: receiverPublicUserId,
          giftId: gift.id,
          coinValue: gift.coins,
          quantity: effectiveCombo,
          roomPublicId: roomPublicId,
        );

        final multiplier =
            result.luckyMultiplier ?? result.luckyResult?.multiplier ?? 1;
        final rewardCoinAmount =
            result.luckyRewardCoinAmount ??
            result.luckyResult?.rewardCoinAmount ??
            0;
        coinBalance = result.senderCoinBalance;
        unawaited(
          _recordRelationshipGiftExpSilently(
            gift: gift,
            quantity: effectiveCombo,
            receiverPublicUserId: receiverPublicUserId,
            eventType: 'lucky_gift_sent',
          ),
        );
        final slide = _createLuckySlide(
          gift: gift,
          receiverName: receiver.name,
          combo: effectiveCombo,
          multiplier: multiplier,
        );
        _luckyComboContexts[slide.id] = _LuckyComboContext(
          gift: gift,
          receiverPublicUserId: receiverPublicUserId,
          receiverName: receiver.name,
          baseCombo: effectiveCombo,
          endAlignment: _receiverAlignment(receiver, roomUsers),
        );
        _startGiftSlide(slide);
        _publishLuckyFlight(
          slide: slide,
          gift: gift,
          receiverName: receiver.name,
          combo: effectiveCombo,
          multiplier: multiplier,
          rewardCoinAmount: rewardCoinAmount,
          endAlignment: _receiverAlignment(receiver, roomUsers),
        );
      }
      MiniProfileEconomyService.instance.clearCache();
      unawaited(refreshCoinBalance());
    } catch (error) {
      onToast(error.toString().replaceFirst('Exception: ', ''));
      unawaited(refreshCoinBalance());
    } finally {
      luckyGiftSendInProgress = false;
      onChanged();
    }
  }

  bool sendLuckyPacket({
    required int coinAmount,
    required int winnerCount,
    required String message,
    required List<SeatUser> roomUsers,
  }) {
    if (coinBalance < coinAmount) {
      onToast('Not enough coins');
      unawaited(refreshCoinBalance());
      return false;
    }
    coinBalance -= coinAmount;
    _setLuckyPacket(
      LuckyPacketRoomEvent(
        id: 'lucky-packet-${DateTime.now().microsecondsSinceEpoch}',
        senderName: currentUser.name,
        coinAmount: coinAmount,
        winnerCount: winnerCount,
        message: message.trim(),
        phase: LuckyPacketPhase.countdown,
        remainingSeconds: 30,
      ),
    );
    _luckyPacketTimer?.cancel();
    _luckyPacketTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tickLuckyPacket(roomUsers),
    );
    onFinalGiftMessage(
      ChatEntry(
        senderName: currentUser.name,
        senderId: currentUser.id,
        senderAvatarUrl: currentUser.avatarUrl,
        message:
            'sent a Lucky Packet worth $coinAmount coins for $winnerCount people${message.trim().isEmpty ? '' : ': ${message.trim()}'}',
        vipLevel: currentUser.vipLevel,
        sendingLevel: currentUser.sendingLevel,
        receivingLevel: currentUser.receivingLevel,
        isGift: true,
      ),
    );
    onToast('Regional Lucky Packet broadcast sent');
    onChanged();
    return true;
  }

  void claimLuckyPacket(List<SeatUser> roomUsers) {
    final packet = activeLuckyPacket;
    if (packet == null ||
        packet.phase != LuckyPacketPhase.claim ||
        packet.claimedByCurrentUser) {
      return;
    }
    final distributions = packet.distributions.isEmpty
        ? _buildLuckyPacketDistributions(packet: packet, roomUsers: roomUsers)
        : Map<String, int>.from(packet.distributions);
    final reward =
        distributions[currentUser.name] ??
        _fallbackCurrentUserReward(distributions);
    distributions[currentUser.name] = reward;
    _setLuckyPacket(
      packet.copyWith(
        claimedByCurrentUser: true,
        currentUserReward: reward,
        distributions: distributions,
      ),
    );
    onChanged();
  }

  void dismissLuckyPacketResults() {
    if (activeLuckyPacket == null) return;
    _luckyPacketTimer?.cancel();
    _luckyPacketTimer = null;
    _setLuckyPacket(null);
    onChanged();
  }

  void tapGiftCombo(GiftSlide slide) {
    if (slide.isVideoGift || slide.giftName == 'Lucky Packet') return;
    if (_isDuplicateComboTap(slide.id)) return;
    final luckyContext = _luckyComboContexts[slide.id];
    if (luckyContext != null) {
      unawaited(_triggerLuckyCombo(slide: slide, context: luckyContext));
      return;
    }

    final index = giftSlides.indexWhere((item) => item.id == slide.id);
    if (index < 0) return;
    final active = giftSlides[index];
    final nextCombo = active.combo + active.baseCombo;
    giftSlides[index] = active.copyWith(
      combo: nextCombo,
      remainingSeconds: comboTriggerSeconds,
    );
    onChanged();
  }

  bool _isDuplicateComboTap(String slideId) {
    final now = DateTime.now();
    final previous = _lastComboTapBySlideId[slideId];
    _lastComboTapBySlideId[slideId] = now;
    return previous != null &&
        now.difference(previous) < const Duration(milliseconds: 90);
  }

  Future<void> _triggerLuckyCombo({
    required GiftSlide slide,
    required _LuckyComboContext context,
  }) async {
    final comboKey =
        '${context.receiverPublicUserId}:${context.gift.id}:${context.baseCombo}';
    if (_luckyComboProcessingSlideIds.contains(slide.id) ||
        _luckyComboProcessingKeys.contains(comboKey)) {
      onToast('Lucky combo is processing');
      return;
    }
    _luckyComboProcessingSlideIds.add(slide.id);
    _luckyComboProcessingKeys.add(comboKey);
    onChanged();

    try {
      final result = await _giftApi.sendLuckyGiftPublic(
        receiverPublicUserId: context.receiverPublicUserId,
        giftId: context.gift.id,
        coinValue: context.gift.coins,
        quantity: context.baseCombo,
        roomPublicId: roomPublicId,
      );
      final multiplier =
          result.luckyMultiplier ?? result.luckyResult?.multiplier ?? 1;
      final rewardCoinAmount =
          result.luckyRewardCoinAmount ??
          result.luckyResult?.rewardCoinAmount ??
          0;
      coinBalance = result.senderCoinBalance;
      unawaited(
        _recordRelationshipGiftExpSilently(
          gift: context.gift,
          quantity: context.baseCombo,
          receiverPublicUserId: context.receiverPublicUserId,
          eventType: 'lucky_gift_combo_sent',
        ),
      );

      final activeSlideIndex = giftSlides.indexWhere(
        (item) => item.id == slide.id,
      );
      if (activeSlideIndex != -1) {
        final active = giftSlides[activeSlideIndex];
        giftSlides[activeSlideIndex] = active.copyWith(
          combo: active.combo + context.baseCombo,
          remainingSeconds: comboTriggerSeconds,
        );
        _luckyComboContexts[slide.id] = context;
        _publishLuckyFlight(
          slide: giftSlides[activeSlideIndex],
          gift: context.gift,
          receiverName: context.receiverName,
          combo: context.baseCombo,
          multiplier: multiplier,
          rewardCoinAmount: rewardCoinAmount,
          endAlignment: context.endAlignment,
        );
      }
      MiniProfileEconomyService.instance.clearCache();
      unawaited(refreshCoinBalance());
    } catch (error) {
      onToast(error.toString().replaceFirst('Exception: ', ''));
      unawaited(refreshCoinBalance());
    } finally {
      _luckyComboProcessingSlideIds.remove(slide.id);
      _luckyComboProcessingKeys.remove(comboKey);
      onChanged();
    }
  }

  void finishVideoGift(GiftSlide slide) {
    final index = giftSlides.indexWhere((item) => item.id == slide.id);
    if (index < 0) return;
    _giftTimers.remove(slide.id)?.cancel();
    _luckyComboContexts.remove(slide.id);
    _luckyComboProcessingSlideIds.remove(slide.id);
    _lastComboTapBySlideId.remove(slide.id);
    giftSlides.removeAt(index);
    onChanged();
  }

  void _setLuckyPacket(LuckyPacketRoomEvent? packet) {
    activeLuckyPacket = packet;
  }

  void applyAuthoritativeLuckyPacket(LuckyPacketRoomEvent? packet) {
    _luckyPacketTimer?.cancel();
    _luckyPacketTimer = null;
    _setLuckyPacket(packet);
    onChanged();
  }

  void _tickLuckyPacket(List<SeatUser> roomUsers) {
    final packet = activeLuckyPacket;
    if (packet == null) {
      _luckyPacketTimer?.cancel();
      _luckyPacketTimer = null;
      return;
    }
    if (packet.remainingSeconds > 0) {
      _setLuckyPacket(
        packet.copyWith(remainingSeconds: packet.remainingSeconds - 1),
      );
      onChanged();
      return;
    }
    switch (packet.phase) {
      case LuckyPacketPhase.countdown:
        _setLuckyPacket(
          packet.copyWith(phase: LuckyPacketPhase.claim, remainingSeconds: 20),
        );
        onChanged();
        return;
      case LuckyPacketPhase.claim:
        _setLuckyPacket(
          packet.copyWith(
            phase: LuckyPacketPhase.results,
            remainingSeconds: 6,
            distributions: packet.distributions.isEmpty
                ? _buildLuckyPacketDistributions(
                    packet: packet,
                    roomUsers: roomUsers,
                  )
                : packet.distributions,
          ),
        );
        onChanged();
        return;
      case LuckyPacketPhase.results:
        _setLuckyPacket(null);
        _luckyPacketTimer?.cancel();
        _luckyPacketTimer = null;
        onChanged();
        return;
    }
  }

  int _fallbackCurrentUserReward(Map<String, int> distributions) =>
      distributions.isEmpty ? 0 : distributions.values.first;

  Map<String, int> _buildLuckyPacketDistributions({
    required LuckyPacketRoomEvent packet,
    required List<SeatUser> roomUsers,
  }) {
    final names = <String>[
      currentUser.name,
      ...roomUsers.map((user) => user.name),
      ...List<String>.generate(
        packet.winnerCount,
        (index) => 'Vibe User ${index + 1}',
      ),
    ];
    final uniqueNames = <String>[];
    final seen = <String>{};
    for (final name in names) {
      if (seen.add(name)) uniqueNames.add(name);
      if (uniqueNames.length >= packet.winnerCount) break;
    }
    if (uniqueNames.isEmpty) return <String, int>{};
    var remaining = packet.coinAmount;
    final result = <String, int>{};
    for (var i = 0; i < uniqueNames.length; i++) {
      final slotsLeft = uniqueNames.length - i;
      final minForRest = slotsLeft - 1;
      final reward = slotsLeft == 1
          ? remaining
          : 1 + _random.nextInt(max(1, remaining - minForRest));
      result[uniqueNames[i]] = reward;
      remaining -= reward;
    }
    return result;
  }

  Future<void> _recordRelationshipGiftExpSilently({
    required GiftItem gift,
    required int quantity,
    required int receiverPublicUserId,
    required String eventType,
  }) async {
    try {
      await _relationshipExpApi.recordExpEvent(
        eventType: eventType,
        otherPublicUserId: receiverPublicUserId,
        coinValue: gift.coins * quantity,
        roomPublicId: roomPublicId,
      );
    } catch (_) {
      // Relationship EXP sync should never block the gift send flow.
    }
  }

  void _startGiftSlide(GiftSlide slide) {
    if (_isLuckyGiftSlide(slide)) {
      _removeActiveLuckySlidesExcept(slide.id);
    }

    giftSlides.insert(0, slide);
    onChanged();
    if (slide.isVideoGift) _insertFinalGiftMessage(slide);
    _giftTimers[slide.id]?.cancel();
    _giftTimers[slide.id] = Timer.periodic(const Duration(seconds: 1), (timer) {
      final index = giftSlides.indexWhere((item) => item.id == slide.id);
      if (index < 0) {
        timer.cancel();
        _giftTimers.remove(slide.id);
        _luckyComboContexts.remove(slide.id);
        _luckyComboProcessingSlideIds.remove(slide.id);
        _lastComboTapBySlideId.remove(slide.id);
        return;
      }
      final active = giftSlides[index];
      if (active.remainingSeconds <= 1) {
        timer.cancel();
        final completed = giftSlides.removeAt(index);
        _giftTimers.remove(slide.id);
        _luckyComboContexts.remove(slide.id);
        _luckyComboProcessingSlideIds.remove(slide.id);
        _lastComboTapBySlideId.remove(slide.id);
        if (!completed.isVideoGift) _insertFinalGiftMessage(completed);
        onChanged();
        return;
      }
      giftSlides[index] = active.copyWith(
        remainingSeconds: active.remainingSeconds - 1,
      );
      onChanged();
    });
  }

  void _removeActiveLuckySlidesExcept(String keepSlideId) {
    final staleLuckySlideIds = giftSlides
        .where((slide) => slide.id != keepSlideId && _isLuckyGiftSlide(slide))
        .map((slide) => slide.id)
        .toList(growable: false);
    for (final slideId in staleLuckySlideIds) {
      _giftTimers.remove(slideId)?.cancel();
      _luckyComboContexts.remove(slideId);
      _luckyComboProcessingSlideIds.remove(slideId);
      _lastComboTapBySlideId.remove(slideId);
      giftSlides.removeWhere((slide) => slide.id == slideId);
    }
    if (staleLuckySlideIds.isNotEmpty) _luckyComboProcessingKeys.clear();
  }

  void _insertFinalGiftMessage(GiftSlide slide) {
    if (!_finishedGiftMessageIds.add(slide.id)) return;
    onFinalGiftMessage(
      ChatEntry(
        senderName: slide.senderName,
        senderId: currentUser.id,
        senderAvatarUrl: currentUser.avatarUrl,
        message:
            'sent to ${slide.receiverName} ${slide.giftName} x${slide.combo}',
        vipLevel: currentUser.vipLevel,
        sendingLevel: currentUser.sendingLevel,
        receivingLevel: currentUser.receivingLevel,
        isGift: true,
        giftAssetPath: slide.giftAssetPath,
      ),
    );
  }

  GiftSlide _createLuckySlide({
    required GiftItem gift,
    required String receiverName,
    required int combo,
    required int multiplier,
  }) {
    return GiftSlide(
      id: '$receiverName-${gift.id}-${DateTime.now().microsecondsSinceEpoch}',
      senderName: currentUser.name,
      receiverName: receiverName,
      giftName: '${gift.name} x$multiplier',
      giftIcon: gift.icon,
      giftAssetPath: gift.assetPath,
      giftAssetUrl: gift.assetUrl,
      videoAssetPath: gift.videoAssetPath,
      videoUrl: gift.videoUrl,
      colors: _slideColorsForMultiplier(gift.colors, multiplier),
      combo: combo,
      baseCombo: combo,
      remainingSeconds: gift.isVideoGift ? 10 : comboTriggerSeconds,
    );
  }

  void _publishLuckyFlight({
    required GiftSlide slide,
    required GiftItem gift,
    required String receiverName,
    required int combo,
    required int multiplier,
    required int rewardCoinAmount,
    required Alignment endAlignment,
  }) {
    giftFlightBus.publish(
      GiftFlightEvent(
        id: 'flight-${slide.id}',
        gift: gift,
        senderName: currentUser.name,
        receiverName: receiverName,
        combo: combo,
        multiplier: multiplier,
        rewardCoinAmount: rewardCoinAmount,
        endAlignment: endAlignment,
      ),
    );
  }

  void _publishPremiumBroadcastIfNeeded({
    required GiftItem gift,
    required String receiverName,
    required int combo,
    required bool shouldPublish,
  }) {
    if (!shouldPublish) return;
    premiumGiftBroadcastBus.publish(
      PremiumGiftBroadcastEvent(
        id: 'premium-${gift.id}-${DateTime.now().microsecondsSinceEpoch}',
        senderName: currentUser.name,
        senderAvatarUrl: currentUser.avatarUrl,
        targetName: receiverName,
        giftName: gift.name,
        combo: combo,
        giftAssetPath: gift.assetPath,
        giftAssetUrl: gift.assetUrl,
      ),
    );
  }

  int? _publicUserIdFromSeatUser(SeatUser user) {
    final id = user.id.trim();
    final direct = int.tryParse(id);
    if (direct != null && direct > 0) return direct;
    final match = RegExp(r'(\d{7,12})').firstMatch(id);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }

  List<Color> _slideColorsForMultiplier(
    List<Color> baseColors,
    int? multiplier,
  ) {
    final value = multiplier ?? 0;
    if (value >= 1000) return const [Color(0xFF8B5CF6), Color(0xFF22D3EE)];
    if (value >= 500) return const [Color(0xFFFF2D95), Color(0xFF00E5FF)];
    if (value >= 100) return const [Color(0xFFFFD166), Color(0xFFFF8A00)];
    return baseColors;
  }

  Alignment _receiverAlignment(SeatUser? receiver, List<SeatUser> roomUsers) {
    if (receiver == null || roomUsers.isEmpty)
      return const Alignment(0.0, -0.20);
    final index = roomUsers.indexWhere((user) => user.id == receiver.id);
    if (index < 0) return const Alignment(0.68, -0.16);
    final column = index % 4;
    final row = index ~/ 4;
    final x = [-0.72, -0.24, 0.24, 0.72][column];
    final y = row == 0
        ? -0.36
        : row == 1
        ? -0.02
        : 0.22;
    return Alignment(x, y);
  }

  void dispose() {
    _userRealtimeSub?.cancel();
    _userRealtimeSub = null;
    for (final timer in _giftTimers.values) {
      timer.cancel();
    }
    _giftTimers.clear();
    _luckyComboContexts.clear();
    _luckyComboProcessingSlideIds.clear();
    _luckyComboProcessingKeys.clear();
    _lastComboTapBySlideId.clear();
    _luckyPacketTimer?.cancel();
    _luckyPacketTimer = null;
    giftFlightBus.dispose();
    premiumGiftBroadcastBus.dispose();
  }
}

class _LuckyComboContext {
  const _LuckyComboContext({
    required this.gift,
    required this.receiverPublicUserId,
    required this.receiverName,
    required this.baseCombo,
    required this.endAlignment,
  });

  final GiftItem gift;
  final int receiverPublicUserId;
  final String receiverName;
  final int baseCombo;
  final Alignment endAlignment;
}

typedef VoidCallbackLike = void Function();
typedef ValueChangedLike<T> = void Function(T value);
