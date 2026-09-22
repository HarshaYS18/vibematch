import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../domain/room_media_engine.dart';
import 'delegating_mediasoup_engine.dart';
import 'live_room_mediasoup_audio_delegate.dart';
import 'mediasoup_audio_delegate.dart';

class NativeMediasoupEngine extends DelegatingMediasoupEngine {
  NativeMediasoupEngine({
    MediasoupAudioDelegate? delegate,
  }) : super(
          delegate: delegate ?? LiveRoomMediasoupAudioDelegate(),
        );

  @override
  RoomMediaEnginePlatform get platform => RoomMediaEnginePlatform.native;

  @override
  Future<void> preferSystemAudioRoute() async {
    if (isDisposed) return;

    try {
      await Helper.setSpeakerphoneOn(false);
    } catch (_) {
      // Routing is best-effort on desktop/unsupported native targets.
    }
  }
}
