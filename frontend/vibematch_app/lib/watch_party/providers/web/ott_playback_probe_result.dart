class OttPlaybackProbeResult {
  const OttPlaybackProbeResult({
    required this.pageSupported,
    required this.authenticated,
    required this.playerAvailable,
    required this.playbackAvailable,
    required this.positionReadable,
    required this.programmaticPlay,
    required this.programmaticPause,
    required this.programmaticSeek,
    required this.playbackRateControl,
    required this.fineGrainedPlaybackRateControl,
    required this.liveTimelineAvailable,
    required this.failureReason,
    required this.fallbackRequired,
  });

  const OttPlaybackProbeResult.unavailable({
    required String failureReason,
    bool pageSupported = false,
    bool fallbackRequired = true,
  }) : this(
         pageSupported: pageSupported,
         authenticated: false,
         playerAvailable: false,
         playbackAvailable: false,
         positionReadable: false,
         programmaticPlay: false,
         programmaticPause: false,
         programmaticSeek: false,
         playbackRateControl: false,
         fineGrainedPlaybackRateControl: false,
         liveTimelineAvailable: false,
         failureReason: failureReason,
         fallbackRequired: fallbackRequired,
       );

  final bool pageSupported;
  final bool authenticated;
  final bool playerAvailable;
  final bool playbackAvailable;
  final bool positionReadable;
  final bool programmaticPlay;
  final bool programmaticPause;
  final bool programmaticSeek;
  final bool playbackRateControl;
  final bool fineGrainedPlaybackRateControl;
  final bool liveTimelineAvailable;
  final String? failureReason;
  final bool fallbackRequired;

  bool get embeddedPlaybackReady {
    return pageSupported &&
        playerAvailable &&
        playbackAvailable &&
        positionReadable &&
        programmaticPlay &&
        programmaticPause &&
        programmaticSeek;
  }

  factory OttPlaybackProbeResult.fromMap(Map<String, dynamic> map) {
    bool flag(String key) {
      final value = map[key];
      if (value is bool) return value;
      if (value is num) return value != 0;
      return value?.toString().toLowerCase() == 'true';
    }

    final reason = map['failureReason']?.toString().trim();
    return OttPlaybackProbeResult(
      pageSupported: flag('pageSupported'),
      authenticated: flag('authenticated'),
      playerAvailable: flag('playerAvailable'),
      playbackAvailable: flag('playbackAvailable'),
      positionReadable: flag('positionReadable'),
      programmaticPlay: flag('programmaticPlay'),
      programmaticPause: flag('programmaticPause'),
      programmaticSeek: flag('programmaticSeek'),
      playbackRateControl: flag('playbackRateControl'),
      fineGrainedPlaybackRateControl: flag('fineGrainedPlaybackRateControl'),
      liveTimelineAvailable: flag('liveTimelineAvailable'),
      failureReason: reason == null || reason.isEmpty ? null : reason,
      fallbackRequired: flag('fallbackRequired'),
    );
  }
}
