import '../../auth/data/auth_api_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/home_room.dart';
import 'models/home_room_dto.dart';

class HomeRepository {
  HomeRepository({ApiClient? apiClient, AuthApiService? authApiService})
      : _apiClient = apiClient ?? ApiClient(),
        _authApiService = authApiService ?? const AuthApiService();

  final ApiClient _apiClient;
  final AuthApiService _authApiService;

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
    final token = _authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Please login again before loading following rooms.');
    }

    final response = await _apiClient.getList(
      ApiEndpoints.roomsFollowing,
      queryParameters: {
        'language': language,
        'category': category,
        'limit': limit.toString(),
      },
      headers: {'Authorization': 'Bearer $token'},
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
