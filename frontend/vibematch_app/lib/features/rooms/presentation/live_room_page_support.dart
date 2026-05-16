part of 'live_room_page.dart';

const SeatUser _roomIdentityFallback = SeatUser(
  id: 'user_pending',
  name: 'Vibe User',
  roleLabel: 'Guest',
  familyName: '',
  familyLevel: 'bronze',
  relationshipText: '',
  vipLevel: 0,
  svipLevel: 0,
  sendingLevel: 0,
  receivingLevel: 0,
  sentExp: 0,
  receivedExp: 0,
  medals: <String>[],
  avatarColors: <Color>[Color(0xFF12C7B7), Color(0xFF6D5DF6)],
  isCurrentUser: true,
);

class _PendingSeatInvite {
  const _PendingSeatInvite({
    required this.inviterName,
    required this.invitedUser,
    required this.seatIndex,
  });

  final String inviterName;
  final SeatUser invitedUser;
  final int seatIndex;
}

extension _LiveRoomRestoreStateBuilder on _LiveRoomPageState {
  LiveRoomRestoreState _buildRestoreState() {
    return LiveRoomRestoreState(
      roomState: _roomStateController.snapshotForRestore(),
      messageState: _roomMessageController.snapshotForRestore(),
      seatState: _seatController.snapshotForRestore(),
      messageDraft: _messageController.text,
    );
  }
}
