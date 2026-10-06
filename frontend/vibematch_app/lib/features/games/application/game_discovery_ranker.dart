import '../data/game_api_service.dart';

List<GameDefinition> rankGameCatalog(
  List<GameDefinition> games, {
  required List<String> recentGameIds,
  required List<String> recommendedGameIds,
}) {
  final result = List<GameDefinition>.of(games);
  final recentRank = <String, int>{
    for (var index = 0; index < recentGameIds.length; index++)
      recentGameIds[index]: index,
  };
  final recommendationRank = <String, int>{
    for (var index = 0; index < recommendedGameIds.length; index++)
      recommendedGameIds[index]: index,
  };

  result.sort((a, b) {
    final recentCompare = _compareRank(
      recentRank[a.gameKey],
      recentRank[b.gameKey],
    );
    if (recentCompare != 0) return recentCompare;

    final recommendationCompare = _compareRank(
      recommendationRank[a.gameKey],
      recommendationRank[b.gameKey],
    );
    if (recommendationCompare != 0) return recommendationCompare;

    return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
  });
  return List<GameDefinition>.unmodifiable(result);
}

int _compareRank(int? a, int? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return a.compareTo(b);
}
