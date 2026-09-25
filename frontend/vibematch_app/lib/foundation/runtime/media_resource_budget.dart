import 'media_resource_lifecycle.dart';

enum MediaResourcePressureTier {
  reclaimFirst,
  reconstructable,
  interactive,
  realtimeCritical,
}

class MediaResourceBudget {
  const MediaResourceBudget({
    required this.recommendedMaxActive,
    required this.pressureTier,
    required this.rationale,
  });

  final int recommendedMaxActive;
  final MediaResourcePressureTier pressureTier;
  final String rationale;
}

abstract final class MediaResourceBudgetPolicy {
  static const Map<MediaResourceKind, MediaResourceBudget> budgets =
      <MediaResourceKind, MediaResourceBudget>{
        MediaResourceKind.vibesVideoDecoder: MediaResourceBudget(recommendedMaxActive: 1, pressureTier: MediaResourcePressureTier.reclaimFirst, rationale: 'One active Vibes decoder.'),
        MediaResourceKind.watchPartyWebView: MediaResourceBudget(recommendedMaxActive: 1, pressureTier: MediaResourcePressureTier.interactive, rationale: 'One active Watch Party WebView.'),
        MediaResourceKind.gameWebView: MediaResourceBudget(recommendedMaxActive: 1, pressureTier: MediaResourcePressureTier.interactive, rationale: 'One active game WebView.'),
        MediaResourceKind.roomWebRtc: MediaResourceBudget(recommendedMaxActive: 1, pressureTier: MediaResourcePressureTier.realtimeCritical, rationale: 'One canonical room WebRTC engine.'),
        MediaResourceKind.giftVideo: MediaResourceBudget(recommendedMaxActive: 2, pressureTier: MediaResourcePressureTier.reclaimFirst, rationale: 'Permit brief gift transition overlap.'),
        MediaResourceKind.audioInput: MediaResourceBudget(recommendedMaxActive: 2, pressureTier: MediaResourcePressureTier.realtimeCritical, rationale: 'Room and call capture may briefly overlap.'),
        MediaResourceKind.cameraInput: MediaResourceBudget(recommendedMaxActive: 1, pressureTier: MediaResourcePressureTier.realtimeCritical, rationale: 'One local call camera.'),
        MediaResourceKind.flutterImageCache: MediaResourceBudget(recommendedMaxActive: 1, pressureTier: MediaResourcePressureTier.reconstructable, rationale: 'One shared Flutter decoded image cache.'),
        MediaResourceKind.imagePrefetch: MediaResourceBudget(recommendedMaxActive: 1, pressureTier: MediaResourcePressureTier.reclaimFirst, rationale: 'One bounded prefetch queue.'),
        MediaResourceKind.gameBundleCache: MediaResourceBudget(recommendedMaxActive: 1, pressureTier: MediaResourcePressureTier.reconstructable, rationale: 'One verified game-bundle cache.'),
      };

  static MediaResourceBudget forKind(MediaResourceKind kind) {
    final budget = budgets[kind];
    if (budget == null) {
      throw StateError('Missing media resource budget for ' + kind.name + '.');
    }
    return budget;
  }
}
