class YouTubeContentId {
  const YouTubeContentId._();

  static final RegExp _videoIdPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');

  static String? tryParse(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) return null;
    if (_videoIdPattern.hasMatch(raw)) return raw;

    final candidate = raw.contains('://') ? raw : 'https://$raw';
    final uri = Uri.tryParse(candidate);
    if (uri == null || uri.host.isEmpty) return null;

    final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');

    if (host == 'youtu.be') {
      return _validSegment(uri.pathSegments.isEmpty ? null : uri.pathSegments.first);
    }

    if (host == 'youtube.com' || host.endsWith('.youtube.com')) {
      final queryId = _validSegment(uri.queryParameters['v']);
      if (queryId != null) return queryId;

      if (uri.pathSegments.length >= 2) {
        final kind = uri.pathSegments.first.toLowerCase();
        if (kind == 'shorts' || kind == 'embed' || kind == 'live') {
          return _validSegment(uri.pathSegments[1]);
        }
      }
    }

    return null;
  }

  static String? _validSegment(String? value) {
    final candidate = value?.trim();
    if (candidate == null || !_videoIdPattern.hasMatch(candidate)) {
      return null;
    }
    return candidate;
  }
}
