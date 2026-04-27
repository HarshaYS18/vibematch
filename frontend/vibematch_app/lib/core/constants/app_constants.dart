class AppConstants {
  AppConstants._();

  static const String appName = 'Vibe Match';

  // Official app logo asset path.
  static const String logoPath = 'assets/images/branding/vibe_match_logo.png';

  // Laptop Wi-Fi IP for testing on a real Android phone.
  // Your current laptop IP from ipconfig: 192.168.29.240
  static const String apiBaseUrl = 'http://192.168.29.240:8000';

  // Same backend URL for web/dev testing when needed.
  static const String webApiBaseUrl = 'http://192.168.29.240:8000';

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 20);
}
