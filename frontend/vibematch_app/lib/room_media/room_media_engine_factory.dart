import 'data/room_media_engine_factory_native.dart'
    if (dart.library.js_interop) 'data/room_media_engine_factory_web.dart'
    as platform;
import 'domain/room_media_engine.dart';

/// Single platform-selection boundary for room media.
RoomMediaEngine createRoomMediaEngine() {
  return platform.createPlatformRoomMediaEngine();
}
