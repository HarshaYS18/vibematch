import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../foundation/di/app_dependencies.dart';
import '../../foundation/networking/app_network_client.dart';
import '../../session/data/session_repository.dart';
import '../domain/room_session_state.dart';

class RoomSessionRepository extends StateNotifier<RoomSessionState> {
  RoomSessionRepository({
    required String roomId,
    required AppNetworkClient networkClient,
    required String? Function() accessTokenProvider,
  })  : _roomId = roomId.trim(),
        _networkClient = networkClient,
        _accessTokenProvider = accessTokenProvider,
        super(RoomSessionState.initial(roomId.trim()));

  final String _roomId;
  final AppNetworkClient _networkClient;
  final String? Function() _accessTokenProvider;

  /// Read-only snapshot for compatibility adapters during the Chunk 21 cutover.
  ///
  /// RoomSessionRepository remains the single mutable room-session authority;
  /// callers can inspect the current state but cannot assign StateNotifier.state.
  RoomSessionState get currentState => state;

  Future<RoomSessionState> join({String? lockPassword}) async {
    state = state.copyWith(
      connection: RoomSessionConnection.joining,
      clearError: true,
    );
    try {
      final response = await _networkClient.postMap(
        '/rooms/$_roomId/realtime/join',
        headers: _headers(),
        body: <String, dynamic>{
          if (lockPassword?.trim().isNotEmpty == true)
            'lock_password': lockPassword!.trim(),
        },
      );
      return reconcileSnapshot(
        _room(response),
        connection: RoomSessionConnection.connected,
        force: true,
      );
    } catch (error) {
      _fail(error);
      rethrow;
    }
  }

  Future<RoomSessionState> refreshAfterReconnect() async {
    state = state.copyWith(
      connection: RoomSessionConnection.reconnecting,
      clearError: true,
    );
    return refreshSnapshot(
      connection: RoomSessionConnection.connected,
      force: true,
    );
  }

  Future<RoomSessionState> refreshSnapshot({
    RoomSessionConnection? connection,
    bool force = false,
  }) async {
    try {
      final response = await _networkClient.getMap(
        '/rooms/$_roomId/realtime/snapshot',
        headers: _headers(),
      );
      return reconcileSnapshot(
        _room(response),
        connection: connection,
        force: force,
      );
    } catch (error) {
      _fail(error, preserveConnection: true);
      rethrow;
    }
  }

  RoomSessionState reconcileSnapshot(
    Map<String, dynamic> snapshot, {
    RoomSessionConnection? connection,
    bool force = false,
  }) {
    if (!force && state.connection == RoomSessionConnection.left) {
      return state;
    }

    final normalized = <String, dynamic>{
      ...snapshot,
      if ((snapshot['room_id']?.toString().trim() ?? '').isEmpty)
        'room_id': _roomId,
    };
    final incoming = RoomSessionState.fromSnapshot(
      normalized,
      connection:
          connection ??
          (state.connection == RoomSessionConnection.reconnecting
              ? RoomSessionConnection.connected
              : state.connection == RoomSessionConnection.idle ||
                    state.connection == RoomSessionConnection.joining
              ? RoomSessionConnection.connected
              : state.connection),
    );

    if (!force &&
        state.stateVersion > 0 &&
        incoming.stateVersion > 0 &&
        incoming.stateVersion < state.stateVersion) {
      return state;
    }

    state = incoming.copyWith(clearError: true);
    return state;
  }

  RoomSessionState reconcileDelta(
    Map<String, dynamic> delta, {
    RoomSessionConnection? connection,
  }) {
    if (state.connection == RoomSessionConnection.left) return state;

    final incomingVersion = _asInt(
      delta['room_version'] ?? delta['state_version'],
    );
    if (incomingVersion > 0 &&
        state.stateVersion > 0 &&
        incomingVersion < state.stateVersion) {
      return state;
    }

    final incomingEventSequence = _asInt(delta['event_sequence']);
    final merged = <String, dynamic>{
      ...state.room,
      ...delta,
      'room_id': _roomId,
      if (incomingVersion > 0) 'state_version': incomingVersion,
      if (incomingEventSequence > 0)
        'event_sequence': incomingEventSequence,
    };
    return reconcileSnapshot(
      merged,
      connection: connection ?? RoomSessionConnection.connected,
      force: true,
    );
  }

  RoomSessionState reconcileRealtimeEvent(Map<String, dynamic> event) {
    final outerPayload = _asMap(event['payload']);
    final wireEvent = outerPayload.containsKey('payload')
        ? outerPayload
        : event;
    final body = _asMap(wireEvent['payload']);
    final delta = _asMap(body['delta']);
    if (delta.isEmpty) return state;
    return reconcileDelta(delta);
  }

  Future<RoomSessionState> recoverFromRealtimeGap() {
    return refreshSnapshot(
      connection: RoomSessionConnection.connected,
      force: true,
    );
  }

