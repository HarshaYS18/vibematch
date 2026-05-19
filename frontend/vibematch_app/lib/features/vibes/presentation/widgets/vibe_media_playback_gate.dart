import 'package:flutter/foundation.dart';

class VibeMediaPlaybackGate {
  const VibeMediaPlaybackGate._();

  static final ValueNotifier<bool> feedPlaybackPaused = ValueNotifier<bool>(false);
  static final ValueNotifier<int> feedScrollTick = ValueNotifier<int>(0);
  static final ValueNotifier<String?> activeFeedVideoKey = ValueNotifier<String?>(null);
  static final Set<String> _pauseLocks = <String>{};
  static bool _tabPaused = false;

  static void setTabPaused(bool paused) {
    _tabPaused = paused;
    if (paused) activeFeedVideoKey.value = null;
    _syncPausedState();
  }

  static void acquirePauseLock(String key) {
    if (key.trim().isEmpty) return;
    _pauseLocks.add(key);
    activeFeedVideoKey.value = null;
    _syncPausedState();
  }

  static void releasePauseLock(String key) {
    if (key.trim().isEmpty) return;
    _pauseLocks.remove(key);
    _syncPausedState();
  }

  static void claimActiveFeedVideo(String key) {
    if (key.trim().isEmpty || feedPlaybackPaused.value) return;
    if (activeFeedVideoKey.value != key) activeFeedVideoKey.value = key;
  }

  static void releaseActiveFeedVideo(String key) {
    if (key.trim().isEmpty) return;
    if (activeFeedVideoKey.value == key) activeFeedVideoKey.value = null;
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
    if (shouldPause) activeFeedVideoKey.value = null;
    if (feedPlaybackPaused.value != shouldPause) {
      feedPlaybackPaused.value = shouldPause;
    }
  }
}