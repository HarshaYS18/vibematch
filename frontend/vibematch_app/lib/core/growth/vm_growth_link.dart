enum VmGrowthDestination {
  room('room'),
  vibe('vibe'),
  profile('profile'),
  game('game'),
  event('event'),
  family('family');

  const VmGrowthDestination(this.segment);
  final String segment;

  static VmGrowthDestination? fromSegment(String value) {
    final normalized = value.trim().toLowerCase();
    for (final destination in values) {
      if (destination.segment == normalized) return destination;
    }
    return null;
  }
}

class VmGrowthLink {
  const VmGrowthLink({
    required this.destination,
    required this.id,
    required this.uri,
    this.referrerId,
    this.inviteToken,
  });

  final VmGrowthDestination destination;
  final String id;
  final Uri uri;
  final String? referrerId;
  final String? inviteToken;
}

class VmGrowthLinks {
  const VmGrowthLinks._();

  static const String configuredShareBaseUrl = String.fromEnvironment(
    'FUNKEY_SHARE_BASE_URL',
    defaultValue: '',
  );

  static Uri room(String roomId, {String? referrerId}) =>
      build(VmGrowthDestination.room, roomId, referrerId: referrerId);

  static Uri vibe(String vibeId, {String? referrerId}) =>
      build(VmGrowthDestination.vibe, vibeId, referrerId: referrerId);

  static Uri profile(String publicUserId, {String? referrerId}) =>
      build(VmGrowthDestination.profile, publicUserId, referrerId: referrerId);

  static Uri game(String gameId, {String? referrerId}) =>
      build(VmGrowthDestination.game, gameId, referrerId: referrerId);

  static Uri event(String eventId, {String? referrerId}) =>
      build(VmGrowthDestination.event, eventId, referrerId: referrerId);

  static Uri family(
    String familyId, {
    String? referrerId,
    String? inviteToken,
  }) =>
      build(
        VmGrowthDestination.family,
        familyId,
        referrerId: referrerId,
        inviteToken: inviteToken,
      );

  static Uri build(
    VmGrowthDestination destination,
    String id, {
    String? referrerId,
    String? inviteToken,
  }) {
    final cleanId = id.trim();
    if (cleanId.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Growth link id cannot be empty.');
    }
    final query = <String, String>{
      if (referrerId != null && referrerId.trim().isNotEmpty)
        'ref': referrerId.trim(),
      if (inviteToken != null && inviteToken.trim().isNotEmpty)
        'invite': inviteToken.trim(),
    };

    final configuredBase = Uri.tryParse(configuredShareBaseUrl.trim());
    if (configuredBase != null &&
        (configuredBase.scheme == 'https' || configuredBase.scheme == 'http') &&
        configuredBase.host.isNotEmpty) {
      final baseSegments =
          configuredBase.pathSegments.where((segment) => segment.isNotEmpty);
      return configuredBase.replace(
        pathSegments: <String>[
          ...baseSegments,
          destination.segment,
          cleanId,
        ],
        queryParameters: query.isEmpty ? null : query,
      );
    }

    return Uri(
      scheme: 'funkey',
      host: destination.segment,
      pathSegments: <String>[cleanId],
      queryParameters: query.isEmpty ? null : query,
    );
  }

  static VmGrowthLink? parse(Uri uri) {
    String? destinationSegment;
    List<String> remainingSegments = const <String>[];

    if (uri.scheme.toLowerCase() == 'funkey') {
      destinationSegment = uri.host;
      remainingSegments =
          uri.pathSegments.where((item) => item.isNotEmpty).toList();
    } else if (uri.scheme == 'https' || uri.scheme == 'http') {
      final configuredBase = Uri.tryParse(configuredShareBaseUrl.trim());
      if (configuredBase == null ||
          configuredBase.host.isEmpty ||
          configuredBase.host.toLowerCase() != uri.host.toLowerCase()) {
        return null;
      }
      final baseSegments = configuredBase.pathSegments
          .where((segment) => segment.isNotEmpty)
          .toList();
      final incoming =
          uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
      if (incoming.length <= baseSegments.length) return null;
      for (var index = 0; index < baseSegments.length; index++) {
        if (incoming[index] != baseSegments[index]) return null;
      }
      destinationSegment = incoming[baseSegments.length];
      remainingSegments = incoming.skip(baseSegments.length + 1).toList();
    } else {
      return null;
    }

    final destination =
        VmGrowthDestination.fromSegment(destinationSegment ?? '');
    if (destination == null || remainingSegments.isEmpty) return null;

    final id = remainingSegments.first.trim();
    if (id.isEmpty || id.length > 256) return null;

    final referrer = uri.queryParameters['ref']?.trim();
    final invite = uri.queryParameters['invite']?.trim();

    return VmGrowthLink(
      destination: destination,
      id: id,
      uri: uri,
      referrerId: referrer == null || referrer.isEmpty ? null : referrer,
      inviteToken: invite == null || invite.isEmpty ? null : invite,
    );
  }
}
