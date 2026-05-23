import '../lifecycle/live_room_lifecycle_module.dart';
import '../live_room_controller_bundle.dart';
import '../live_room_games_actions_module.dart';

class LiveRoomGamesEntryModule {
  const LiveRoomGamesEntryModule._();

  static void openGamesSheet(LiveRoomControllerBundle bundle) {
    LiveRoomLifecycleModule.clearFocus(bundle);
    LiveRoomGamesActionsModule.openGamesSheet(context: bundle.context);
  }
}
