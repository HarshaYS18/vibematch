import '../domain/room_media_engine.dart';
import 'web_mediasoup_engine.dart';

RoomMediaEngine createPlatformRoomMediaEngine() {
  return WebMediasoupEngine();
}
