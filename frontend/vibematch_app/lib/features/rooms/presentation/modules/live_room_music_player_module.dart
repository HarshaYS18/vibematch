import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/live_room_audio_service.dart';
import '../../data/live_room_music_signaling_service.dart';
import '../../../media/data/media_upload_service.dart';
import '../widgets/room_theme.dart';

class LiveRoomMusicPlayerModule extends StatefulWidget {
  const LiveRoomMusicPlayerModule({super.key, required this.roomId});

  final String roomId;

  static Future<void> open(BuildContext context, {required String roomId}) {
    return Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => LiveRoomMusicPlayerModule(roomId: roomId),
      ),
    );
  }

  @override
  State<LiveRoomMusicPlayerModule> createState() =>
      _LiveRoomMusicPlayerModuleState();
}

class _LiveRoomMusicPlayerModuleState extends State<LiveRoomMusicPlayerModule> {
  final AudioPlayer _player = AudioPlayer();
  final MediaUploadService _mediaUploadService = const MediaUploadService();
  final TextEditingController _searchController = TextEditingController();

  final List<RoomMusicTrack> _tracks = <RoomMusicTrack>[];
  final Set<String> _selectedTrackIds = <String>{};
  final Map<String, String> _uploadedMusicUrls = <String, String>{};

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<void>? _completeSub;

  int _currentIndex = -1;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  PlayerState _state = PlayerState.stopped;
  String _query = '';
  bool _loadingFiles = false;

  RoomMusicTrack? get _currentTrack =>
      _currentIndex >= 0 && _currentIndex < _tracks.length
      ? _tracks[_currentIndex]
      : null;

  bool get _isPlaying => _state == PlayerState.playing;

