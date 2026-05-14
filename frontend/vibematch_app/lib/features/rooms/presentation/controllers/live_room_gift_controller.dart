import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Alignment, Color;

import '../../../wallet/data/wallet_api_service.dart';
import '../../data/active_room_context.dart';
import '../../data/gift_api_service.dart';
import '../../data/live_room_media_signaling_service.dart';
import '../live_room_models.dart';
import '../widgets/gift_flight_bus.dart';
import '../widgets/gift_flight_overlay.dart';

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

class LuckyPacketRoomBus {
  const LuckyPacketRoomBus._();

  static final ValueNotifier<LuckyPacketRoomEvent?> packet = ValueNotifier<LuckyPacketRoomEvent?>(null);
  static LiveRoomGiftController? _controller;
  static List<SeatUser> _roomUsers = const <SeatUser>[];

  static void bind({required LiveRoomGiftController controller, required List<SeatUser> roomUsers}) {
    _controller = controller;
    _roomUsers = roomUsers;
    packet.value = controller.activeLuckyPacket;
  }

  static void publish(LuckyPacketRoomEvent? event) {
    packet.value = event;
  }

  static void claim() {
    _controller?.claimLuckyPacket(_roomUsers);
  }

  static void dismissResults() {
    _controller?.dismissLuckyPacketResults();
  }

  static void clearController(LiveRoomGiftController controller) {
    if (_controller != controller) return;
    _controller = null;
    _roomUsers = const <SeatUser>[];
    packet.value = null;
  }
}

class LiveRoomGiftController {
  LiveRoomGiftController({
    required SeatUser currentUser,
    required this.onChanged,
    required this.onFinalGiftMessage,
    required this.onToast,
  }) : currentUser = LiveRoomMediaSignalingService.instance.effectiveCurrentUser(currentUser) {
    unawaited(refreshCoinBalance());
  }

  static const int smallGiftFlightThreshold = 200000;

  final SeatUser currentUser;
  final VoidCallbackLike onChanged;
  final ValueChangedLike<ChatEntry> onFinalGiftMessage;
  final ValueChangedLike<String> onToast;
  final WalletApiService _walletApi = const WalletApiService();
  final GiftApiService _giftApi = const GiftApiService();

  GiftCategory selectedCategory = GiftCategory.premium;
  GiftItem? selectedGift = mockGiftItems.isEmpty ? null : mockGiftItems.first;
  final Set<String> selectedReceiverIds = <String>{};
  int selectedCombo = 1;
  int coinBalance = 0;
  bool luckyGiftSendInProgress = false;

  final List<GiftSlide> giftSlides = <GiftSlide>[];
  final Map<String, Timer> _giftTimers = <String, Timer>{};
  final Set<String> _finishedGiftMessageIds = <String>{};

  LuckyPacketRoomEvent? activeLuckyPacket;
  Timer? _luckyPacketTimer;
  final Random _random = Random();

  bool get selectedGiftIsLuckyPacket => selectedGift?.id == 'lucky_packet';

  Future<void> refreshCoinBalance() async {
    try {
      final wallet = await _walletApi.getWallet();
      coinBalance = wallet.coinBalance;
      onChanged();
    } catch (_) {
      // Keep the current visible value. Do not fall back to mock coins.
    }
  }

  GiftSlide? get activeComboSlide {
    final normalSlides = giftSlides.where((slide) => !slide.isVideoGift && slide.giftName != 'Lucky Packet').toList(growable: false);
    return normalSlides.isEmpty ? null : normalSlides.first;
  }

  void ensureDefaultReceiver(List<SeatUser> roomUsers) {
    if (selectedReceiverIds.isEmpty && roomUsers.isNotEmpty) selectedReceiverIds.add(roomUsers.first.id);
    if (selectedGift == null && mockGiftItems.isNotEmpty) selectedGift = mockGiftItems.first;
  }

