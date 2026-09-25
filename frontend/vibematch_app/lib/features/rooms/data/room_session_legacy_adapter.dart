import 'dart:async';

import '../../../foundation/realtime/realtime_event_envelope.dart';
import '../../../realtime/app_realtime_hub.dart';
import '../../../room_session/data/room_session_repository.dart';
import '../../../room_session/domain/room_session_state.dart';
import '../presentation/live_room_models.dart';
import 'live_room_media_signaling_service.dart';
import 'live_room_presence_repository.dart';

/// Pure read-only presentation adapter.
///
/// Chunk 33 removed all legacy cache writes. RoomSessionRepository is the only
/// mutable room-session authority; this adapter only maps canonical state into
/// legacy presentation shapes while those widgets are still being retired.
class RoomSessionLegacyAdapter {
  const RoomSessionLegacyAdapter._();

  static LiveRoomPresenceSnapshot toPresenceSnapshot(
    RoomSessionState state, {
    int? currentPublicUserId,
  }) {
    final participants = <SeatUser>[];
    SeatUser? joinedUser;
    final membership = <String, bool>{};

    for (final participant in state.presence.values) {
      final user = toSeatUser(participant);
      participants.add(user);
      membership[user.id] =
          participant.isMember || participant.isAdmin || participant.isHost;
      if (participant.publicUserId == currentPublicUserId) {
        joinedUser = user.copyWith(isCurrentUser: true);
      }
    }

    for (final entry in state.membershipRoster.values) {
      membership['user_${entry.publicUserId}'] =
          entry.isMember || entry.isAdmin || entry.isHost;
    }

    return LiveRoomPresenceSnapshot(
      roomId: state.roomId,
      onlineCount: state.onlineCount,
      participants: List<SeatUser>.unmodifiable(participants),
      roomMemberByUserId: Map<String, bool>.unmodifiable(membership),
      joinedUser: joinedUser,
      shouldShowEnteredMessage: false,
    );
  }

  static SeatUser toSeatUser(RoomSessionParticipant participant) {
    final raw = <String, dynamic>{
      ...participant.raw,
      'is_owner': participant.isHost,
      'is_member': participant.isMember,
      'is_room_member': participant.isMember,
      'is_room_admin': participant.isAdmin,
      'mic_enabled': participant.micEnabled,
      'admin_muted': participant.adminMuted,
    };
    return LiveRoomPresenceSnapshot.participantToSeatUser(raw).copyWith(
      isHost: participant.isHost,
      isRoomAdmin: participant.isAdmin || participant.isHost,
      selfMuted: !participant.micEnabled,
      adminMuted: participant.adminMuted,
    );
  }


  static List<SeatUser> presenceUsers(RoomSessionState state) {
    return state.presence.values
        .map(toSeatUser)
        .toList(growable: false);
  }

  static SeatUser? findPresenceUser(
    RoomSessionState state,
    String userId,
  ) {
    final aliases = _identityAliases(userId);
    if (aliases.isEmpty) return null;
    for (final participant in state.presence.values) {
      final participantAliases = <String>{
        participant.backendUserId.toString(),
        participant.publicUserId.toString(),
        'user_${participant.publicUserId}',
        participant.roomUserKey.toLowerCase(),
      };
      if (aliases.intersection(participantAliases).isNotEmpty) {
        return toSeatUser(participant);
      }
    }
    return null;
  }

  static Set<String> _identityAliases(String rawId) {
    final value = rawId.trim().toLowerCase();
    if (value.isEmpty) return const <String>{};
    final aliases = <String>{value};
    final match = RegExp(r'(?:^|_)user_(\d+)$').firstMatch(value);
    if (match != null) {
      aliases.add(match.group(1)!);
      aliases.add('user_${match.group(1)!}');
    }
    final direct = int.tryParse(value);
    if (direct != null) {
      aliases.add(direct.toString());
      aliases.add('user_$direct');
    }
    return aliases;
  }
}

/// Temporary transport projection bridge.
///
/// Realtime deltas are reconciled into RoomSessionRepository first. The bridge
/// only forwards the resulting canonical room map to the media compatibility
/// layer; it never writes another participant/membership/settings cache.
class RoomSessionLegacyRealtimeBridge {
  RoomSessionLegacyRealtimeBridge({
    required this.roomId,
    required this.repository,
    required this.mediaSignalingService,
    AppRealtimeHub? hub,
  }) : _hub = hub ?? AppRealtimeHub.shared;

  final String roomId;
  final RoomSessionRepository repository;
  final LiveRoomMediaSignalingService mediaSignalingService;
  final AppRealtimeHub _hub;

  StreamSubscription<RealtimeEventEnvelope>? _eventSubscription;
  StreamSubscription<RealtimeResyncRequest>? _resyncSubscription;
  bool _active = false;
  bool _recovering = false;

  void start() {
    _eventSubscription ??= _hub.events.listen(_handleEvent);
    _resyncSubscription ??= _hub.resyncRequests.listen(_handleResync);
  }

  Future<void> activate() async {
    if (_active) return;
    _active = true;
    start();
    await _hub.start();
    _hub.subscribeRoom(roomId);
  }

  void _handleEvent(RealtimeEventEnvelope event) {
    if (!_active || !_belongsToRoom(event)) return;
    if (event.type == 'subscribed' ||
        event.type == 'subscription_revoked' ||
        event.type == 'command/ack' ||
        event.type == 'command/error') {
      return;
    }

    final previousVersion = repository.currentState.stateVersion;
    final previousEventSequence = repository.currentState.eventSequence;
    final next = repository.reconcileRealtimeEvent(event.raw);
    if (next.stateVersion == previousVersion &&
        next.eventSequence == previousEventSequence) {
      return;
    }
    _project(next);
  }

  void _handleResync(RealtimeResyncRequest request) {
    if (!_active || _recovering) return;
    final streamMatches = request.stream.startsWith('room:$roomId:');
    final roomMatches = request.roomId?.trim() == roomId.trim();
    if (!streamMatches && !roomMatches) return;

    _recovering = true;
    unawaited(
      repository
          .recoverFromRealtimeGap()
          .then((state) {
            _project(state);
            final sequence = request.observedSequence ?? 0;
            final stream = request.stream.trim();
            if (stream.isNotEmpty && stream != '*' && sequence > 0) {
              _hub.markResynced(stream, sequence);
              _hub.subscribeRoom(
                roomId,
                stream: stream,
                lastSequence: sequence,
              );
            } else {
              _hub.subscribeRoom(roomId);
            }
          })
          .whenComplete(() {
            _recovering = false;
          }),
    );
  }

  bool _belongsToRoom(RealtimeEventEnvelope event) {
    if (event.stream.startsWith('room:$roomId:')) return true;

    final legacy = event.toLegacyEvent();
    final nested = _asMap(legacy['payload']);
    for (final candidate in <dynamic>[
      legacy['room_id'],
      legacy['room_public_id'],
      nested['room_id'],
      nested['room_public_id'],
    ]) {
      if (candidate?.toString().trim() == roomId.trim()) return true;
    }
    return false;
  }

  void _project(RoomSessionState state) {
    mediaSignalingService.applyCanonicalRoomState(state.room);
  }

  void deactivate() {
    if (!_active) return;
    _active = false;
    _hub.unsubscribeRoom(roomId);
  }

  void dispose() {
    _active = false;
    unawaited(_eventSubscription?.cancel());
    unawaited(_resyncSubscription?.cancel());
    _eventSubscription = null;
    _resyncSubscription = null;
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return const <String, dynamic>{};
}
