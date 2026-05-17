class GiftPanelConstants {
  const GiftPanelConstants._();

  static const List<int> combos = [1, 9, 69, 99, 999];
  static const List<int> luckyCombos = [9, 69, 99, 999];

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
