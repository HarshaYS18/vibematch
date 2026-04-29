import '../live_room_models.dart';

class LiveRoomVibeSyncController {
  const LiveRoomVibeSyncController();

  VibeSyncRoomState pickFirstUser({
    required VibeSyncRoomState state,
    required SeatUser user,
  }) {
    return state.copyWith(
      active: false,
      announced: false,
      firstUser: user,
      statusText: 'First user picked: ${user.name}',
    );
  }

  VibeSyncRoomState pickSecondUser({
    required VibeSyncRoomState state,
    required SeatUser user,
  }) {
    return state.copyWith(
      active: false,
      announced: false,
      secondUser: user,
      statusText: 'Second user picked: ${user.name}',
    );
  }

  VibeSyncAnnouncement? announce(VibeSyncRoomState state) {
    final first = state.firstUser;
    final second = state.secondUser;
    if (first == null || second == null) return null;

    final nextState = state.copyWith(
      active: true,
      announced: true,
      statusText: '${first.name} and ${second.name} are matched by VibeSync',
    );

    return VibeSyncAnnouncement(
      state: nextState,
      systemMessage: 'VibeSync announced ${first.name} × ${second.name}',
    );
  }

  VibeSyncRoomState end() {
    return VibeSyncRoomState.inactive;
  }

  String endSystemMessage() {
    return 'VibeSync match cleared';
  }

  VibeSyncRoomState clearOverlay(VibeSyncRoomState state) {
    return state.copyWith(active: false);
  }
}

class VibeSyncAnnouncement {
  const VibeSyncAnnouncement({
    required this.state,
    required this.systemMessage,
  });

  final VibeSyncRoomState state;
  final String systemMessage;
}
