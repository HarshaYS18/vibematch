import '../../../core/network/api_client.dart';
import '../../auth/data/auth_api_service.dart';
import '../models/canonical_user_display_model.dart';

class ProfileDisplayRepository {
  ProfileDisplayRepository({
    ApiClient? apiClient,
    AuthApiService? authApiService,
  }) : _apiClient = apiClient ?? ApiClient(),
       _authApiService = authApiService ?? const AuthApiService();

  final ApiClient _apiClient;
  final AuthApiService _authApiService;

  Future<CanonicalUserDisplayModel> getMe() async {
    final json = await _apiClient.getMap(
      '/profile-display/me',
      headers: _headers(),
    );
    return CanonicalUserDisplayModel.fromJson(json);
  }

  Future<CanonicalUserDisplayModel> getPublicUser(int publicUserId) async {
    final json = await _apiClient.getMap(
      '/profile-display/users/$publicUserId',
      headers: _headers(),
    );
    return CanonicalUserDisplayModel.fromJson(json);
  }

  Map<String, String> _headers() {
    final token = _authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Please login again.');
    }
    return {'Authorization': 'Bearer $token'};
  }

  void close() => _apiClient.close();
}
