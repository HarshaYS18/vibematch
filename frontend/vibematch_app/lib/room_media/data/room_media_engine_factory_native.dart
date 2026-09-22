import '../domain/room_media_engine.dart';
import 'native_mediasoup_engine.dart';

RoomMediaEngine createPlatformRoomMediaEngine() {
  return NativeMediasoupEngine();
}