  List<RoomMusicTrack> get _filteredTracks {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return List<RoomMusicTrack>.from(_tracks);
    return _tracks
        .where((track) => track.title.toLowerCase().contains(q))
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _positionSub = _player.onPositionChanged.listen((value) {
      if (mounted) setState(() => _position = value);
    });
    _durationSub = _player.onDurationChanged.listen((value) {
      if (mounted) setState(() => _duration = value);
    });
    _stateSub = _player.onPlayerStateChanged.listen((value) {
      if (mounted) setState(() => _state = value);
    });
    _completeSub = _player.onPlayerComplete.listen((_) => _playNext());
    _searchController.addListener(() {
      if (mounted) setState(() => _query = _searchController.text);
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _stateSub?.cancel();
    _completeSub?.cancel();
    _searchController.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _pickSongs() async {
    if (_loadingFiles) return;
    setState(() => _loadingFiles = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.audio,
        withData: true,
      );
      if (result == null) return;

      final nextTracks = <RoomMusicTrack>[];
      for (final file in result.files) {
        final stablePart = file.path ?? file.bytes?.lengthInBytes.toString() ?? '';
        final id = '${file.name}-${file.size}-$stablePart';
        if (_tracks.any((track) => track.id == id) ||
            nextTracks.any((track) => track.id == id)) {
          continue;
        }
        nextTracks.add(
          RoomMusicTrack(
            id: id,
            title: file.name,
            path: file.path,
            bytes: file.bytes,
            sizeBytes: file.size,
          ),
        );
      }

      if (nextTracks.isEmpty) return;
      setState(() {
        _tracks.addAll(nextTracks);
        if (_currentIndex < 0) _currentIndex = 0;
      });
    } finally {
      if (mounted) setState(() => _loadingFiles = false);
    }
  }

  Future<void> _playOrPause() async {
    final track = _currentTrack;
    if (track == null) {
      await _pickSongs();
      if (_currentTrack == null) return;
    }

    if (_isPlaying) {
      await _player.pause();
      unawaited(_broadcastMusicControl('pause'));
      return;
    }

    if (_state == PlayerState.paused) {
      await _player.resume();
      unawaited(_broadcastMusicControl('resume'));
      return;
    }

    await _playTrack(_currentIndex < 0 ? 0 : _currentIndex);
  }

  Future<void> _playTrack(int index) async {
    if (index < 0 || index >= _tracks.length) return;
    final track = _tracks[index];
    setState(() {
      _currentIndex = index;
      _position = Duration.zero;
      _duration = Duration.zero;
    });

    final uploadedUrl = await _ensureUploadedTrack(track);
    if (uploadedUrl == null) return;

    if (kIsWeb && track.bytes != null) {
      await _player.play(BytesSource(track.bytes!));
    } else if (track.path != null && track.path!.trim().isNotEmpty) {
      await _player.play(DeviceFileSource(track.path!));
    } else if (track.bytes != null) {
      await _player.play(BytesSource(track.bytes!));
    } else {
      return;
    }

    await LiveRoomAudioService.instance.startRoomMusic(
      url: uploadedUrl,
      title: track.title,
    );
    unawaited(_broadcastProducerStarted());
    unawaited(_broadcastMusicControl('play'));
  }

  Future<String?> _ensureUploadedTrack(RoomMusicTrack track) async {
    final existing = _uploadedMusicUrls[track.id];
    if (existing != null && existing.trim().isNotEmpty) return existing;

    final bytes = track.bytes;
    if (bytes == null || bytes.isEmpty) return null;

    final result = await _mediaUploadService.uploadRoomMusicBytes(
      bytes: bytes,
      filename: track.title,
    );

    if (result.url.trim().isEmpty) return null;
    _uploadedMusicUrls[track.id] = result.url;
    return result.url;
  }

  Future<void> _playNext() async {
    if (_tracks.isEmpty) return;
    final next = _currentIndex + 1 >= _tracks.length ? 0 : _currentIndex + 1;
    await _playTrack(next);
  }

  Future<void> _playPrevious() async {
    if (_tracks.isEmpty) return;
    final previous = _currentIndex - 1 < 0 ? _tracks.length - 1 : _currentIndex - 1;
    await _playTrack(previous);
  }

  Future<void> _seekTo(double millis) async {
    final next = Duration(milliseconds: millis.round());
    await _player.seek(next);
    unawaited(_broadcastMusicControl('seek', positionMs: next.inMilliseconds));
  }

  void _removeTrack(RoomMusicTrack track) {
    final removedIndex = _tracks.indexWhere((item) => item.id == track.id);
    if (removedIndex < 0) return;

    setState(() {
      _tracks.removeAt(removedIndex);
      _selectedTrackIds.remove(track.id);
      if (_tracks.isEmpty) {
        _currentIndex = -1;
      } else if (_currentIndex >= _tracks.length) {
        _currentIndex = _tracks.length - 1;
      } else if (removedIndex < _currentIndex) {
        _currentIndex--;
      }
    });

    if (_tracks.isEmpty) {
      unawaited(_player.stop());
      unawaited(LiveRoomAudioService.instance.stopRoomMusic());
      unawaited(_broadcastMusicControl('stop'));
    }
  }

  void _removeSelectedOrAll() {
    if (_tracks.isEmpty) return;
    if (_selectedTrackIds.isEmpty) {
      setState(() {
        _tracks.clear();
        _selectedTrackIds.clear();
        _currentIndex = -1;
        _position = Duration.zero;
        _duration = Duration.zero;
      });
      unawaited(_player.stop());
      unawaited(LiveRoomAudioService.instance.stopRoomMusic());
      unawaited(_broadcastMusicControl('stop'));
      return;
    }

    setState(() {
      _tracks.removeWhere((track) => _selectedTrackIds.contains(track.id));
      _selectedTrackIds.clear();
      if (_tracks.isEmpty) {
        _currentIndex = -1;
      } else if (_currentIndex >= _tracks.length) {
        _currentIndex = _tracks.length - 1;
      }
    });
  }

  void _toggleSelectAllVisible() {
    final visible = _filteredTracks;
    if (visible.isEmpty) return;
    final allSelected = visible.every((track) => _selectedTrackIds.contains(track.id));
    setState(() {
      if (allSelected) {
        for (final track in visible) {
          _selectedTrackIds.remove(track.id);
        }
      } else {
        _selectedTrackIds.addAll(visible.map((track) => track.id));
      }
    });
  }

  Future<void> _broadcastProducerStarted() async {
    final track = _currentTrack;
    if (track == null) return;
    await LiveRoomMusicSignalingService.instance.sendProducerStarted(
      roomId: widget.roomId,
      trackId: track.id,
      trackTitle: track.title,
      positionMs: _position.inMilliseconds,
      durationMs: _duration.inMilliseconds,
    );
  }

  Future<void> _broadcastMusicControl(String action, {int? positionMs}) async {
    final track = _currentTrack;
    final event = LiveRoomMusicControlEvent(
      roomId: widget.roomId,
      action: action,
      trackId: track?.id ?? '',
      trackTitle: track?.title ?? '',
      positionMs: positionMs ?? _position.inMilliseconds,
      durationMs: _duration.inMilliseconds,
      emittedAt: DateTime.now(),
    );
    LiveRoomMusicControlBus.publish(event);
    await LiveRoomMusicSignalingService.instance.sendControl(
      roomId: event.roomId,
      action: event.action,
      trackId: event.trackId,
      trackTitle: event.trackTitle,
      positionMs: event.positionMs,
      durationMs: event.durationMs,
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final track = _currentTrack;
    final maxMs = _duration.inMilliseconds <= 0
        ? 1.0
        : _duration.inMilliseconds.toDouble();
    final positionMs = _position.inMilliseconds.clamp(0, maxMs.toInt()).toDouble();
    final visibleTracks = _filteredTracks;

    return Scaffold(
      backgroundColor: RoomColors.deep,
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF120B2A), Color(0xFF071B25), Color(0xFF241044)],
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text(
                        'Room Music',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _loadingFiles ? null : _pickSongs,
                      icon: const Icon(Icons.library_music_rounded, size: 18),
                      label: Text(_loadingFiles ? 'Loading...' : 'Add songs'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _CompactMusicCard(
                  title: track?.title ?? 'No song selected',
                  subtitle: track == null
                      ? 'Add songs from this device to start room music'
                      : 'Broadcasting controls to the live room',
                  isPlaying: _isPlaying,
                  positionLabel: _formatDuration(_position),
                  durationLabel: _formatDuration(_duration),
                  sliderValue: positionMs,
                  sliderMax: maxMs,
                  onPlayPause: _playOrPause,
                  onPrevious: _playPrevious,
                  onNext: _playNext,
                  onSeek: _seekTo,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search songs',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
                          prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: _toggleSelectAllVisible,
                      icon: const Icon(Icons.select_all_rounded),
                      tooltip: 'Select all visible',
                    ),
                    IconButton.filledTonal(
                      onPressed: _removeSelectedOrAll,
                      icon: Icon(_selectedTrackIds.isEmpty ? Icons.delete_sweep_rounded : Icons.delete_rounded),
                      tooltip: _selectedTrackIds.isEmpty ? 'Remove all' : 'Remove selected',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: visibleTracks.isEmpty
                    ? Center(
                        child: Text(
                          _tracks.isEmpty ? 'No songs added yet' : 'No matching songs',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
                        itemCount: visibleTracks.length,
                        itemBuilder: (context, index) {
                          final item = visibleTracks[index];
                          final realIndex = _tracks.indexWhere((track) => track.id == item.id);
                          final selected = _selectedTrackIds.contains(item.id);
                          final active = realIndex == _currentIndex;
                          return _MusicTrackTile(
                            track: item,
                            selected: selected,
                            active: active,
                            onTap: () => _playTrack(realIndex),
                            onSelected: () {
                              setState(() {
                                if (selected) {
                                  _selectedTrackIds.remove(item.id);
                                } else {
                                  _selectedTrackIds.add(item.id);
                                }
                              });
                            },
                            onRemove: () => _removeTrack(item),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactMusicCard extends StatelessWidget {
  const _CompactMusicCard({
    required this.title,
    required this.subtitle,
    required this.isPlaying,
    required this.positionLabel,
    required this.durationLabel,
    required this.sliderValue,
    required this.sliderMax,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onSeek,
  });

  final String title;
  final String subtitle;
  final bool isPlaying;
  final String positionLabel;
  final String durationLabel;
  final double sliderValue;
  final double sliderMax;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    final safeSliderValue = sliderValue.clamp(0.0, sliderMax).toDouble();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [RoomColors.aqua, RoomColors.violet]),
                  boxShadow: [
                    BoxShadow(
                      color: RoomColors.aqua.withValues(alpha: 0.25),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Icon(Icons.music_note_rounded, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onPrevious,
                icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
              ),
              IconButton.filled(
                onPressed: onPlayPause,
                icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
              ),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(positionLabel, style: _timeStyle),
              Expanded(
                child: Slider(
                  value: safeSliderValue,
                  max: sliderMax <= 0 ? 1 : sliderMax,
                  onChanged: onSeek,
                ),
              ),
              Text(durationLabel, style: _timeStyle),
            ],
          ),
        ],
      ),
    );
  }

  TextStyle get _timeStyle => TextStyle(
    color: Colors.white.withValues(alpha: 0.72),
    fontSize: 10.5,
    fontWeight: FontWeight.w800,
  );
}

class _MusicTrackTile extends StatelessWidget {
  const _MusicTrackTile({
    required this.track,
    required this.selected,
    required this.active,
    required this.onTap,
    required this.onSelected,
    required this.onRemove,
  });

  final RoomMusicTrack track;
  final bool selected;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onSelected;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: active
            ? RoomColors.aqua.withValues(alpha: 0.17)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active
              ? RoomColors.aqua.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.14),
        ),
      ),
      child: ListTile(
        dense: true,
        onTap: onTap,
        leading: Checkbox(value: selected, onChanged: (_) => onSelected()),
        title: Text(
          track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          track.sizeLabel,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.58),
            fontWeight: FontWeight.w700,
          ),
        ),
        trailing: IconButton(
          onPressed: onRemove,
          icon: const Icon(Icons.close_rounded, color: Colors.white70),
        ),
      ),
    );
  }
}

