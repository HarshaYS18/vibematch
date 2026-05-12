
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

import 'room_music_controller.dart';

class DeviceAudioLibraryService {
  DeviceAudioLibraryService({OnAudioQuery? audioQuery})
      : _audioQuery = audioQuery ?? OnAudioQuery();

  final OnAudioQuery _audioQuery;

  Future<bool> requestPermission() async {
    final audio = await Permission.audio.request();
    if (audio.isGranted) return true;

    final storage = await Permission.storage.request();
    if (storage.isGranted) return true;

    return _audioQuery.permissionsRequest();
  }

  Future<List<RoomMusicTrack>> scanSongs() async {
    final allowed = await requestPermission();
    if (!allowed) return <RoomMusicTrack>[];

    final songs = await _audioQuery.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    return songs
        .where((song) => song.data.trim().isNotEmpty)
        .map(
          (song) => RoomMusicTrack(
            id: song.id.toString(),
            title: song.title.trim().isEmpty ? song.displayNameWOExt : song.title,
            artist: song.artist == '<unknown>' ? '' : (song.artist ?? ''),
            path: song.data,
            durationMs: song.duration ?? 0,
          ),
        )
        .toList(growable: false);
  }
}
