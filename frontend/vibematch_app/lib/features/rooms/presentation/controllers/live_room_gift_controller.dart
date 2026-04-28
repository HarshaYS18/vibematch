import 'dart:async';

import '../live_room_models.dart';

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

  GiftSlide? get activeComboSlide {
    return giftSlides.isEmpty ? null : giftSlides.first;
  }

  void ensureDefaultReceiver(List<SeatUser> roomUsers) {
    if (selectedReceiverIds.isEmpty && roomUsers.isNotEmpty) {
      selectedReceiverIds.add(roomUsers.first.id);
    }
  }

  void selectCategory(GiftCategory category) {
    selectedCategory = category;

    final categoryGifts = mockGiftItems
        .where((gift) => gift.category == category)
        .toList();

    if (categoryGifts.isNotEmpty) {
      selectedGift = categoryGifts.first;
    }

    if (category == GiftCategory.lucky && selectedCombo < 9) {
      selectedCombo = 9;
    }

    onChanged();
  }

  void selectGift(GiftItem gift) {
    selectedGift = gift;
    selectedCategory = gift.category;

    if (gift.category == GiftCategory.lucky && selectedCombo < 9) {
      selectedCombo = 9;
    }

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
    selectedCombo = combo;
    onChanged();
  }

  void sendGift(List<SeatUser> roomUsers) {
    final gift = selectedGift;
    if (gift == null) return;

    final receivers = roomUsers
        .where((user) => selectedReceiverIds.contains(user.id))
        .toList();

    if (receivers.isEmpty) {
      onToast('Select a receiver');
      return;
    }

    final totalCost = gift.coins * selectedCombo * receivers.length;

    if (coinBalance < totalCost) {
      onToast('Not enough coins');
      return;
    }

    coinBalance -= totalCost;
    onChanged();

    final sentToAll = receivers.length == roomUsers.length && roomUsers.isNotEmpty;
    final targets = sentToAll ? <SeatUser?>[null] : receivers.cast<SeatUser?>();

    for (final receiver in targets) {
      final slide = GiftSlide(
        id: '${receiver?.id ?? 'all'}-${DateTime.now().microsecondsSinceEpoch}',
        senderName: currentUser.name,
        receiverName: receiver?.name ?? 'all',
        giftName: gift.name,
        giftIcon: gift.icon,
        colors: gift.colors,
        combo: selectedCombo,
        baseCombo: selectedCombo,
        remainingSeconds: 15,
      );
      _startGiftSlide(slide);
    }
  }

  void tapGiftCombo(GiftSlide slide) {
    final index = giftSlides.indexWhere((item) => item.id == slide.id);
    if (index < 0) return;

    final active = giftSlides[index];
    final nextCombo = active.combo + active.baseCombo;

    giftSlides[index] = active.copyWith(
      combo: nextCombo,
      remainingSeconds: 15,
    );
    onChanged();
  }

  void _startGiftSlide(GiftSlide slide) {
    giftSlides.insert(0, slide);
    onChanged();

    _giftTimers[slide.id]?.cancel();
    _giftTimers[slide.id] = Timer.periodic(const Duration(seconds: 1), (timer) {
      final index = giftSlides.indexWhere((item) => item.id == slide.id);

      if (index < 0) {
        timer.cancel();
        return;
      }

      final active = giftSlides[index];

      if (active.remainingSeconds <= 1) {
        timer.cancel();
        giftSlides.removeAt(index);
        _giftTimers.remove(slide.id);
        _insertFinalGiftMessage(active);
        onChanged();
        return;
      }

      giftSlides[index] = active.copyWith(
        remainingSeconds: active.remainingSeconds - 1,
      );
      onChanged();
    });
  }

  void _insertFinalGiftMessage(GiftSlide slide) {
    if (!_finishedGiftMessageIds.add(slide.id)) return;

    onFinalGiftMessage(
      ChatEntry(
        senderName: slide.senderName,
        senderId: currentUser.id,
        message: 'sent to ${slide.receiverName} 🎁 x${slide.combo}',
        vipLevel: currentUser.vipLevel,
        sendingLevel: currentUser.sendingLevel,
        receivingLevel: currentUser.receivingLevel,
        isGift: true,
      ),
    );
  }

  void dispose() {
    for (final timer in _giftTimers.values) {
      timer.cancel();
    }
  }
}

typedef VoidCallbackLike = void Function();
typedef ValueChangedLike<T> = void Function(T value);
