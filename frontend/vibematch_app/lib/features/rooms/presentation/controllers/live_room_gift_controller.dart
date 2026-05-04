import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../live_room_models.dart';

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
    required this.currentUser,
    required this.onChanged,
    required this.onFinalGiftMessage,
    required this.onToast,
  });

  final SeatUser currentUser;
  final VoidCallbackLike onChanged;
  final ValueChangedLike<ChatEntry> onFinalGiftMessage;
  final ValueChangedLike<String> onToast;

  GiftCategory selectedCategory = GiftCategory.classic;
  GiftItem? selectedGift = mockGiftItems.first;
  final Set<String> selectedReceiverIds = <String>{};
  int selectedCombo = 1;
  int coinBalance = 35494;

  final List<GiftSlide> giftSlides = <GiftSlide>[];
  final Map<String, Timer> _giftTimers = <String, Timer>{};
  final Set<String> _finishedGiftMessageIds = <String>{};

  LuckyPacketRoomEvent? activeLuckyPacket;
  Timer? _luckyPacketTimer;
  final Random _random = Random();

  bool get selectedGiftIsLuckyPacket => selectedGift?.id == 'lucky_packet';

  GiftSlide? get activeComboSlide {
    final normalSlides = giftSlides
        .where((slide) => !slide.isVideoGift && slide.giftName != 'Lucky Packet')
        .toList(growable: false);
    return normalSlides.isEmpty ? null : normalSlides.first;
  }

  void ensureDefaultReceiver(List<SeatUser> roomUsers) {
    if (selectedReceiverIds.isEmpty && roomUsers.isNotEmpty) {
      selectedReceiverIds.add(roomUsers.first.id);
    }
  }

  void selectCategory(GiftCategory category) {
    selectedCategory = category;
    final categoryGifts = mockGiftItems.where((gift) => gift.category == category).toList();
    if (categoryGifts.isNotEmpty) selectedGift = categoryGifts.first;
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
    if (gift == null) return;

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
      return;
    }

    coinBalance -= totalCost;
    onChanged();

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
    }
  }

  bool sendLuckyPacket({
    required int coinAmount,
    required int winnerCount,
    required String message,
    required List<SeatUser> roomUsers,
  }) {
    LuckyPacketRoomBus.bind(controller: this, roomUsers: roomUsers);

    if (coinBalance < coinAmount) {
      onToast('Not enough coins');
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
    _luckyPacketTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tickLuckyPacket(roomUsers));

    onFinalGiftMessage(
      ChatEntry(
        senderName: currentUser.name,
        senderId: currentUser.id,
        message: 'sent a Lucky Packet worth $coinAmount coins for $winnerCount people${message.trim().isEmpty ? '' : ': ${message.trim()}'}',
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
    if (packet == null || packet.phase != LuckyPacketPhase.claim || packet.claimedByCurrentUser) return;

    final distributions = packet.distributions.isEmpty
        ? _buildLuckyPacketDistributions(packet: packet, roomUsers: roomUsers)
        : Map<String, int>.from(packet.distributions);
    final reward = distributions[currentUser.name] ?? _fallbackCurrentUserReward(distributions);
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
        _setLuckyPacket(
          packet.copyWith(
            phase: LuckyPacketPhase.results,
            remainingSeconds: 6,
            distributions: packet.distributions.isEmpty
                ? _buildLuckyPacketDistributions(packet: packet, roomUsers: roomUsers)
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

  int _fallbackCurrentUserReward(Map<String, int> distributions) {
    if (distributions.isEmpty) return 0;
    return distributions.values.first;
  }

  Map<String, int> _buildLuckyPacketDistributions({
    required LuckyPacketRoomEvent packet,
    required List<SeatUser> roomUsers,
  }) {
    final names = <String>[
      currentUser.name,
      ...roomUsers.map((user) => user.name),
      ...List<String>.generate(packet.winnerCount, (index) => 'Vibe User ${index + 1}'),
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
      final reward = slotsLeft == 1 ? remaining : 1 + _random.nextInt(max(1, remaining - minForRest));
      result[uniqueNames[i]] = reward;
      remaining -= reward;
    }
    return result;
  }

  void _startGiftSlide(GiftSlide slide) {
    giftSlides.insert(0, slide);
    onChanged();

    if (slide.isVideoGift) {
      _insertFinalGiftMessage(slide);
    }

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
    onFinalGiftMessage(
      ChatEntry(
        senderName: slide.senderName,
        senderId: currentUser.id,
        message: 'sent to ${slide.receiverName} ${slide.giftName} x${slide.combo}',
        vipLevel: currentUser.vipLevel,
        sendingLevel: currentUser.sendingLevel,
        receivingLevel: currentUser.receivingLevel,
        isGift: true,
        giftAssetPath: slide.giftAssetPath,
      ),
    );
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
