import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../auth/data/auth_api_service.dart';
import '../models/home_banner.dart';
import '../models/home_room.dart';
import 'models/home_room_dto.dart';

class HomeRepository {
  HomeRepository({ApiClient? apiClient, AuthApiService? authApiService})
      : _apiClient = apiClient ?? ApiClient(),
        _authApiService = authApiService ?? const AuthApiService();

  final ApiClient _apiClient;
  final AuthApiService _authApiService;

  Map<String, String> _authHeaders() {
    final token = _authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Please login again.');
    }
    return {'Authorization': 'Bearer $token'};
  }

  Future<HomeRoom?> fetchMyCreatedRoom() async {
    final response = await _apiClient.getMap(
      ApiEndpoints.myCreatedRoom,
      headers: _authHeaders(),
    );
    if (response.isEmpty) return null;
    return HomeRoomDto.fromJson(response).toDomain();
  }

  Future<List<HomeBanner>> fetchHomeBanners({required String placement}) async {
    final response = await _apiClient.getList(
      ApiEndpoints.homeBanners,
      queryParameters: {'placement': placement},
    );
    return response
        .whereType<Map<String, dynamic>>()
        .map(HomeBanner.fromJson)
        .where((banner) => banner.imageUrl != null && banner.imageUrl!.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<List<HomeRoom>> fetchTrendingRooms({
    String? language,
    String? category,
    int limit = 30,
  }) async {
    final response = await _apiClient.getList(
      ApiEndpoints.roomsTrending,
      queryParameters: {
        'language': language,
        'category': category,
        'limit': limit.toString(),
      },
    );

    return response
        .whereType<Map<String, dynamic>>()
        .map(HomeRoomDto.fromJson)
        .map((dto) => dto.toDomain())
        .toList(growable: false);
  }

  Future<List<HomeRoom>> fetchFollowingRooms({
    String? language,
    String? category,
    int limit = 30,
  }) async {
    final response = await _apiClient.getList(
      ApiEndpoints.roomsFollowing,
      queryParameters: {
        'language': language,
        'category': category,
        'limit': limit.toString(),
      },
      headers: _authHeaders(),
    );

    return response
        .whereType<Map<String, dynamic>>()
        .map(HomeRoomDto.fromJson)
        .map((dto) => dto.toDomain())
        .toList(growable: false);
  }

  void close() {
    _apiClient.close();
  }
}
