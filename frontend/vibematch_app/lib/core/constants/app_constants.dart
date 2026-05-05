class AppConstants {
  AppConstants._();

  static const String appName = 'Vibe Match';

  // Official app logo asset path.
  static const String logoPath = 'assets/images/branding/vibe_match_logo.png';

  // Default local backend URL for Flutter Web / Edge testing on the same laptop.
  static const String apiBaseUrl = 'http://127.0.0.1:8000';

  // Same backend URL for ApiClient-based modules like Home/Rooms/Splash.
  static const String webApiBaseUrl = 'http://127.0.0.1:8000';

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 20);
}
