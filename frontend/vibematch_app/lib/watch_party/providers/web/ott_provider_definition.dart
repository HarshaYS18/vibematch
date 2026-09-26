import '../../domain/watch_party_state.dart';

class OttProviderDefinition {
  const OttProviderDefinition({
    required this.id,
    required this.displayName,
    required this.homeUri,
    required this.allowedHosts,
    required this.liveContentSupported,
  });

  final String id;
  final String displayName;
  final Uri homeUri;
  final Set<String> allowedHosts;
  final bool liveContentSupported;

  Uri? normalizeContentInput(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.userInfo.isNotEmpty ||
        !_hostAllowed(uri.host)) {
      return null;
    }
    return uri;
  }

  Uri resolveSessionUri(WatchSession session) {
    final contentUrl = session.contentUrl?.trim() ?? '';
    return normalizeContentInput(contentUrl) ?? homeUri;
  }

  bool _hostAllowed(String rawHost) {
    final host = rawHost.trim().toLowerCase();
    return allowedHosts.any(
      (allowed) => host == allowed || host.endsWith('.$allowed'),
    );
  }
}

class OttProviderCatalog {
  const OttProviderCatalog._();

  static final OttProviderDefinition netflix = OttProviderDefinition(
    id: 'netflix',
    displayName: 'Netflix',
    homeUri: Uri.parse('https://www.netflix.com/'),
    allowedHosts: const {'netflix.com'},
    liveContentSupported: false,
  );

  static final OttProviderDefinition primeVideo = OttProviderDefinition(
    id: 'prime_video',
    displayName: 'Prime Video',
    homeUri: Uri.parse('https://www.primevideo.com/'),
    allowedHosts: const {'primevideo.com', 'amazon.com'},
    liveContentSupported: true,
  );

  static final OttProviderDefinition jioHotstar = OttProviderDefinition(
    id: 'jiohotstar',
    displayName: 'JioHotstar',
    homeUri: Uri.parse('https://www.jiohotstar.com/'),
    allowedHosts: const {'jiohotstar.com', 'hotstar.com'},
    liveContentSupported: true,
  );

  static List<OttProviderDefinition> get all =>
      <OttProviderDefinition>[netflix, primeVideo, jioHotstar];

  static OttProviderDefinition? byId(String raw) {
    final normalized = raw.trim().toLowerCase().replaceAll('-', '_');
    for (final provider in all) {
      if (provider.id == normalized) return provider;
    }
    if (normalized == 'primevideo' || normalized == 'prime') {
      return primeVideo;
    }
    if (normalized == 'hotstar' || normalized == 'jio_hotstar') {
      return jioHotstar;
    }
    return null;
  }
}
