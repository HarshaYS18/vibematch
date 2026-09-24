import '../../../foundation/networking/app_network_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../auth/data/auth_api_service.dart';
import '../models/banner_manager_models.dart';

class BannerManagerRepository {
  BannerManagerRepository({AppNetworkClient? apiClient, AuthApiService? authApiService})
      : _apiClient = apiClient ?? AppNetworkRuntime.shared,
        _authApiService = authApiService ?? const AuthApiService();

  final AppNetworkClient _apiClient;
  final AuthApiService _authApiService;

  Map<String, String> _authHeaders() {
    final token = _authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Please login again.');
    }
    return {'Authorization': 'Bearer $token'};
  }

  Future<List<ManagedBanner>> fetchBanners({required ManagedBannerSection section}) async {
    final response = await _apiClient.getList(
      ApiEndpoints.homeBannersManage,
      queryParameters: {'placement': section.placement},
      headers: _authHeaders(),
    );
    return response
        .whereType<Map<String, dynamic>>()
        .map(ManagedBanner.fromJson)
        .toList(growable: false);
  }

  Future<ManagedBanner> createBanner({
    required ManagedBannerSection section,
    required String title,
    required ManagedBannerTarget target,
    required String imageUrl,
    required DateTime startDate,
    required DateTime endDate,
    required bool isActive,
    required int sortOrder,
  }) async {
    final response = await _apiClient.postMap(
      ApiEndpoints.homeBannersManage,
      headers: _authHeaders(),
      body: {
        'placement': section.placement,
        'title': title,
        'image_url': imageUrl,
        'target': target.backendValue,
        'target_url': null,
        'sort_order': sortOrder,
        'is_active': isActive,
        'starts_at': _dateOnly(startDate),
        'ends_at': _dateOnly(endDate),
      },
    );
    return ManagedBanner.fromJson(response);
  }

  Future<ManagedBanner> setActive({required int bannerId, required bool isActive}) async {
    final response = await _apiClient.patchMap(
      '/admin/media/banners/$bannerId/active',
      queryParameters: {'is_active': isActive.toString()},
      headers: _authHeaders(),
    );
    return ManagedBanner.fromJson(response);
  }

  String _dateOnly(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.toIso8601String();
  }

  void close() {
    _apiClient.close();
  }
}
