import '../../core/network/api_exception.dart';
import '../../core/network/vm_api_config.dart';
import '../../features/auth/data/auth_api_service.dart';
import '../networking/app_network_client.dart';

class GraphqlReadResult {
  const GraphqlReadResult({required this.data, required this.errors});

  final Map<String, dynamic> data;
  final List<Map<String, dynamic>> errors;
}

class PersistedGraphqlReadClient {
  PersistedGraphqlReadClient({
    AppNetworkClient? apiClient,
    AuthApiService? authApiService,
  }) : _apiClient = apiClient ?? AppNetworkRuntime.shared,
       _authApiService = authApiService ?? const AuthApiService();

  final AppNetworkClient _apiClient;
  final AuthApiService _authApiService;

  Future<GraphqlReadResult> execute(
    String operationId, {
    Map<String, dynamic> variables = const <String, dynamic>{},
    NetworkCancellation? cancellation,
  }) async {
    final token = _authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw ApiException(message: 'Please login again.');
    }

    final json = await _apiClient.postMap(
      VmApiConfig.graphqlEndpoint,
      headers: <String, String>{'Authorization': 'Bearer $token'},
      body: <String, dynamic>{
        'id': operationId,
        'variables': variables,
      },
      cancellation: cancellation,
    );

    final rawData = json['data'];
    final rawErrors = json['errors'];
    final data = rawData is Map
        ? rawData.cast<String, dynamic>()
        : const <String, dynamic>{};
    final errors = rawErrors is List
        ? rawErrors
              .whereType<Map>()
              .map((item) => item.cast<String, dynamic>())
              .toList(growable: false)
        : const <Map<String, dynamic>>[];

    if (data.isEmpty && errors.isNotEmpty) {
      throw ApiException(
        message: errors.first['message']?.toString() ?? 'GraphQL read failed',
        body: json,
      );
    }
    return GraphqlReadResult(data: data, errors: errors);
  }
}
