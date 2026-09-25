import '../../../foundation/graphql/composite_read_repository.dart';
import '../../../foundation/networking/app_network_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../auth/data/auth_api_service.dart';
import '../models/home_banner.dart';
import '../models/home_room.dart';
import 'models/home_banner_dto.dart';
import 'models/home_room_dto.dart';

class HomeRepository {
  HomeRepository({
    AppNetworkClient? apiClient,
    AuthApiService? authApiService,
    CompositeReadRepository? compositeReadRepository,
  }) : _apiClient = apiClient ?? AppNetworkRuntime.shared,
       _authApiService = authApiService ?? const AuthApiService(),
       _compositeReads =
           compositeReadRepository ??
           CompositeReadRepository(
             apiClient: apiClient ?? AppNetworkRuntime.shared,
             authApiService: authApiService ?? const AuthApiService(),
           );

  final AppNetworkClient _apiClient;
  final AuthApiService _authApiService;
  final CompositeReadRepository _compositeReads;

  Map<String, String> _authHeaders() {
    final token = _authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Please login again.');
    }
    return {'Authorization': 'Bearer $token'};
  }

  Future<HomeChromeComposite> fetchHomeChromeComposite() async {
    final result = await _compositeReads.loadHome();
    final home = _map(result.data['home']);

    final roomJson = _map(home['myRoom']);
    final eventJson = _listOfMaps(home['eventBanners']);
    final policyJson = _listOfMaps(home['policyBanners']);

    return HomeChromeComposite(
      myCreatedRoom: roomJson.isEmpty
          ? null
          : HomeRoomDto.fromJson(roomJson).toDomain(),
      eventBanners: eventJson
          .map(HomeBannerDto.fromJson)
          .map((dto) => dto.toDomain())
          .where(
            (banner) =>
                banner.imageUrl != null && banner.imageUrl!.trim().isNotEmpty,
          )
          .toList(growable: false),
      policyBanners: policyJson
          .map(HomeBannerDto.fromJson)
          .map((dto) => dto.toDomain())
          .where(
            (banner) =>
                banner.imageUrl != null && banner.imageUrl!.trim().isNotEmpty,
          )
          .toList(growable: false),
      hasPartialErrors: result.errors.isNotEmpty,
    );
  }

  Future<HomeRoom?> fetchMyCreatedRoom() async {
    final response = await _apiClient.getOptionalMap(
      ApiEndpoints.myCreatedRoom,
      headers: _authHeaders(),
    );
    if (response == null || response.isEmpty) return null;
    return HomeRoomDto.fromJson(response).toDomain();
  }

  Future<List<HomeBanner>> fetchHomeBanners({required String placement}) async {
    final response = await _apiClient.getList(
      ApiEndpoints.homeBanners,
      queryParameters: {'placement': placement},
    );
    return response
        .whereType<Map<String, dynamic>>()
        .map(HomeBannerDto.fromJson)
        .map((dto) => dto.toDomain())
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

  Future<HomeRoom?> fetchQuickMatch({
    String? language,
    String? category,
  }) async {
    final response = await _apiClient.getOptionalMap(
      ApiEndpoints.roomsQuickMatch,
      queryParameters: <String, String?>{
        'language': language,
        'category': category,
      },
      headers: _authHeaders(),
    );
    if (response == null || response.isEmpty) return null;
    return HomeRoomDto.fromJson(response).toDomain();
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


class HomeChromeComposite {
  const HomeChromeComposite({
    required this.myCreatedRoom,
    required this.eventBanners,
    required this.policyBanners,
    required this.hasPartialErrors,
  });

  final HomeRoom? myCreatedRoom;
  final List<HomeBanner> eventBanners;
  final List<HomeBanner> policyBanners;
  final bool hasPartialErrors;
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _listOfMaps(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((item) => item.cast<String, dynamic>())
      .toList(growable: false);
}
