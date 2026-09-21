import '../../../core/network/api_client.dart';
import '../../auth/data/auth_api_service.dart';
import '../models/app_source_truth_model.dart';

class AppSourceTruthRepository {
  AppSourceTruthRepository({
    ApiClient? apiClient,
    AuthApiService? authApiService,
  }) : _apiClient = apiClient ?? ApiClient(),
       _authApiService = authApiService ?? const AuthApiService();

  final ApiClient _apiClient;
  final AuthApiService _authApiService;

  Future<AppSourceTruthRegistry> loadMasterRegistry() async {
    final json = await _apiClient.getMap(
      '/app/source-of-truth/master',
      headers: _headers(),
    );
    return AppSourceTruthRegistry.fromJson(json);
  }

  Future<AppSourceTruthRegistry> loadControlCenterRegistry() => loadMasterRegistry();

  Map<String, String> _headers() {
    final token = _authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Please login again.');
    }
    return {'Authorization': 'Bearer $token'};
  }

  void close() => _apiClient.close();
}
