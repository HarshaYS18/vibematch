import 'package:shared_preferences/shared_preferences.dart';

class LoveBondsSlotsState {
  const LoveBondsSlotsState({
    required this.freeSlotCount,
    required this.paidSlotCount,
    required this.nextSlotPriceCoins,
  });

  final int freeSlotCount;
  final int paidSlotCount;
  final int nextSlotPriceCoins;

  int get totalSlotCount => freeSlotCount + paidSlotCount;

  LoveBondsSlotsState copyWith({
    int? freeSlotCount,
    int? paidSlotCount,
    int? nextSlotPriceCoins,
  }) {
    return LoveBondsSlotsState(
      freeSlotCount: freeSlotCount ?? this.freeSlotCount,
      paidSlotCount: paidSlotCount ?? this.paidSlotCount,
      nextSlotPriceCoins: nextSlotPriceCoins ?? this.nextSlotPriceCoins,
    );
  }
}

class LoveBondsSlotsStore {
  const LoveBondsSlotsStore._();

  static const int defaultFreeSlots = 4;
  static const int defaultNextSlotPriceCoins = 12000;
  static const String _paidSlotsKey = 'vm_love_bonds.paid_slot_count';
  static const String _nextSlotPriceKey = 'vm_love_bonds.next_slot_price_coins';

  static Future<LoveBondsSlotsState> load() async {
    final prefs = await SharedPreferences.getInstance();
    return LoveBondsSlotsState(
      freeSlotCount: defaultFreeSlots,
      paidSlotCount: prefs.getInt(_paidSlotsKey) ?? 0,
      nextSlotPriceCoins: prefs.getInt(_nextSlotPriceKey) ?? defaultNextSlotPriceCoins,
    );
  }

  static Future<LoveBondsSlotsState> purchaseExtraSlot(LoveBondsSlotsState current) async {
    final next = current.copyWith(
      paidSlotCount: current.paidSlotCount + 1,
      nextSlotPriceCoins: _nextPrice(current.nextSlotPriceCoins),
    );
    await save(next);
    return next;
  }

  static Future<void> save(LoveBondsSlotsState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_paidSlotsKey, state.paidSlotCount);
    await prefs.setInt(_nextSlotPriceKey, state.nextSlotPriceCoins);
  }

  static int _nextPrice(int currentPrice) {
    // Backend will decide this later. Local fallback increases gently for testing.
    return (currentPrice * 1.25).round();
  }
}
