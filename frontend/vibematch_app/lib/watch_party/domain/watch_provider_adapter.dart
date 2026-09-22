import 'watch_party_state.dart';

class WatchProviderCapabilities {
  const WatchProviderCapabilities({
    required this.embeddedPlayback,
    required this.programmaticPlay,
    required this.programmaticPause,
    required this.programmaticSeek,
    required this.programmaticPosition,
    required this.playbackRateControl,
    required this.externalLaunch,
  });

  final bool embeddedPlayback;
  final bool programmaticPlay;
  final bool programmaticPause;
  final bool programmaticSeek;
  final bool programmaticPosition;
  final bool playbackRateControl;
  final bool externalLaunch;
}

abstract interface class WatchProviderAdapter {
  String get providerId;
  WatchProviderCapabilities get capabilities;

  Future<void> load(WatchSession session);
  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(int positionMs);
  Future<void> setPlaybackRate(double playbackRate);
  Future<int> currentPositionMs();
  Future<void> dispose();
}
