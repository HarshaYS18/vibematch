import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../configuration/app_configuration.dart';
import '../logging/app_logger.dart';
import '../networking/app_network_client.dart';
import '../persistence/app_key_value_store.dart';
import '../telemetry/app_telemetry.dart';

final appConfigurationProvider = Provider<AppConfiguration>(
  (ref) => AppConfiguration.current(),
);

final appLoggerProvider = Provider<AppLogger>(
  (ref) => const AppLogger(),
);

final appTelemetryProvider = Provider<AppTelemetry>(
  (ref) => const AppTelemetry(),
);

final appNetworkClientProvider = Provider<AppNetworkClient>((ref) {
  final client = ApiClientNetworkAdapter();
  ref.onDispose(client.close);
  return client;
});

final appKeyValueStoreProvider = FutureProvider<AppKeyValueStore>((ref) async {
  return SharedPreferencesKeyValueStore.create();
});
