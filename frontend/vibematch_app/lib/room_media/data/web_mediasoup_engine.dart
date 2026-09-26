import '../domain/room_media_engine.dart';
import 'delegating_mediasoup_engine.dart';
import 'live_room_mediasoup_audio_delegate.dart';
import 'mediasoup_audio_delegate.dart';

/// Real Flutter Web mediasoup/WebRTC engine.
///
/// Playback stays on the existing flutter_webrtc + mediasoup transport. The
/// browser owns the output route, while the room UI keeps its tiny RTC media
/// elements mounted to satisfy browser autoplay/output requirements.
class WebMediasoupEngine extends DelegatingMediasoupEngine {
  WebMediasoupEngine({
    MediasoupAudioDelegate? delegate,
  }) : super(
          delegate: delegate ?? LiveRoomMediasoupAudioDelegate(),
        );

  @override
  RoomMediaEnginePlatform get platform => RoomMediaEnginePlatform.web;

  @override
  Future<void> preferSystemAudioRoute() async {
    // Browser audio routing is controlled by the browser/OS. No mock transport
    // or fake success path is used; transport remains real mediasoup/WebRTC.
  }
}