  void selectCategory(GiftCategory category) {
    selectedCategory = category;
    final categoryGifts = mockGiftItems.where((gift) => gift.category == category).toList();
    selectedGift = categoryGifts.isNotEmpty ? categoryGifts.first : null;
    selectedCombo = category == GiftCategory.lucky ? 9 : 1;
    if (selectedGiftIsLuckyPacket) selectedCombo = 1;
    onChanged();
  }

  void selectGift(GiftItem gift) {
    selectedGift = gift;
    selectedCategory = gift.category;
    selectedCombo = gift.id == 'lucky_packet' ? 1 : (gift.category == GiftCategory.lucky ? 9 : 1);
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
    final receivers = roomUsers.where((user) => selectedReceiverIds.contains(user.id)).toList();
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

    if (gift.category == GiftCategory.lucky) {
      unawaited(_sendLuckyGift(gift: gift, receivers: receivers, roomUsers: roomUsers, effectiveCombo: effectiveCombo));
      return;
    }

    coinBalance -= totalCost;
    final sentToAll = !gift.isVideoGift && receivers.length == roomUsers.length && roomUsers.isNotEmpty;
    final targets = sentToAll ? <SeatUser?>[null] : receivers.cast<SeatUser?>();
    final deliveredCombo = sentToAll ? effectiveCombo * receivers.length : effectiveCombo;
    for (final receiver in targets) {
      final slide = GiftSlide(
        id: '${receiver?.id ?? 'all'}-${DateTime.now().microsecondsSinceEpoch}',
        senderName: currentUser.name,
        receiverName: receiver?.name ?? 'all',
        giftName: gift.name,
        giftIcon: gift.icon,
        giftAssetPath: gift.assetPath,
        videoAssetPath: gift.videoAssetPath,
        colors: gift.colors,
        combo: deliveredCombo,
        baseCombo: deliveredCombo,
        remainingSeconds: gift.isVideoGift ? 10 : 15,
      );
      _startGiftSlide(slide);

      final shouldFly = (gift.coins * deliveredCombo) < smallGiftFlightThreshold;
      if (shouldFly) {
        GiftFlightBus.publish(
          GiftFlightEvent(
            id: 'flight-${slide.id}',
            gift: gift,
            senderName: currentUser.name,
            receiverName: receiver?.name ?? 'all',
            combo: deliveredCombo,
            endAlignment: _receiverAlignment(receiver, roomUsers),
          ),
        );
      }
    }
    onChanged();
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
          roomPublicId: ActiveRoomContext.roomPublicId,
        );

