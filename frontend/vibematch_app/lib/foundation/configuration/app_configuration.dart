import '../../core/network/vm_api_config.dart';

class AppConfiguration {
  const AppConfiguration({
    required this.apiBaseUrl,
  });

  final String apiBaseUrl;

  factory AppConfiguration.current() {
    return AppConfiguration(apiBaseUrl: VmApiConfig.baseUrl);
  }
}
