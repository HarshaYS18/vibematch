import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../features/auth/data/auth_api_service.dart';
import 'app_source_registry.dart';

class AppSourceRegistryRepository {
  AppSourceRegistryRepository({
    ApiClient? apiClient,
    AuthApiService authApiService = const AuthApiService(),
  }) : _apiClient = apiClient ?? ApiClient(),
       _authApiService = authApiService;

  final ApiClient _apiClient;
  final AuthApiService _authApiService;

  Future<AppSourceRegistry> fetchAndValidate() async {
    final token = _authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw StateError('Cannot load app source registry without a session.');
    }

    final json = await _apiClient.getMap(
      ApiEndpoints.appSourceOfTruthMaster,
      headers: <String, String>{
        'Authorization': 'Bearer $token',
      },
    );
    final registry = AppSourceRegistry.fromJson(json);
    registry.validateMainShellContract();
    return registry;
  }

  void close() {
    _apiClient.close();
  }
}
