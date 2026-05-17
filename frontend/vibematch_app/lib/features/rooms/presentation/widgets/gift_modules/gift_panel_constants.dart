import '../../live_room_models.dart';

class GiftPanelConstants {
  const GiftPanelConstants._();

  static const List<int> combos = [1, 9, 69, 99, 999];
  static const List<int> luckyCombos = [9, 69, 99, 999];

  static final Map<String, _GiftComboLimit> _comboLimitsByGiftId = <String, _GiftComboLimit>{};

  static void registerGiftComboLimit({
    required String giftId,
    required int minCombo,
    required int maxCombo,
  }) {
    final cleanId = giftId.trim();
    if (cleanId.isEmpty) return;
    final safeMin = minCombo < 1 ? 1 : minCombo;
    final safeMax = maxCombo < safeMin ? safeMin : maxCombo;
    _comboLimitsByGiftId[cleanId] = _GiftComboLimit(minCombo: safeMin, maxCombo: safeMax);
  }

  static int minComboFor(GiftItem? gift) => _comboLimitsByGiftId[gift?.id ?? '']?.minCombo ?? 1;

  static int maxComboFor(GiftItem? gift) => _comboLimitsByGiftId[gift?.id ?? '']?.maxCombo ?? 999;

  static List<int> allowedCombos({
    required bool isLucky,
    required int minCombo,
    required int maxCombo,
  }) {
    final safeMin = minCombo < 1 ? 1 : minCombo;
    final safeMax = maxCombo < safeMin ? safeMin : maxCombo;
    final source = isLucky ? luckyCombos : combos;
    final filtered = source.where((combo) => combo >= safeMin && combo <= safeMax).toList(growable: false);
    if (filtered.isNotEmpty) return filtered;
    return <int>[safeMin];
  }

  static int clampCombo({
    required int combo,
    required int minCombo,
    required int maxCombo,
  }) {
    final safeMin = minCombo < 1 ? 1 : minCombo;
    final safeMax = maxCombo < safeMin ? safeMin : maxCombo;
    if (combo < safeMin) return safeMin;
    if (combo > safeMax) return safeMax;
    return combo;
  }
}

class _GiftComboLimit {
  const _GiftComboLimit({required this.minCombo, required this.maxCombo});
  final int minCombo;
  final int maxCombo;
}

extension GiftItemComboLimitX on GiftItem {
  int get minCombo => GiftPanelConstants.minComboFor(this);
  int get maxCombo => GiftPanelConstants.maxComboFor(this);
}
