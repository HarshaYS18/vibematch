import 'package:flutter/foundation.dart';

class VibeMediaPlaybackGate {
  const VibeMediaPlaybackGate._();

  static final ValueNotifier<bool> feedPlaybackPaused = ValueNotifier<bool>(false);
  static final ValueNotifier<int> feedScrollTick = ValueNotifier<int>(0);

  static void notifyFeedScrolled() {
    feedScrollTick.value += 1;
  }
}
