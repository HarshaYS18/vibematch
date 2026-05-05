class AppConstants {
  AppConstants._();

  static const String appName = 'Vibe Match';

  // Official app logo asset path.
  static const String logoPath = 'assets/images/branding/vibe_match_logo.png';

  // Default local backend URL for Flutter Web / Edge testing on the same laptop.
  // Override when testing on Android emulator or a physical phone:
  // flutter run --dart-define=VM_API_BASE_URL=http://10.0.2.2:8000
  // flutter run --dart-define=VM_API_BASE_URL=http://YOUR_LAN_IP:8000
  static const String apiBaseUrl = String.fromEnvironment(
    'VM_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  // Same backend URL for ApiClient-based modules like Home/Rooms/Splash.
  static const String webApiBaseUrl = String.fromEnvironment(
    'VM_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 20);
}
