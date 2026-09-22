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

  Future<RoomSessionState> heartbeat() async {
    try {
      final response = await _networkClient.postMap(
        '/rooms/$_roomId/realtime/heartbeat',
        headers: _headers(),
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

  Map<String, dynamic> _room(Map<String, dynamic> response) {
    final raw = response['room'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return raw.cast<String, dynamic>();
    throw StateError('Room command response is missing canonical room state.');
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