@immutable
class RoomMusicTrack {
  const RoomMusicTrack({
    required this.id,
    required this.title,
    required this.sizeBytes,
    this.path,
    this.bytes,
  });

  final String id;
  final String title;
  final int sizeBytes;
  final String? path;
  final Uint8List? bytes;

  String get sizeLabel {
    if (sizeBytes <= 0) return 'Local audio';
    final mb = sizeBytes / (1024 * 1024);
    if (mb >= 1) return '${mb.toStringAsFixed(1)} MB';
    return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
  }
}

class LiveRoomMusicControlBus {
  LiveRoomMusicControlBus._();

  static final ValueNotifier<LiveRoomMusicControlEvent?> latestEvent =
      ValueNotifier<LiveRoomMusicControlEvent?>(null);

  static void publish(LiveRoomMusicControlEvent event) {
    latestEvent.value = event;
  }
}

@immutable
class LiveRoomMusicControlEvent {
  const LiveRoomMusicControlEvent({
    required this.roomId,
    required this.action,
    required this.trackId,
    required this.trackTitle,
    required this.positionMs,
    required this.durationMs,
    required this.emittedAt,
  });

  final String roomId;
  final String action;
  final String trackId;
  final String trackTitle;
  final int positionMs;
  final int durationMs;
  final DateTime emittedAt;
}
