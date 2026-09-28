import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class DesktopChromeBrowserProfile {
  const DesktopChromeBrowserProfile._();

  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/140.0.0.0 Safari/537.36';

  static InAppWebViewSettings settings() {
    return InAppWebViewSettings(
      userAgent: userAgent,
      javaScriptEnabled: true,
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,
      thirdPartyCookiesEnabled: true,
      hardwareAcceleration: true,
    );
  }
}
