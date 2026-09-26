import '../../features/auth/data/auth_api_service.dart';
import '../networking/app_network_client.dart';
import 'persisted_graphql_client.dart';
import 'persisted_operations.dart';

class CompositeReadRepository {
  CompositeReadRepository({
    AppNetworkClient? apiClient,
    AuthApiService? authApiService,
  }) : _client = PersistedGraphqlReadClient(
         apiClient: apiClient,
         authApiService: authApiService,
       );

  final PersistedGraphqlReadClient _client;

  Future<GraphqlReadResult> loadHome() =>
      _client.execute(PersistedGraphqlOperations.homeComposite);

  Future<GraphqlReadResult> loadProfile({
    required int publicUserId,
    int vibeLimit = 12,
  }) => _client.execute(
    PersistedGraphqlOperations.profileComposite,
    variables: <String, dynamic>{
      'publicUserId': '$publicUserId',
      'vibeLimit': vibeLimit,
    },
  );

  Future<GraphqlReadResult> loadDiscovery({
    int vibeLimit = 20,
    int rankingLimit = 20,
  }) => _client.execute(
    PersistedGraphqlOperations.discoveryComposite,
    variables: <String, dynamic>{
      'vibeLimit': vibeLimit,
      'rankingLimit': rankingLimit,
    },
  );

  Future<GraphqlReadResult> loadCreatorAdminDashboard({
    int reportLimit = 20,
  }) => _client.execute(
    PersistedGraphqlOperations.creatorAdminDashboard,
    variables: <String, dynamic>{'reportLimit': reportLimit},
  );
}
