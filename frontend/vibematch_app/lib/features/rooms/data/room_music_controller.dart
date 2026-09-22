import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../media/data/media_upload_service.dart';
import 'live_room_media_signaling_service.dart';

class RoomMusicController {
  RoomMusicController._();

  static final RoomMusicController instance = RoomMusicController._();

  static const String _playlistKey = 'vibematch_room_music_playlist_v1';

  final MediaUploadService _uploadService = const MediaUploadService();

  final ValueNotifier<RoomMusicState> state =
      ValueNotifier<RoomMusicState>(const RoomMusicState());

  String? _roomId;
  bool _loaded = false;
  bool _stoppingBecauseRoomExit = false;
  Timer? _progressTimer;
  DateTime? _playStartedAt;
  int _playStartedPositionMs = 0;

  Future<void> attachRoom(String roomId) async {
    final safeRoomId = roomId.trim().isEmpty ? 'VM000000' : roomId.trim();
    _roomId = safeRoomId;
    if (!_loaded) {
      await _loadPlaylist();
      _loaded = true;
    }
  }

  Future<void> addTracks(List<RoomMusicTrack> tracks) async {
    if (tracks.isEmpty) return;

    final existingIds = state.value.playlist.map((track) => track.id).toSet();
    final merged = <RoomMusicTrack>[
      ...state.value.playlist,
      ...tracks.where((track) => !existingIds.contains(track.id)),
    ];

    state.value = state.value.copyWith(
      playlist: merged,
      currentIndex: state.value.currentIndex >= 0
          ? state.value.currentIndex
          : merged.isEmpty
              ? -1
              : 0,
    );
    await _savePlaylist();
  }

  Future<void> removeTrack(String trackId) async {
    final current = state.value;
    final removingCurrent =
        current.currentTrack != null && current.currentTrack!.id == trackId;

    final nextPlaylist = current.playlist
        .where((track) => track.id != trackId)
        .toList(growable: false);

    if (nextPlaylist.isEmpty) {
      await stop();
      state.value = state.value.copyWith(
        playlist: <RoomMusicTrack>[],
        currentIndex: -1,
        positionMs: 0,
      );
      await _savePlaylist();
      return;
    }

    var nextIndex = current.currentIndex;
    if (nextIndex >= nextPlaylist.length) nextIndex = nextPlaylist.length - 1;

    state.value = current.copyWith(
      playlist: nextPlaylist,
      currentIndex: nextIndex,
      positionMs: removingCurrent ? 0 : current.positionMs,
    );

    await _savePlaylist();

    if (removingCurrent && current.isPlaying) {
      await playIndex(nextIndex);
    }
  }

  Future<void> clearPlaylist() async {
    await stop();
    state.value = state.value.copyWith(
      playlist: <RoomMusicTrack>[],
      currentIndex: -1,
      positionMs: 0,
    );
    await _savePlaylist();
  }

  Future<void> playIndex(int index, {int seekMs = 0}) async {
    final roomId = _roomId;
    if (roomId == null || roomId.trim().isEmpty) return;

    final playlist = state.value.playlist;
    if (index < 0 || index >= playlist.length) return;

    final track = playlist[index];
    final safeSeekMs = _clampPosition(seekMs, track.durationMs);

    state.value = state.value.copyWith(
      currentIndex: index,
      positionMs: safeSeekMs,
      isUploading: true,
      isOverlayVisible: true,
      isMinimized: false,
      clearError: true,
    );

    try {
      final uploadedUrl = await _ensureUploaded(track);
      final success = await LiveRoomMediaSignalingService.instance.mediaEngine.startRoomMusic(
        url: uploadedUrl,
        title: track.title,
        seekMs: safeSeekMs,
      );

      if (!success) {
        final sfuError =
            LiveRoomMediaSignalingService.instance.mediaEngine.lastError.value ??
            'Could not start room music on SFU.';
        state.value = state.value.copyWith(
          isUploading: false,
          isPlaying: false,
          isPaused: false,
          lastError: sfuError,
        );
        return;
      }

      _startProgressTimer(fromMs: safeSeekMs);
      state.value = state.value.copyWith(
        currentIndex: index,
        positionMs: safeSeekMs,
        isUploading: false,
        isPlaying: true,
        isPaused: false,
        isOverlayVisible: true,
        isMinimized: false,
        clearError: true,
      );
      await _savePlaylist();
    } catch (error) {
      state.value = state.value.copyWith(
        isUploading: false,
        isPlaying: false,
        isPaused: false,
        lastError: error.toString(),
      );
    }
  }

