import '../../foundation/runtime/media_resource_lifecycle.dart';

/// Optional lifecycle binding implemented by room-media engines whose concrete
/// platform delegate owns feature-level resources such as microphone capture.
abstract interface class RoomMediaResourceRegistryBinding {
  void bindMediaResourceRegistry(MediaResourceRegistry? registry);
}
