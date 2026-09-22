import 'package:flutter/foundation.dart';

class VibeMediaPlaybackGate {
  VibeMediaPlaybackGate({bool initiallyPaused = true})
      : feedPlaybackPaused = ValueNotifier<bool>(initiallyPaused),
        _tabPaused = initiallyPaused;

  final ValueNotifier<bool> feedPlaybackPaused;
  final ValueNotifier<int> feedScrollTick = ValueNotifier<int>(0);
  final ValueNotifier<String?> activeFeedVideoKey = ValueNotifier<String?>(null);
  final Set<String> _pauseLocks = <String>{};
  bool _tabPaused;
  bool _disposed = false;

  void setTabPaused(bool paused) {
    if (_disposed) return;
    _tabPaused = paused;
    if (paused) activeFeedVideoKey.value = null;
    _syncPausedState();
  }

  void acquirePauseLock(String key) {
    if (_disposed || key.trim().isEmpty) return;
    _pauseLocks.add(key);
    activeFeedVideoKey.value = null;
    _syncPausedState();
  }

  void releasePauseLock(String key) {
    if (_disposed || key.trim().isEmpty) return;
    _pauseLocks.remove(key);
    _syncPausedState();
  }

  void claimActiveFeedVideo(String key) {
    if (_disposed || key.trim().isEmpty || feedPlaybackPaused.value) return;
    if (activeFeedVideoKey.value != key) activeFeedVideoKey.value = key;
  }

  void releaseActiveFeedVideo(String key) {
    if (_disposed || key.trim().isEmpty) return;
    if (activeFeedVideoKey.value == key) activeFeedVideoKey.value = null;
  }

  void clearPauseLocks() {
    if (_disposed) return;
    _pauseLocks.clear();
    _syncPausedState();
  }

  void notifyFeedScrolled() {
    if (_disposed) return;
    feedScrollTick.value += 1;
  }

  void handleMemoryPressure() {
    if (_disposed) return;
    activeFeedVideoKey.value = null;
    feedScrollTick.value += 1;
  }

  void _syncPausedState() {
    if (_disposed) return;
    final shouldPause = _tabPaused || _pauseLocks.isNotEmpty;
    if (shouldPause) activeFeedVideoKey.value = null;
    if (feedPlaybackPaused.value != shouldPause) {
      feedPlaybackPaused.value = shouldPause;
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    feedPlaybackPaused.dispose();
    feedScrollTick.dispose();
    activeFeedVideoKey.dispose();
    _pauseLocks.clear();
  }
}
