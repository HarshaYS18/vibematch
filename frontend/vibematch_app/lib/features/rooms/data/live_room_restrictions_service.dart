import 'package:flutter/foundation.dart';

class LiveRoomRestrictionsService {
  LiveRoomRestrictionsService._();

  static final ValueNotifier<LiveRoomRestrictionsState> state =
      ValueNotifier<LiveRoomRestrictionsState>(const LiveRoomRestrictionsState());

  static bool get roomImagesEnabled => state.value.roomImagesEnabled;
  static bool get guestMessagesEnabled => state.value.guestMessagesEnabled;

  static void update({
    bool? roomImagesEnabled,
    bool? guestMessagesEnabled,
    bool notify = true,
  }) {
    final nextState = state.value.copyWith(
      roomImagesEnabled: roomImagesEnabled,
      guestMessagesEnabled: guestMessagesEnabled,
    );

    if (nextState == state.value) return;
    state.value = nextState;
  }
}

@immutable
class LiveRoomRestrictionsState {
  const LiveRoomRestrictionsState({
    this.roomImagesEnabled = true,
    this.guestMessagesEnabled = true,
  });

  final bool roomImagesEnabled;
  final bool guestMessagesEnabled;

  LiveRoomRestrictionsState copyWith({
    bool? roomImagesEnabled,
    bool? guestMessagesEnabled,
  }) {
    return LiveRoomRestrictionsState(
      roomImagesEnabled: roomImagesEnabled ?? this.roomImagesEnabled,
      guestMessagesEnabled: guestMessagesEnabled ?? this.guestMessagesEnabled,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LiveRoomRestrictionsState &&
        other.roomImagesEnabled == roomImagesEnabled &&
        other.guestMessagesEnabled == guestMessagesEnabled;
  }

  @override
  int get hashCode => Object.hash(roomImagesEnabled, guestMessagesEnabled);
}
