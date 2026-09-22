import 'watch_party_state.dart';

class WatchProviderCapabilities {
  const WatchProviderCapabilities({
    required this.embeddedPlayback,
    required this.programmaticPlay,
    required this.programmaticPause,
    required this.programmaticSeek,
    required this.programmaticPosition,
    required this.playbackRateControl,
    this.fineGrainedPlaybackRateControl = true,
    required this.externalLaunch,
  });

  final bool embeddedPlayback;
  final bool programmaticPlay;
  final bool programmaticPause;
  final bool programmaticSeek;
  final bool programmaticPosition;
  final bool playbackRateControl;

  /// Whether small temporary rate changes (for example 0.95/1.05) can be
  /// applied accurately enough for drift correction.
  ///
  /// Providers such as YouTube expose playback-rate control but only at
  /// discrete supported rates, so they should set this to false and let the
  /// coordinator use an authoritative seek for medium drift.
  final bool fineGrainedPlaybackRateControl;
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
