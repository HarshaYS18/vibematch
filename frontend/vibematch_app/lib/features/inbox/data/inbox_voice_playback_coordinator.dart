import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class InboxVoicePlaybackState {
  const InboxVoicePlaybackState({this.activeKey, this.isPlaying = false, this.isLoading = false});

  final String? activeKey;
  final bool isPlaying;
  final bool isLoading;

  bool isActive(String key) => activeKey == key;

  InboxVoicePlaybackState copyWith({String? activeKey, bool clearActiveKey = false, bool? isPlaying, bool? isLoading}) {
    return InboxVoicePlaybackState(
      activeKey: clearActiveKey ? null : activeKey ?? this.activeKey,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class InboxVoicePlaybackCoordinator extends ChangeNotifier {
  InboxVoicePlaybackCoordinator._() {
    _stateSubscription = _player.onPlayerStateChanged.listen(_handlePlayerState);
    _completeSubscription = _player.onPlayerComplete.listen((_) {
      _state = const InboxVoicePlaybackState();
      notifyListeners();
    });
  }

  static final InboxVoicePlaybackCoordinator instance = InboxVoicePlaybackCoordinator._();

  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<void>? _completeSubscription;
  InboxVoicePlaybackState _state = const InboxVoicePlaybackState();

  InboxVoicePlaybackState get state => _state;

  Future<void> toggle({required String key, required String target}) async {
    if (_state.activeKey == key && _state.isPlaying) {
      await _player.pause();
      _state = _state.copyWith(isPlaying: false, isLoading: false);
      notifyListeners();
      return;
    }

    _state = InboxVoicePlaybackState(activeKey: key, isLoading: true);
    notifyListeners();

    try {
      await _player.stop();
      await _player.play(_audioSource(target));
    } catch (_) {
      _state = const InboxVoicePlaybackState();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> stop() async {
    await _player.stop();
    _state = const InboxVoicePlaybackState();
    notifyListeners();
  }

  void _handlePlayerState(PlayerState playerState) {
    if (_state.activeKey == null) return;
    if (playerState == PlayerState.completed || playerState == PlayerState.stopped) {
      _state = const InboxVoicePlaybackState();
    } else {
      _state = _state.copyWith(
        isPlaying: playerState == PlayerState.playing,
        isLoading: false,
      );
    }
    notifyListeners();
  }

  Source _audioSource(String target) {
    if (target.startsWith('http://') || target.startsWith('https://')) return UrlSource(target);
    if (target.startsWith('file://')) return DeviceFileSource(Uri.parse(target).toFilePath());
    return DeviceFileSource(target);
  }

  @override
  void dispose() {
    unawaited(_stateSubscription?.cancel());
    unawaited(_completeSubscription?.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }
}