  Future<void> playCurrentOrFirst() async {
    if (state.value.playlist.isEmpty) return;
    final index = state.value.currentIndex >= 0 ? state.value.currentIndex : 0;
    await playIndex(index, seekMs: state.value.positionMs);
  }

  Future<void> playNext() async {
    final playlist = state.value.playlist;
    if (playlist.isEmpty) {
      await stop();
      return;
    }

    final nextIndex = state.value.currentIndex + 1;
    if (nextIndex >= playlist.length) {
      await stop();
      return;
    }

    await playIndex(nextIndex, seekMs: 0);
  }

  Future<void> playPrevious() async {
    final playlist = state.value.playlist;
    if (playlist.isEmpty) return;
    final previous =
        state.value.currentIndex <= 0 ? 0 : state.value.currentIndex - 1;
    await playIndex(previous, seekMs: 0);
  }

  Future<void> pause() async {
    if (!state.value.isPlaying) return;
    _syncProgressPosition();
    _stopProgressTimer();
    await LiveRoomMediaSignalingService.instance.mediaEngine.stopRoomMusic();
    state.value = state.value.copyWith(
      isPlaying: false,
      isPaused: true,
      isUploading: false,
      isOverlayVisible: true,
      isMinimized: false,
    );
  }

  Future<void> seekTo(int positionMs) async {
    final current = state.value.currentTrack;
    if (current == null) return;
    final safePosition = _clampPosition(positionMs, current.durationMs);

    state.value = state.value.copyWith(positionMs: safePosition);

    if (state.value.isPlaying) {
      await playIndex(state.value.currentIndex, seekMs: safePosition);
    }
  }

  void previewSeekPosition(int positionMs) {
    final current = state.value.currentTrack;
    final durationMs = current?.durationMs ?? 0;
    state.value = state.value.copyWith(
      positionMs: _clampPosition(positionMs, durationMs),
    );
  }

  Future<void> stop() async {
    _stopProgressTimer();
    await LiveRoomMediaSignalingService.instance.mediaEngine.stopRoomMusic();
    state.value = state.value.copyWith(
      isPlaying: false,
      isPaused: false,
      isUploading: false,
      isMinimized: false,
      isOverlayVisible: false,
      positionMs: 0,
    );
  }

  Future<void> stopBecauseControllerExitedRoom() async {
    if (_stoppingBecauseRoomExit) return;
    _stoppingBecauseRoomExit = true;
    try {
      await stop();
    } finally {
      _stoppingBecauseRoomExit = false;
    }
  }

  void showOverlay() {
    state.value = state.value.copyWith(
      isOverlayVisible: true,
      isMinimized: false,
    );
  }

  void minimizeOverlay() {
    if (!state.value.isPlaying &&
        !state.value.isUploading &&
        !state.value.isPaused) {
      state.value = state.value.copyWith(isOverlayVisible: false);
      return;
    }

    state.value = state.value.copyWith(
      isOverlayVisible: false,
      isMinimized: true,
    );
  }

  void setBubbleOffset(Offset offset) {
    state.value = state.value.copyWith(bubbleOffset: offset);
  }

  Future<String> _ensureUploaded(RoomMusicTrack track) async {
    if (track.uploadedUrl.trim().isNotEmpty) return track.uploadedUrl;

    final bytes = await XFile(track.path).readAsBytes();
    final result = await _uploadService.uploadRoomMusicBytes(
      bytes: bytes,
      filename: _uploadFilenameFor(track),
    );

    final playlist = [...state.value.playlist];
    final index = playlist.indexWhere((item) => item.id == track.id);
    if (index >= 0) {
      playlist[index] = playlist[index].copyWith(uploadedUrl: result.url);
      state.value = state.value.copyWith(playlist: playlist);
      await _savePlaylist();
    }

    return result.url;
  }

  String _uploadFilenameFor(RoomMusicTrack track) {
    final pathName = track.path.split(RegExp(r'[\\/]')).last.trim();
    final titleName =
        track.title.trim().replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

    final audioExt = RegExp(
      r'\.(mp3|m4a|aac|wav|ogg|opus|webm|flac)$',
      caseSensitive: false,
    );

    if (audioExt.hasMatch(pathName)) return pathName;
    if (audioExt.hasMatch(titleName)) return titleName;

    final safeTitle = titleName.isEmpty ? 'vibematch_room_music' : titleName;
    return '$safeTitle.mp3';
  }

