import 'controllers/live_room_state_controller.dart';
import 'live_room_models.dart';

class LiveRoomRestoreState {
  const LiveRoomRestoreState({
    required this.roomState,
    required this.messageState,
    required this.seatState,
    required this.messageDraft,
  });

  final LiveRoomStateSnapshot roomState;
  final LiveRoomMessageRestoreState messageState;
  final LiveRoomSeatRestoreState seatState;
  final String messageDraft;
}

class LiveRoomMessageRestoreState {
  const LiveRoomMessageRestoreState({
    required this.messages,
    required this.joinRequestUsers,
  });

  final List<ChatEntry> messages;
  final List<SeatUser> joinRequestUsers;
}

class LiveRoomSeatRestoreState {
  const LiveRoomSeatRestoreState({
    required this.layoutId,
    required this.seats,
    required this.micMuted,
    this.selectedSeatIndex,
  });

  final String layoutId;
  final List<RoomSeat> seats;
  final bool micMuted;
  final int? selectedSeatIndex;
}
