import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/home_room.dart';
import 'models/home_room_dto.dart';

class HomeRepository {
  HomeRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

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

  void close() {
    _apiClient.close();
  }
}