  void _startProgressTimer({required int fromMs}) {
    _stopProgressTimer();
    _playStartedAt = DateTime.now();
    _playStartedPositionMs = fromMs;

    _progressTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _syncProgressPosition();
    });
  }

  void _syncProgressPosition() {
    final current = state.value.currentTrack;
    if (current == null || _playStartedAt == null) return;

    final elapsed = DateTime.now().difference(_playStartedAt!).inMilliseconds;
    final nextPosition = _clampPosition(
      _playStartedPositionMs + elapsed,
      current.durationMs,
    );

    if (current.durationMs > 0 && nextPosition >= current.durationMs - 350) {
      playNext();
      return;
    }

    state.value = state.value.copyWith(positionMs: nextPosition);
  }

  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
    _playStartedAt = null;
    _playStartedPositionMs = 0;
  }

  int _clampPosition(int positionMs, int durationMs) {
    if (positionMs < 0) return 0;
    if (durationMs <= 0) return positionMs;
    if (positionMs > durationMs) return durationMs;
    return positionMs;
  }

  Future<void> _loadPlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_playlistKey);
    if (raw == null || raw.trim().isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;

      final playlist = decoded
          .whereType<Map<String, dynamic>>()
          .map(RoomMusicTrack.fromJson)
          .where((track) => track.path.trim().isNotEmpty)
          .toList(growable: false);

      state.value = state.value.copyWith(
        playlist: playlist,
        currentIndex: playlist.isEmpty ? -1 : 0,
      );
    } catch (_) {}
  }

  Future<void> _savePlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      state.value.playlist.map((track) => track.toJson()).toList(),
    );
    await prefs.setString(_playlistKey, encoded);
  }
}

@immutable
class RoomMusicState {
  const RoomMusicState({
    this.playlist = const <RoomMusicTrack>[],
    this.currentIndex = -1,
    this.positionMs = 0,
    this.isPlaying = false,
    this.isPaused = false,
    this.isUploading = false,
    this.isOverlayVisible = false,
    this.isMinimized = false,
    this.bubbleOffset,
    this.lastError,
  });

  final List<RoomMusicTrack> playlist;
  final int currentIndex;
  final int positionMs;
  final bool isPlaying;
  final bool isPaused;
  final bool isUploading;
  final bool isOverlayVisible;
  final bool isMinimized;
  final Offset? bubbleOffset;
  final String? lastError;

  RoomMusicTrack? get currentTrack =>
      currentIndex >= 0 && currentIndex < playlist.length
          ? playlist[currentIndex]
          : null;

  int get durationMs => currentTrack?.durationMs ?? 0;

  RoomMusicState copyWith({
    List<RoomMusicTrack>? playlist,
    int? currentIndex,
    int? positionMs,
    bool? isPlaying,
    bool? isPaused,
    bool? isUploading,
    bool? isOverlayVisible,
    bool? isMinimized,
    Offset? bubbleOffset,
    String? lastError,
    bool clearError = false,
  }) {
    return RoomMusicState(
      playlist: playlist ?? this.playlist,
      currentIndex: currentIndex ?? this.currentIndex,
      positionMs: positionMs ?? this.positionMs,
      isPlaying: isPlaying ?? this.isPlaying,
      isPaused: isPaused ?? this.isPaused,
      isUploading: isUploading ?? this.isUploading,
      isOverlayVisible: isOverlayVisible ?? this.isOverlayVisible,
      isMinimized: isMinimized ?? this.isMinimized,
      bubbleOffset: bubbleOffset ?? this.bubbleOffset,
      lastError: clearError ? null : lastError ?? this.lastError,
    );
  }
}

@immutable
class RoomMusicTrack {
  const RoomMusicTrack({
    required this.id,
    required this.title,
    required this.path,
    this.artist = '',
    this.durationMs = 0,
    this.uploadedUrl = '',
  });

  final String id;
  final String title;
  final String path;
  final String artist;
  final int durationMs;
  final String uploadedUrl;

  RoomMusicTrack copyWith({String? uploadedUrl}) {
    return RoomMusicTrack(
      id: id,
      title: title,
      path: path,
      artist: artist,
      durationMs: durationMs,
      uploadedUrl: uploadedUrl ?? this.uploadedUrl,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'path': path,
        'artist': artist,
        'duration_ms': durationMs,
        'uploaded_url': uploadedUrl,
      };

  factory RoomMusicTrack.fromJson(Map<String, dynamic> json) {
    return RoomMusicTrack(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Unknown song',
      path: json['path']?.toString() ?? '',
      artist: json['artist']?.toString() ?? '',
      durationMs: int.tryParse(json['duration_ms']?.toString() ?? '') ?? 0,
      uploadedUrl: json['uploaded_url']?.toString() ?? '',
    );
  }
}
