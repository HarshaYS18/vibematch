import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/vm_failure.dart';
import '../../../core/presentation/vm_async_state.dart';
import '../../../core/ui/vm_motion.dart';
import '../../../game_platform/presentation/remote_game_player_page.dart';
import '../../discovery/data/recommendation_repository.dart';
import '../application/game_discovery_ranker.dart';
import '../data/game_api_service.dart';
import '../data/recent_games_store.dart';

/// Consumer-facing entry point for the existing remote Game Platform.
///
/// This page intentionally lists only backend-enabled games with a remote
/// manifest. Development settlement/test controls are not exposed here.
class GamesPage extends StatefulWidget {
  const GamesPage({super.key});

  @override
  State<GamesPage> createState() => _GamesPageState();
}

class _GamesPageState extends State<GamesPage> {
  final GameApiService _api = const GameApiService();
  final RecommendationRepository _recommendations = RecommendationRepository();
  final RecentGamesStore _recentGames = RecentGamesStore();

  List<GameDefinition> _games = const <GameDefinition>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final hadGames = _games.isNotEmpty;
    setState(() {
      _loading = !hadGames;
      _error = null;
    });

    try {
      final catalog = await _api.loadCatalog();
      final discovery = await Future.wait<Object?>([
        _recommendations.tryFetchCandidateIds(
          candidateKind: 'game',
          limit: 80,
        ),
        _recentGames.load(),
      ]);
      final recommendedGameIds =
          discovery[0] as List<String>? ?? const <String>[];
      final recentGameIds = discovery[1] as List<String>;

      final games = rankGameCatalog(
        catalog
            .where(
              (game) =>
                  game.isEnabled &&
                  (game.assetManifestUrl?.trim().isNotEmpty ?? false),
            )
            .toList(growable: false),
        recentGameIds: recentGameIds,
        recommendedGameIds: recommendedGameIds,
      );

      if (!mounted) return;
      setState(() {
        _games = games;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      final message = VmFailurePresentation.messageFor(
        error,
        contentLabel: 'games',
      );
      setState(() {
        _loading = false;
        _error = hadGames ? null : message;
      });
      if (hadGames) _toast(message);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF251538),
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      );
  }

  void _openGame(GameDefinition game) {
    unawaited(_recentGames.record(game.gameKey));
    Navigator.of(context).push<void>(
      VmMotion.pageRoute<void>(
        settings: RouteSettings(name: 'game:${game.gameKey}'),
        page: RemoteGamePlayerPage(gameId: game.gameKey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7F1),
        foregroundColor: const Color(0xFF251538),
        title: const Text(
          'Games',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh games',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: const Color(0xFF251538),
        child: _loading && _games.isEmpty
            ? const VmLoadingState(message: 'Loading games…')
            : _error != null && _games.isEmpty
                ? VmFailureState(
                    message: _error!,
                    contentLabel: 'games',
                    onRetry: _load,
                  )
                : _games.isEmpty
                    ? const _EmptyGamesState()
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                        itemCount: _games.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final game = _games[index];
                          return _GameCard(
                            game: game,
                            onTap: () => _openGame(game),
                          );
                        },
                      ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game, required this.onTap});

  final GameDefinition game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = game.isCoinGame
        ? 'Coin game · server-authoritative result'
        : 'Party game · remote verified bundle';

    return Semantics(
      button: true,
      label: 'Play ${game.displayName}',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFECE2D8)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF251538).withValues(alpha: 0.045),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8C5CF6), Color(0xFF12C7B7)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    game.isCoinGame
                        ? Icons.casino_rounded
                        : Icons.sports_esports_rounded,
                    color: Colors.white,
                    size: 27,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        game.displayName,
                        style: const TextStyle(
                          color: Color(0xFF251538),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF7B6A86),
                          fontSize: 11.5,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.play_circle_fill_rounded,
                  color: Color(0xFF251538),
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyGamesState extends StatelessWidget {
  const _EmptyGamesState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: const [
        SizedBox(height: 80),
        Icon(
          Icons.sports_esports_rounded,
          color: Color(0xFF8C5CF6),
          size: 48,
        ),
        SizedBox(height: 14),
        Text(
          'No games available right now',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF251538),
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 7),
        Text(
          'Enabled games appear here as soon as their verified CDN manifest is available.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF7B6A86),
            fontSize: 12.5,
            height: 1.35,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
