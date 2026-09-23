import 'dart:async';

import '../../../foundation/realtime/realtime_event_envelope.dart';
import '../../../realtime/app_realtime_hub.dart';
import '../../../room_session/data/room_session_repository.dart';
import '../../../room_session/domain/room_session_state.dart';
import '../presentation/live_room_models.dart';
import 'live_room_media_signaling_service.dart';
import 'live_room_membership_service.dart';
import 'live_room_presence_repository.dart';

class RoomSessionLegacyAdapter {
  const RoomSessionLegacyAdapter._();

  static LiveRoomPresenceSnapshot toPresenceSnapshot(
    RoomSessionState state, {
    int? currentPublicUserId,
    bool publishLegacyCaches = false,
  }) {
    final participants = <SeatUser>[];
    SeatUser? joinedUser;
    final membership = <String, bool>{};

    for (final participant in state.presence.values) {
      final user = _seatUser(participant);
      participants.add(user);
      membership[user.id] = participant.isMember;
      if (participant.publicUserId == currentPublicUserId) {
        joinedUser = user.copyWith(isCurrentUser: true);
      }
    }

    // Durable offline members stay members even when absent from presence.
    for (final entry in state.membershipRoster.values) {
      membership['user_${entry.publicUserId}'] =
          entry.isMember || entry.isAdmin || entry.isHost;
    }

    final snapshot = LiveRoomPresenceSnapshot(
      roomId: state.roomId,
      onlineCount: state.onlineCount,
      participants: List<SeatUser>.unmodifiable(participants),
      roomMemberByUserId: Map<String, bool>.unmodifiable(membership),
      joinedUser: joinedUser,
      shouldShowEnteredMessage: false,
    );

    if (publishLegacyCaches) {
      publishLegacy(state, snapshot: snapshot);
    }
    return snapshot;
  }

  static SeatUser _seatUser(RoomSessionParticipant participant) {
    final raw = <String, dynamic>{
      ...participant.raw,
      'is_owner': participant.isHost,
      'is_member': participant.isMember,
      'is_room_admin': participant.isAdmin,
    };
    final canonical = LiveRoomPresenceSnapshot.participantToSeatUser(raw);
    final existing =
        LiveRoomPresenceRepository.userByRoomUserId(canonical.id);

    if (existing == null) return canonical;
    return existing.copyWith(
      name: canonical.name,
      roleLabel: canonical.roleLabel,
      avatarUrl: canonical.avatarUrl,
      isHost: participant.isHost,
      isRoomAdmin: participant.isAdmin || participant.isHost,
      selfMuted: !participant.micEnabled,
      adminMuted: participant.adminMuted,
    );
  }

  static void publishLegacy(
    RoomSessionState state, {
    LiveRoomPresenceSnapshot? snapshot,
  }) {
    final resolved =
        snapshot ??
        toPresenceSnapshot(
          state,
          publishLegacyCaches: false,
        );
    LiveRoomPresenceRepository.publishParticipants(
      resolved.participants,
      roomId: state.roomId,
    );
    LiveRoomMembershipService.applyBackendMembershipSnapshot(
      roomId: state.roomId,
      roomMemberByUserId: resolved.roomMemberByUserId,
      completeRoster: true,
      onlineCount: state.onlineCount,
    );
  }
}

/// Chunk 21 compatibility bridge.
///
/// RoomSessionRepository remains the canonical room-state authority. The Go
/// application socket supplies v2 deltas and bounded replay; this bridge only
/// projects the reconciled canonical state into legacy UI/media adapters while
/// those consumers are being retired.
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

    final previousVersion = repository.state.stateVersion;
    final next = repository.reconcileRealtimeEvent(event.raw);
    if (next.stateVersion == previousVersion &&
        next.eventSequence == repository.state.eventSequence) {
      // Non-state room events (system messages, invites, etc.) are handled by
      // the compatibility media/event facade. There is nothing to project.
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
    RoomSessionLegacyAdapter.publishLegacy(state);
    mediaSignalingService.applyCanonicalRoomState(state.room);
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
