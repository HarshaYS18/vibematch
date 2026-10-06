import 'package:flutter/material.dart';

import '../../core/growth/vm_growth_link.dart';
import '../../core/navigation/vm_navigator.dart';
import '../../core/ui/vm_motion.dart';
import '../../features/auth/models/current_user.dart';
import '../../features/events/presentation/events_page.dart';
import '../../features/family/presentation/family_modular_page.dart';
import '../../features/games/data/game_api_service.dart';
import '../../features/home/controllers/home_navigation_controller.dart';
import '../../features/home/models/home_room.dart';
import '../../features/rooms/data/room_api_service.dart';
import '../../features/vibes/data/vibes_api_service.dart';
import '../../features/vibes/presentation/pages/vibe_detail_backend_page.dart';
import '../../game_platform/presentation/remote_game_player_page.dart';

class VmGrowthRouter {
  const VmGrowthRouter._();

  static Future<void> open(
    BuildContext context, {
    required VmGrowthLink link,
    required CurrentUser currentUser,
  }) async {
    switch (link.destination) {
      case VmGrowthDestination.room:
        final room = await const RoomApiService().getRoom(link.id);
        if (!context.mounted) return;
        HomeNavigationController.openRoom(
          context: context,
          currentUser: currentUser,
          room: HomeRoom(
            id: room.id,
            name: room.name,
            subtitle: room.subtitle ?? '',
            language: room.language,
            mode: room.mode,
            type: room.type,
            onlineCount: room.onlineCount,
            trendingScore: room.trendingScore,
            followedFriendsInside: room.followedFriendsInside,
            coverPhotoUrl: room.coverPhotoUrl,
          ),
        );
        return;
      case VmGrowthDestination.vibe:
        final vibe = await const VibesApiService().getVibe(link.id);
        if (!context.mounted) return;
        await Navigator.of(context).push<void>(
          VmMotion.pageRoute<void>(
            settings: RouteSettings(name: 'shared-vibe:${link.id}'),
            page: VibeDetailBackendPage(vibe: vibe),
          ),
        );
        return;
      case VmGrowthDestination.profile:
        await VmNavigator.openPublicProfile<void>(
          context,
          userId: link.id,
          displayName: 'FunKey user',
        );
        return;
      case VmGrowthDestination.game:
        final catalog = await const GameApiService().loadCatalog();
        final game = catalog.where(
          (candidate) =>
              candidate.gameKey == link.id &&
              candidate.isEnabled &&
              (candidate.assetManifestUrl?.trim().isNotEmpty ?? false),
        );
        if (game.isEmpty) {
          throw Exception('This game is unavailable right now.');
        }
        if (!context.mounted) return;
        await Navigator.of(context).push<void>(
          VmMotion.pageRoute<void>(
            settings: RouteSettings(name: 'shared-game:${link.id}'),
            page: RemoteGamePlayerPage(gameId: link.id),
          ),
        );
        return;
      case VmGrowthDestination.event:
        if (!context.mounted) return;
        await Navigator.of(context).push<void>(
          VmMotion.pageRoute<void>(
            settings: RouteSettings(name: 'shared-event:${link.id}'),
            page: EventsPage(initialEventId: link.id),
          ),
        );
        return;
      case VmGrowthDestination.family:
        if (!context.mounted) return;
        await Navigator.of(context).push<void>(
          VmMotion.pageRoute<void>(
            settings: RouteSettings(name: 'shared-family:${link.id}'),
            page: const FamilyModularPage(),
          ),
        );
        return;
    }
  }
}
