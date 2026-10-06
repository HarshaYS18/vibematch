import '../../../foundation/networking/app_network_client.dart';
import '../../auth/data/auth_api_service.dart';

/// Reads the disposable Recommendation projection without making it a product
/// authority. Callers must always have an authoritative fallback.
class RecommendationRepository {
  RecommendationRepository({
    AppNetworkClient? apiClient,
    AuthApiService? authApiService,
  }) : _apiClient = apiClient ?? AppNetworkRuntime.shared,
       _authApiService = authApiService ?? const AuthApiService();

  final AppNetworkClient _apiClient;
  final AuthApiService _authApiService;

  /// Returns null when personalization is unavailable and an empty list when
  /// the projection is healthy but has no candidates for [candidateKind].
  Future<List<String>?> tryFetchCandidateIds({
    required String candidateKind,
    int limit = 40,
  }) async {
    final user = _authApiService.cachedUser;
    if (user == null) return null;

    final kind = candidateKind.trim().toLowerCase();
    if (!const <String>{'room', 'vibe', 'user', 'game'}.contains(kind)) {
      return null;
    }

    try {
      final response = await _apiClient.getMap(
        '/recommendations',
        queryParameters: <String, String?>{
          'public_user_id': user.publicUserId.toString(),
          'limit': limit.clamp(1, 100).toString(),
        },
      );
      final items = response['items'];
      if (items is! List) return const <String>[];

      final seen = <String>{};
      final ids = <String>[];
      for (final raw in items.whereType<Map>()) {
        final item = raw.cast<String, dynamic>();
        if (item['candidate_kind']?.toString().trim().toLowerCase() != kind) {
          continue;
        }
        final id = item['candidate_id']?.toString().trim();
        if (id == null || id.isEmpty || !seen.add(id)) continue;
        ids.add(id);
      }
      return List<String>.unmodifiable(ids);
    } catch (_) {
      // Recommendation is an optional projection. Content authority remains
      // Home/Game APIs, so personalization failure must degrade silently.
      return null;
    }
  }
}
