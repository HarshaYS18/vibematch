import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../foundation/di/app_dependencies.dart';
import '../../foundation/networking/app_network_client.dart';
import '../../room_session/data/room_session_repository.dart';
import '../../room_session/domain/room_session_state.dart';
import '../../session/data/session_repository.dart';
import '../domain/watch_party_state.dart';

enum WatchPartyCommand {
  load,
  play,
  pause,
  seek,
  changeContent,
  sync,
  end,
  transferControl,
}

class WatchPartyRepository extends StateNotifier<WatchPartyState> {
  WatchPartyRepository({
    required String roomId,
    required AppNetworkClient networkClient,
    required String? Function() accessTokenProvider,
    required RoomSessionRepository roomSessionRepository,
  }) : _roomId = roomId.trim(),
       _networkClient = networkClient,
       _accessTokenProvider = accessTokenProvider,
       _roomSessionRepository = roomSessionRepository,
       super(WatchPartyState.initial(roomId.trim()));

  final String _roomId;
  final AppNetworkClient _networkClient;
  final String? Function() _accessTokenProvider;
  final RoomSessionRepository _roomSessionRepository;

  void reconcileRoomState(RoomSessionState roomState) {
    if (roomState.roomId.trim() != _roomId) return;
    state = WatchPartyState.fromRoomState(roomState);
  }

  Future<WatchPartyState> load({
    required String provider,
    String? contentId,
    String? contentUrl,
    String? contentTitle,
    int positionMs = 0,
    WatchTimelineMode timelineMode = WatchTimelineMode.vod,
    int targetLiveLatencyMs = defaultWatchTargetLiveLatencyMs,
  }) {
    return _command(
      WatchPartyCommand.load,
      <String, dynamic>{
        'provider': provider,
        if (contentId?.trim().isNotEmpty == true) 'content_id': contentId!.trim(),
        if (contentUrl?.trim().isNotEmpty == true)
          'content_url': contentUrl!.trim(),
        if (contentTitle?.trim().isNotEmpty == true)
          'content_title': contentTitle!.trim(),
        'position_ms': positionMs,
        'timeline_mode': timelineMode == WatchTimelineMode.live ? 'live' : 'vod',
        'target_live_latency_ms': targetLiveLatencyMs,
      },
      includeExpectedRevision: false,
    );
  }

  Future<WatchPartyState> play() {
    return _command(WatchPartyCommand.play, const <String, dynamic>{});
  }

  Future<WatchPartyState> pause() {
    return _command(WatchPartyCommand.pause, const <String, dynamic>{});
  }

  Future<WatchPartyState> seek(int positionMs) {
    return _command(
      WatchPartyCommand.seek,
      <String, dynamic>{'position_ms': positionMs},
    );
  }

  Future<WatchPartyState> changeContent({
    String? provider,
    String? contentId,
    String? contentUrl,
    String? contentTitle,
    int positionMs = 0,
    WatchTimelineMode? timelineMode,
    int? targetLiveLatencyMs,
  }) {
    return _command(
      WatchPartyCommand.changeContent,
      <String, dynamic>{
        if (provider?.trim().isNotEmpty == true) 'provider': provider!.trim(),
        if (contentId?.trim().isNotEmpty == true) 'content_id': contentId!.trim(),
        if (contentUrl?.trim().isNotEmpty == true)
          'content_url': contentUrl!.trim(),
        if (contentTitle?.trim().isNotEmpty == true)
          'content_title': contentTitle!.trim(),
        'position_ms': positionMs,
        if (timelineMode != null)
          'timeline_mode': timelineMode == WatchTimelineMode.live ? 'live' : 'vod',
        'target_live_latency_ms': targetLiveLatencyMs,
      },
    );
  }

  Future<WatchPartyState> sync({
    required int positionMs,
    required WatchPlaybackState playbackState,
    double playbackRate = 1,
  }) {
    return _command(
      WatchPartyCommand.sync,
      <String, dynamic>{
        'position_ms': positionMs,
        'playback_state': playbackState == WatchPlaybackState.playing
            ? 'playing'
            : 'paused',
        'playback_rate': playbackRate,
      },
    );
  }

  Future<WatchPartyState> end() {
    return _command(WatchPartyCommand.end, const <String, dynamic>{});
  }

  Future<WatchPartyState> transferControl(int targetBackendUserId) {
    return _command(
      WatchPartyCommand.transferControl,
      <String, dynamic>{'target_user_id': targetBackendUserId},
    );
  }

  Future<WatchPartyState> _command(
    WatchPartyCommand command,
    Map<String, dynamic> payload, {
    bool includeExpectedRevision = true,
  }) async {
    try {
      final session = state.session;
      final response = await _networkClient.postMap(
        '/rooms/$_roomId/realtime/watch-party/command',
        headers: _headers(),
        body: <String, dynamic>{
          'action': _wireName(command),
          if (includeExpectedRevision && session != null)
            'expected_revision': session.revision,
          ...payload,
        },
      );
      final raw = response['room'];
      final room = raw is Map<String, dynamic>
          ? Map<String, dynamic>.from(raw)
          : raw is Map
          ? raw.cast<String, dynamic>()
          : null;
      if (room == null) {
        throw StateError(
          'Watch Party command response is missing canonical room state.',
        );
      }

      final roomState = _roomSessionRepository.reconcileSnapshot(room);
      reconcileRoomState(roomState);
      return state;
    } catch (error) {
      state = state.copyWith(errorMessage: _errorMessage(error));
      rethrow;
    }
  }

  Map<String, String> _headers() {
    final token = _accessTokenProvider()?.trim();
    if (token == null || token.isEmpty) {
      throw StateError('Authenticated session required for Watch Party.');
    }
    return <String, String>{'Authorization': 'Bearer $token'};
  }

  String _errorMessage(Object error) {
    if (error is ApiException && error.body is Map) {
      final detail = (error.body as Map)['detail']?.toString().trim();
      if (detail != null && detail.isNotEmpty) return detail;
    }
    return error.toString().replaceFirst('Exception: ', '').trim();
  }
}

String _wireName(WatchPartyCommand command) {
  switch (command) {
    case WatchPartyCommand.load:
      return 'LOAD';
    case WatchPartyCommand.play:
      return 'PLAY';
    case WatchPartyCommand.pause:
      return 'PAUSE';
    case WatchPartyCommand.seek:
      return 'SEEK';
    case WatchPartyCommand.changeContent:
      return 'CHANGE_CONTENT';
    case WatchPartyCommand.sync:
      return 'SYNC';
    case WatchPartyCommand.end:
      return 'END';
    case WatchPartyCommand.transferControl:
      return 'TRANSFER_CONTROL';
  }
}

final watchPartyRepositoryProvider = StateNotifierProvider.autoDispose.family<
    WatchPartyRepository,
    WatchPartyState,
    String>((ref, roomId) {
  final roomSession = ref.read(roomSessionRepositoryProvider(roomId).notifier);
  final repository = WatchPartyRepository(
    roomId: roomId,
    networkClient: ref.read(appNetworkClientProvider),
    accessTokenProvider: () =>
        ref.read(sessionRepositoryProvider).accessToken,
    roomSessionRepository: roomSession,
  );

  repository.reconcileRoomState(ref.read(roomSessionRepositoryProvider(roomId)));
  ref.listen<RoomSessionState>(
    roomSessionRepositoryProvider(roomId),
    (_, next) => repository.reconcileRoomState(next),
  );
  return repository;
});
