import '../../live_room_models.dart';

class GiftPanelConstants {
  const GiftPanelConstants._();

  static const List<int> combos = [1, 9, 69, 99, 999];
  static const List<int> luckyCombos = [9, 69, 99, 999];

  static final Map<String, _GiftComboLimit> _comboLimitsByGiftId = <String, _GiftComboLimit>{};
  static final Map<String, String> _displayModeByGiftKey = <String, String>{};

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

  static void registerGiftDisplayMode({
    required String giftId,
    required String giftName,
    required String displayMode,
  }) {
    final mode = _cleanDisplayMode(displayMode);
    final cleanId = _normalizeGiftKey(giftId);
    final cleanName = _normalizeGiftKey(giftName);
    if (cleanId.isNotEmpty) _displayModeByGiftKey[cleanId] = mode;
    if (cleanName.isNotEmpty) _displayModeByGiftKey[cleanName] = mode;
  }

  static int minComboFor(GiftItem? gift) => _comboLimitsByGiftId[gift?.id ?? '']?.minCombo ?? 1;

  static int maxComboFor(GiftItem? gift) => _comboLimitsByGiftId[gift?.id ?? '']?.maxCombo ?? 999;

  static String displayModeForGiftName(String giftName) {
    final clean = _normalizeGiftKey(giftName.replaceAll(RegExp(r'\s+x\d+$'), ''));
    return _displayModeByGiftKey[clean] ?? 'normal';
  }

  static String displayModeForGift(GiftItem? gift) {
    if (gift == null) return 'normal';
    return _displayModeByGiftKey[_normalizeGiftKey(gift.id)] ??
        _displayModeByGiftKey[_normalizeGiftKey(gift.name)] ??
        'normal';
  }

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

  static String _cleanDisplayMode(String value) {
    final clean = value.trim().toLowerCase();
    return clean == 'large_80' ? 'large_80' : 'normal';
  }

  static String _normalizeGiftKey(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
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
  String get displayMode => GiftPanelConstants.displayModeForGift(this);
}