        final multiplier = result.luckyMultiplier ?? result.luckyResult?.multiplier ?? 1;
        final rewardCoinAmount = result.luckyRewardCoinAmount ?? result.luckyResult?.rewardCoinAmount ?? 0;
        coinBalance = result.senderCoinBalance;
        final slideColors = _slideColorsForMultiplier(gift.colors, multiplier);
        final slide = GiftSlide(
          id: '${receiver.id}-${DateTime.now().microsecondsSinceEpoch}',
          senderName: currentUser.name,
          receiverName: receiver.name,
          giftName: '${gift.name} x$multiplier',
          giftIcon: gift.icon,
          giftAssetPath: gift.assetPath,
          videoAssetPath: gift.videoAssetPath,
          colors: slideColors,
          combo: effectiveCombo,
          baseCombo: effectiveCombo,
          remainingSeconds: gift.isVideoGift ? 10 : 15,
        );
        _startGiftSlide(slide);
        GiftFlightBus.publish(
          GiftFlightEvent(
            id: 'flight-${slide.id}',
            gift: gift,
            senderName: currentUser.name,
            receiverName: receiver.name,
            combo: effectiveCombo,
            multiplier: multiplier,
            rewardCoinAmount: rewardCoinAmount,
            endAlignment: _receiverAlignment(receiver, roomUsers),
          ),
        );
      }
    } catch (error) {
      onToast(error.toString().replaceFirst('Exception: ', ''));
      unawaited(refreshCoinBalance());
    } finally {
      luckyGiftSendInProgress = false;
      onChanged();
    }
  }

  bool sendLuckyPacket({required int coinAmount, required int winnerCount, required String message, required List<SeatUser> roomUsers}) {
    LuckyPacketRoomBus.bind(controller: this, roomUsers: roomUsers);
    if (coinBalance < coinAmount) {
      onToast('Not enough coins');
      unawaited(refreshCoinBalance());
      return false;
    }
    coinBalance -= coinAmount;
    _setLuckyPacket(LuckyPacketRoomEvent(id: 'lucky-packet-${DateTime.now().microsecondsSinceEpoch}', senderName: currentUser.name, coinAmount: coinAmount, winnerCount: winnerCount, message: message.trim(), phase: LuckyPacketPhase.countdown, remainingSeconds: 30));
    _luckyPacketTimer?.cancel();
    _luckyPacketTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tickLuckyPacket(roomUsers));
    onFinalGiftMessage(ChatEntry(senderName: currentUser.name, senderId: currentUser.id, senderAvatarUrl: currentUser.avatarUrl, message: 'sent a Lucky Packet worth $coinAmount coins for $winnerCount people${message.trim().isEmpty ? '' : ': ${message.trim()}'}', vipLevel: currentUser.vipLevel, sendingLevel: currentUser.sendingLevel, receivingLevel: currentUser.receivingLevel, isGift: true));
    onToast('Regional Lucky Packet broadcast sent');
    onChanged();
    return true;
  }

  void claimLuckyPacket(List<SeatUser> roomUsers) {
    final packet = activeLuckyPacket;
    if (packet == null || packet.phase != LuckyPacketPhase.claim || packet.claimedByCurrentUser) return;
    final distributions = packet.distributions.isEmpty ? _buildLuckyPacketDistributions(packet: packet, roomUsers: roomUsers) : Map<String, int>.from(packet.distributions);
    final reward = distributions[currentUser.name] ?? _fallbackCurrentUserReward(distributions);
    distributions[currentUser.name] = reward;
    _setLuckyPacket(packet.copyWith(claimedByCurrentUser: true, currentUserReward: reward, distributions: distributions));
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
    final index = giftSlides.indexWhere((item) => item.id == slide.id);
    if (index < 0) return;
    final active = giftSlides[index];
    final nextCombo = active.combo + active.baseCombo;
    giftSlides[index] = active.copyWith(combo: nextCombo, remainingSeconds: 15);
    onChanged();
  }

  void finishVideoGift(GiftSlide slide) {
    final index = giftSlides.indexWhere((item) => item.id == slide.id);
    if (index < 0) return;
    _giftTimers.remove(slide.id)?.cancel();
    giftSlides.removeAt(index);
    onChanged();
  }

  void _setLuckyPacket(LuckyPacketRoomEvent? packet) {
    activeLuckyPacket = packet;
    LuckyPacketRoomBus.publish(packet);
  }

  void _tickLuckyPacket(List<SeatUser> roomUsers) {
    final packet = activeLuckyPacket;
    if (packet == null) {
      _luckyPacketTimer?.cancel();
      _luckyPacketTimer = null;
      LuckyPacketRoomBus.publish(null);
      return;
    }
    if (packet.remainingSeconds > 0) {
      _setLuckyPacket(packet.copyWith(remainingSeconds: packet.remainingSeconds - 1));
      onChanged();
      return;
    }
    switch (packet.phase) {
      case LuckyPacketPhase.countdown:
        _setLuckyPacket(packet.copyWith(phase: LuckyPacketPhase.claim, remainingSeconds: 20));
        onChanged();
        return;
      case LuckyPacketPhase.claim:
        _setLuckyPacket(packet.copyWith(phase: LuckyPacketPhase.results, remainingSeconds: 6, distributions: packet.distributions.isEmpty ? _buildLuckyPacketDistributions(packet: packet, roomUsers: roomUsers) : packet.distributions));
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

  int _fallbackCurrentUserReward(Map<String, int> distributions) => distributions.isEmpty ? 0 : distributions.values.first;

  Map<String, int> _buildLuckyPacketDistributions({required LuckyPacketRoomEvent packet, required List<SeatUser> roomUsers}) {
    final names = <String>[currentUser.name, ...roomUsers.map((user) => user.name), ...List<String>.generate(packet.winnerCount, (index) => 'Vibe User ${index + 1}')];
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
      final reward = slotsLeft == 1 ? remaining : 1 + _random.nextInt(max(1, remaining - minForRest));
      result[uniqueNames[i]] = reward;
      remaining -= reward;
    }
    return result;
  }

  void _startGiftSlide(GiftSlide slide) {
    giftSlides.insert(0, slide);
    onChanged();
    if (slide.isVideoGift) _insertFinalGiftMessage(slide);
    _giftTimers[slide.id]?.cancel();
    _giftTimers[slide.id] = Timer.periodic(const Duration(seconds: 1), (timer) {
      final index = giftSlides.indexWhere((item) => item.id == slide.id);
      if (index < 0) {
        timer.cancel();
        _giftTimers.remove(slide.id);
        return;
      }
      final active = giftSlides[index];
      if (active.remainingSeconds <= 0) {
        timer.cancel();
        giftSlides.removeAt(index);
        _giftTimers.remove(slide.id);
        if (!active.isVideoGift) _insertFinalGiftMessage(active);
        onChanged();
        return;
      }
      giftSlides[index] = active.copyWith(remainingSeconds: active.remainingSeconds - 1);
      onChanged();
    });
  }

  void _insertFinalGiftMessage(GiftSlide slide) {
    if (!_finishedGiftMessageIds.add(slide.id)) return;
    onFinalGiftMessage(ChatEntry(senderName: slide.senderName, senderId: currentUser.id, senderAvatarUrl: currentUser.avatarUrl, message: 'sent to ${slide.receiverName} ${slide.giftName} x${slide.combo}', vipLevel: currentUser.vipLevel, sendingLevel: currentUser.sendingLevel, receivingLevel: currentUser.receivingLevel, isGift: true, giftAssetPath: slide.giftAssetPath));
  }

  int? _publicUserIdFromSeatUser(SeatUser user) {
    final id = user.id.trim();
    final direct = int.tryParse(id);
    if (direct != null && direct > 0) return direct;
    final match = RegExp(r'(\d{7,12})').firstMatch(id);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }

  List<Color> _slideColorsForMultiplier(List<Color> baseColors, int? multiplier) {
    final value = multiplier ?? 0;
    if (value >= 1000) return const [Color(0xFF8B5CF6), Color(0xFF22D3EE)];
    if (value >= 500) return const [Color(0xFFFF2D95), Color(0xFF00E5FF)];
    if (value >= 100) return const [Color(0xFFFFD166), Color(0xFFFF8A00)];
    return baseColors;
  }

  Alignment _receiverAlignment(SeatUser? receiver, List<SeatUser> roomUsers) {
    if (receiver == null || roomUsers.isEmpty) return const Alignment(0.0, -0.20);
    final index = roomUsers.indexWhere((user) => user.id == receiver.id);
    if (index < 0) return const Alignment(0.68, -0.16);
    final column = index % 4;
    final row = index ~/ 4;
    final x = [-0.72, -0.24, 0.24, 0.72][column];
    final y = row == 0 ? -0.36 : row == 1 ? -0.02 : 0.22;
    return Alignment(x, y);
  }

  void dispose() {
    for (final timer in _giftTimers.values) {
      timer.cancel();
    }
    _giftTimers.clear();
    _luckyPacketTimer?.cancel();
    _luckyPacketTimer = null;
    LuckyPacketRoomBus.clearController(this);
  }
}

typedef VoidCallbackLike = void Function();
typedef ValueChangedLike<T> = void Function(T value);