  Future<RoomSessionState> takeSeat(int seatIndex) {
    return _postCanonical(
      '/rooms/$_roomId/realtime/seat/take',
      <String, dynamic>{'seat_index': seatIndex},
    );
  }

  Future<RoomSessionState> leaveSeat() {
    return _postCanonical(
      '/rooms/$_roomId/realtime/seat/leave',
      const <String, dynamic>{},
    );
  }

  Future<RoomSessionState> setMicEnabled(bool enabled) {
    return _postCanonical(
      '/rooms/$_roomId/realtime/mic',
      <String, dynamic>{'enabled': enabled},
    );
  }

  Future<RoomSessionState> activityCommand({
    required String action,
    int? expectedRevision,
    String? kind,
    String? activityId,
    String? title,
    String? phase,
    String? gameId,
    int? targetUserId,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? postGame,
  }) {
    return _postCanonical(
      '/rooms/$_roomId/realtime/activity/command',
      <String, dynamic>{
        'action': action.trim().toUpperCase(),
        'expected_revision': ?expectedRevision,
        if (kind?.trim().isNotEmpty == true) 'kind': kind!.trim(),
        if (activityId?.trim().isNotEmpty == true) 'activity_id': activityId!.trim(),
        if (title?.trim().isNotEmpty == true) 'title': title!.trim(),
        if (phase?.trim().isNotEmpty == true) 'phase': phase!.trim(),
        if (gameId?.trim().isNotEmpty == true) 'game_id': gameId!.trim(),
        'target_user_id': ?targetUserId,
        'metadata': ?metadata,
        'post_game': ?postGame,
      },
    );
  }

  Future<RoomSessionState> _postCanonical(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _networkClient.postMap(
        path,
        headers: _headers(),
        body: body,
      );
      return reconcileSnapshot(
        _room(response),
        connection: RoomSessionConnection.connected,
        force: true,
      );
    } catch (error) {
      _fail(error, preserveConnection: true);
      rethrow;
    }
  }

  Future<RoomSessionState> leave() async {
    if (state.connection == RoomSessionConnection.left) return state;

    state = state.copyWith(
      connection: RoomSessionConnection.leaving,
      clearError: true,
    );
    try {
      final response = await _networkClient.postMap(
        '/rooms/$_roomId/realtime/leave',
        headers: _headers(),
        body: const <String, dynamic>{'release_seat': true},
      );
      final left = reconcileSnapshot(
        _room(response),
        connection: RoomSessionConnection.left,
        force: true,
      );
      state = left.copyWith(
        connection: RoomSessionConnection.left,
        clearError: true,
      );
      return state;
    } catch (error) {
      _fail(error, preserveConnection: true);
      rethrow;
    }
  }

  Map<String, String> _headers() {
    final token = _accessTokenProvider()?.trim();
    if (token == null || token.isEmpty) {
      throw StateError('Authenticated session required for room access.');
    }
    return <String, String>{'Authorization': 'Bearer $token'};
  }

  Map<String, dynamic> _room(
    Map<String, dynamic> response, {
    bool preserveServerOmissions = false,
  }) {
    final raw = response['room'];
    final room = raw is Map<String, dynamic>
        ? Map<String, dynamic>.from(raw)
        : raw is Map
        ? raw.cast<String, dynamic>()
        : null;
    if (room == null) {
      throw StateError('Room command response is missing canonical room state.');
    }

    if (!preserveServerOmissions) return room;

    final rawOmissions = response['omitted_sections'];
    if (rawOmissions is! List) return room;

    for (final item in rawOmissions) {
      final key = item?.toString().trim();
      if (key == null || key.isEmpty || room.containsKey(key)) continue;
      if (state.room.containsKey(key)) {
        room[key] = state.room[key];
      }
    }
    return room;
  }

  void _fail(Object error, {bool preserveConnection = false}) {
    final message = _roomErrorMessage(error);
    state = state.copyWith(
      connection: preserveConnection
          ? state.connection
          : RoomSessionConnection.failed,
      errorMessage: message,
    );
  }

  String _roomErrorMessage(Object error) {
    if (error is ApiException && error.body is Map) {
      final detail = (error.body as Map)['detail'];
      final message = detail?.toString().trim();
      if (message != null && message.isNotEmpty) return message;
    }
    return error.toString().replaceFirst('Exception: ', '').trim();
  }
}

final roomSessionRepositoryProvider = StateNotifierProvider.family<
    RoomSessionRepository,
    RoomSessionState,
    String>((ref, roomId) {
  return RoomSessionRepository(
    roomId: roomId,
    networkClient: ref.read(appNetworkClientProvider),
    accessTokenProvider: () =>
        ref.read(sessionRepositoryProvider).accessToken,
  );
});


Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return const <String, dynamic>{};
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
