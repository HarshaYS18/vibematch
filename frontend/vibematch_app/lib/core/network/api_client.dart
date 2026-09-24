@Deprecated('Use AppNetworkClient from foundation/networking instead.')
library;

import '../../foundation/networking/app_network_client.dart';

/// Temporary source-compatibility name only.
///
/// This type no longer owns sockets, HTTP clients, authentication, retries, or
/// serialization. All traffic is handled by the process-scoped Dio transport.
@Deprecated('Use DioAppNetworkClient or AppNetworkRuntime.shared.')
class ApiClient extends DioAppNetworkClient {
  ApiClient();
}
