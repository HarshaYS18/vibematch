import 'dart:async';

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
    final canonical =
        LiveRoomPresenceSnapshot.participantToSeatUser(raw);
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

class RoomSessionLegacyRealtimeBridge {
  RoomSessionLegacyRealtimeBridge({
    required this.roomId,
    required this.repository,
    required this.mediaSignalingService,
  });

  final String roomId;
  final RoomSessionRepository repository;
  final LiveRoomMediaSignalingService mediaSignalingService;

  StreamSubscription<Map<String, dynamic>>? _subscription;

  void start() {
    _subscription ??= mediaSignalingService.canonicalRoomSnapshotEvents.listen(
      (snapshot) {
        final snapshotRoomId =
            snapshot['room_id']?.toString() ??
            snapshot['room_public_id']?.toString();
        if (snapshotRoomId != null &&
            snapshotRoomId.trim().isNotEmpty &&
            snapshotRoomId.trim() != roomId.trim()) {
          return;
        }

        final state = repository.reconcileSnapshot(snapshot);
        RoomSessionLegacyAdapter.publishLegacy(state);
      },
    );
  }

  void dispose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
  }
}
