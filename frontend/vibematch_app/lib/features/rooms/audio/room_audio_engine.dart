import 'package:flutter/foundation.dart';

import 'room_audio_state.dart';

abstract class RoomAudioEngine extends ChangeNotifier {
  RoomAudioState get state;

  Future<void> joinAsAudience({
    required String roomId,
    required String peerId,
    required String audioToken,
  });

  Future<void> takeSpeakerSeat(int seatNo);

  Future<void> leaveSpeakerSeat();

  Future<void> publishMic();

  Future<void> stopPublishing();

  Future<void> setSelfMuted(bool muted);

  Future<void> leaveRoomAudio();
}
