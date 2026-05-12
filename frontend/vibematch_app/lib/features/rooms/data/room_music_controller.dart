import 'dart:async';
import 'dart:convert';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../media/data/media_upload_service.dart';
import 'live_room_audio_service.dart';

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

    state.value = state.value.copyWith(playlist: merged);
    await _savePlaylist();
  }

  Future<void> removeTrack(String trackId) async {
    final current = state.value;
    final nextPlaylist = current.playlist
        .where((track) => track.id != trackId)
        .toList(growable: false);

    var nextIndex = current.currentIndex;
    if (nextPlaylist.isEmpty) {
      await stop();
      state.value = state.value.copyWith(
        playlist: <RoomMusicTrack>[],
        currentIndex: -1,
      );
      await _savePlaylist();
      return;
    }

    if (nextIndex >= nextPlaylist.length) nextIndex = nextPlaylist.length - 1;

    state.value = current.copyWith(
      playlist: nextPlaylist,
      currentIndex: nextIndex,
    );
    await _savePlaylist();
  }

  Future<void> clearPlaylist() async {
    await stop();
    state.value = state.value.copyWith(
      playlist: <RoomMusicTrack>[],
      currentIndex: -1,
    );
    await _savePlaylist();
  }

  Future<void> playIndex(int index) async {
    final roomId = _roomId;
    if (roomId == null || roomId.trim().isEmpty) return;

    final playlist = state.value.playlist;
    if (index < 0 || index >= playlist.length) return;

    final track = playlist[index];

    state.value = state.value.copyWith(
      currentIndex: index,
      isUploading: true,
      isOverlayVisible: true,
      isMinimized: false,
      clearError: true,
    );

    try {
      final uploadedUrl = await _ensureUploaded(track);
      final success = await LiveRoomAudioService.instance.startRoomMusic(
        url: uploadedUrl,
        title: track.title,
      );

      if (!success) {
        final sfuError =
            LiveRoomAudioService.instance.lastError.value ??
            'Could not start room music on SFU.';
        state.value = state.value.copyWith(
          isUploading: false,
          isPlaying: false,
          lastError: sfuError,
        );
        return;
      }

      state.value = state.value.copyWith(
        currentIndex: index,
        isUploading: false,
        isPlaying: true,
        isPaused: false,
        isOverlayVisible: true,
        clearError: true,
      );
      await _savePlaylist();
    } catch (error) {
      state.value = state.value.copyWith(
        isUploading: false,
        isPlaying: false,
        lastError: error.toString(),
      );
    }
  }

  Future<void> playCurrentOrFirst() async {
    if (state.value.playlist.isEmpty) return;
    final index = state.value.currentIndex >= 0 ? state.value.currentIndex : 0;
    await playIndex(index);
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

    await playIndex(nextIndex);
  }

  Future<void> playPrevious() async {
    final playlist = state.value.playlist;
    if (playlist.isEmpty) return;
    final previous =
        state.value.currentIndex <= 0 ? 0 : state.value.currentIndex - 1;
    await playIndex(previous);
  }

  Future<void> stop() async {
    await LiveRoomAudioService.instance.stopRoomMusic();
    state.value = state.value.copyWith(
      isPlaying: false,
      isPaused: false,
      isUploading: false,
      isMinimized: false,
      isOverlayVisible: false,
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
    if (!state.value.isPlaying && !state.value.isUploading) {
      state.value = state.value.copyWith(isOverlayVisible: false);
      return;
    }

    state.value = state.value.copyWith(
      isOverlayVisible: false,
      isMinimized: true,
    );
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
    final titleName = track.title.trim().replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

    final pathHasAudioExtension = RegExp(
      r'\.(mp3|m4a|aac|wav|ogg|opus|webm|flac)$',
      caseSensitive: false,
    ).hasMatch(pathName);

    if (pathHasAudioExtension) return pathName;

    final titleHasAudioExtension = RegExp(
      r'\.(mp3|m4a|aac|wav|ogg|opus|webm|flac)$',
      caseSensitive: false,
    ).hasMatch(titleName);

    if (titleHasAudioExtension) return titleName;

    final safeTitle = titleName.isEmpty ? 'vibematch_room_music' : titleName;
    return '$safeTitle.mp3';
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
    this.isPlaying = false,
    this.isPaused = false,
    this.isUploading = false,
    this.isOverlayVisible = false,
    this.isMinimized = false,
    this.lastError,
  });

  final List<RoomMusicTrack> playlist;
  final int currentIndex;
  final bool isPlaying;
  final bool isPaused;
  final bool isUploading;
  final bool isOverlayVisible;
  final bool isMinimized;
  final String? lastError;

  RoomMusicTrack? get currentTrack =>
      currentIndex >= 0 && currentIndex < playlist.length
      ? playlist[currentIndex]
      : null;

  RoomMusicState copyWith({
    List<RoomMusicTrack>? playlist,
    int? currentIndex,
    bool? isPlaying,
    bool? isPaused,
    bool? isUploading,
    bool? isOverlayVisible,
    bool? isMinimized,
    String? lastError,
    bool clearError = false,
  }) {
    return RoomMusicState(
      playlist: playlist ?? this.playlist,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      isPaused: isPaused ?? this.isPaused,
      isUploading: isUploading ?? this.isUploading,
      isOverlayVisible: isOverlayVisible ?? this.isOverlayVisible,
      isMinimized: isMinimized ?? this.isMinimized,
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
