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

  // Standalone mediasoup SFU server for production-testing WebRTC audio.
  // Android emulator can use http://10.0.2.2:4000 in the standalone test page.
  // Real phones should use the laptop/server LAN IP during local testing.
  static const String mediasoupAudioServerUrl = 'http://192.168.29.240:4000';

  // Keep true while testing migration. It makes Live Room use mediasoup by default,
  // while still allowing a safe rollback by flipping this constant.
  static const bool useMediasoupAudioInLiveRoom = true;

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 20);
}
