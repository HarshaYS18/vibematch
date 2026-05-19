import 'package:flutter/foundation.dart';

class VibeMediaPlaybackGate {
  const VibeMediaPlaybackGate._();

  static final ValueNotifier<bool> feedPlaybackPaused = ValueNotifier<bool>(false);
  static final ValueNotifier<int> feedScrollTick = ValueNotifier<int>(0);
  static final Set<String> _pauseLocks = <String>{};
  static bool _tabPaused = false;

  static void setTabPaused(bool paused) {
    _tabPaused = paused;
    _syncPausedState();
  }

  static void acquirePauseLock(String key) {
    if (key.trim().isEmpty) return;
    _pauseLocks.add(key);
    _syncPausedState();
  }

  static void releasePauseLock(String key) {
    if (key.trim().isEmpty) return;
    _pauseLocks.remove(key);
    _syncPausedState();
  }

  static void clearPauseLocks() {
    _pauseLocks.clear();
    _syncPausedState();
  }

  static void notifyFeedScrolled() {
    feedScrollTick.value += 1;
  }

  static void _syncPausedState() {
    final shouldPause = _tabPaused || _pauseLocks.isNotEmpty;
    if (feedPlaybackPaused.value != shouldPause) {
      feedPlaybackPaused.value = shouldPause;
    }
  }
}