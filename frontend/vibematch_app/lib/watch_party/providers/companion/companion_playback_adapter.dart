import 'package:url_launcher/url_launcher.dart';

import '../../domain/watch_party_state.dart';
import '../../domain/watch_provider_adapter.dart';
import '../web/ott_provider_definition.dart';

typedef ExternalUriLauncher = Future<bool> Function(Uri uri);

class CompanionPlaybackAdapter
    implements WatchProviderAdapter, ExternalWatchProviderAdapter {
  CompanionPlaybackAdapter({
    required OttProviderDefinition provider,
    ExternalUriLauncher? launcher,
  }) : _provider = provider,
       _launcher = launcher ?? _defaultExternalLauncher;

  final OttProviderDefinition _provider;
  final ExternalUriLauncher _launcher;
  WatchSession? _session;
  bool _disposed = false;

  @override
  String get providerId => _provider.id;

  @override
  WatchProviderCapabilities get capabilities =>
      const WatchProviderCapabilities(
        embeddedPlayback: false,
        programmaticPlay: false,
        programmaticPause: false,
        programmaticSeek: false,
        programmaticPosition: false,
        playbackRateControl: false,
        fineGrainedPlaybackRateControl: false,
        liveTimelineAvailable: false,
        liveResync: false,
        manualPlayPause: false,
        manualSeek: false,
        externalLaunch: true,
      );

  @override
  Future<void> load(WatchSession session) async {
    if (_disposed) throw StateError('Companion adapter has been disposed.');
    if (session.provider.trim().toLowerCase() != providerId) {
      throw StateError(
        'Companion adapter $providerId cannot load ${session.provider}.',
      );
    }
    _session = session;
  }

  @override
  Future<bool> launchExternal() async {
    final session = _session;
    final uri = session == null
        ? _provider.homeUri
        : _provider.resolveSessionUri(session);
    return _launcher(uri);
  }

  @override
  Future<void> restoreAfterExternalLaunch() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> seekTo(int positionMs) async {}

  @override
  Future<void> setPlaybackRate(double playbackRate) async {}

  @override
  Future<int> currentPositionMs() async => _session?.positionMs ?? 0;

  @override
  Future<void> dispose() async {
    _disposed = true;
    _session = null;
  }

  static Future<bool> _defaultExternalLauncher(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
