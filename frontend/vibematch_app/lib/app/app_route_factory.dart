import 'package:flutter/material.dart';

import '../core/ui/vm_motion.dart';
import '../features/auth/presentation/auth_gate.dart';
import '../features/banner_manager/presentation/banner_manager_page.dart';
import '../features/control_center/presentation/control_center_page.dart';
import '../features/events/presentation/events_page.dart';
import '../features/experience/presentation/experience_detail_page.dart';
import '../features/family/presentation/family_modular_page.dart';
import '../features/games/presentation/games_page.dart';
import '../features/inbox/presentation/inbox_page.dart';
import '../features/love_bond/presentation/love_bond_page.dart';
import '../features/notifications/presentation/notifications_page.dart';
import '../features/profile/presentation/public_profile_page.dart';
import '../features/rankings/presentation/rankings_page.dart';
import '../features/room_level/presentation/room_level_page.dart';
import '../features/rooms/presentation/routes/live_room_route_args.dart';
import '../features/rooms/presentation/routes/live_room_routes.dart';
import '../features/search/presentation/search_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/store/presentation/inventory_page.dart';
import '../features/store/presentation/store_page.dart';
import '../features/vip/presentation/vip_page.dart';
import '../features/wallet/presentation/models/wallet_models.dart';
import '../features/wallet/presentation/wallet_page_modular.dart';
import 'app_routes.dart';

class AppRouteFactory {
  const AppRouteFactory._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case VmRoutes.auth:
        return _buildRoute(settings, const AuthGate());
      case VmRoutes.liveRoom:
        final args = settings.arguments;
        if (args is LiveRoomRouteArgs) {
          return LiveRoomRoutes.liveRoom(
            LiveRoomRouteViewArgs(
              roomName: args.roomName,
              roomId: args.roomId,
              language: args.language,
              modeTitle: args.modeTitle,
              onlineCount: args.onlineCount,
              currentUser: args.currentUser,
              lockPassword: args.lockPassword,
              entryTransition: args.entryTransition,
            ),
          );
        }
        return _buildRoute(
          settings,
          UnknownRoutePage(routeName: settings.name ?? VmRoutes.liveRoom),
        );
      case VmRoutes.roomLevel:
        return _buildRoute(settings, const RoomLevelPage());
      case VmRoutes.experienceDetail:
        final args = settings.arguments;
        return _buildRoute(
          settings,
          args is ExperienceDetailRouteArgs
              ? ExperienceDetailPage(args: args)
              : const ExperienceDetailPage(
                  args: ExperienceDetailRouteArgs(
                    kind: ExperienceDetailKind.sent,
                  ),
                ),
        );
      case VmRoutes.profile:
        final args = settings.arguments;
        return _buildRoute(
          settings,
          args is PublicProfileRouteArgs
              ? PublicProfilePage(
                  userId: args.userId,
                  displayName: args.displayName,
                  username: args.username,
                )
              : const PublicProfilePage(),
        );
      case VmRoutes.events:
        return _buildRoute(settings, const EventsPage());
      case VmRoutes.rankings:
        return _buildRoute(settings, const RankingsPage());
      case VmRoutes.wallet:
      case VmRoutes.recharge:
      case VmRoutes.transactions:
        return _buildRoute(
          settings,
          const WalletPageModular(initialSection: WalletSection.coins),
        );
      case VmRoutes.earnings:
      case VmRoutes.payouts:
        return _buildRoute(
          settings,
          const WalletPageModular(initialSection: WalletSection.ruby),
        );
      case VmRoutes.store:
        return _buildRoute(settings, const StorePage());
      case VmRoutes.inventory:
        return _buildRoute(settings, const InventoryPage());
      case VmRoutes.settings:
        return _buildRoute(settings, const SettingsPage());
      case VmRoutes.inbox:
        return _buildRoute(settings, const InboxPage());
      case VmRoutes.family:
        return _buildRoute(settings, const FamilyModularPage());
      case VmRoutes.loveBond:
        return _buildRoute(settings, const LoveBondPage());
      case VmRoutes.vip:
        return _buildRoute(settings, const VipPage());
      case VmRoutes.notifications:
        return _buildRoute(settings, const NotificationsPage());
      case VmRoutes.search:
        return _buildRoute(settings, const SearchPage());
      case VmRoutes.controlCenter:
        return _buildRoute(settings, const ControlCenterPage());
      case VmRoutes.bannerManager:
        return _buildRoute(settings, const BannerManagerPage());
      case VmRoutes.admin:
      case VmRoutes.reports:
        return _buildRoute(settings, const ControlCenterPage());
      case VmRoutes.privacy:
      case VmRoutes.blockList:
      case VmRoutes.security:
      case VmRoutes.language:
        return _buildRoute(settings, const SettingsPage());
      case VmRoutes.games:
        return _buildRoute(settings, const GamesPage());
      default:
        return _buildRoute(
          settings,
          UnknownRoutePage(routeName: settings.name ?? 'unknown'),
        );
    }
  }

  static Route<dynamic> _buildRoute(
    RouteSettings settings,
    Widget page,
  ) => VmMotion.pageRoute(settings: settings, page: page);
}

class UnknownRoutePage extends StatelessWidget {
  const UnknownRoutePage({super.key, required this.routeName});
  final String routeName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      appBar: AppBar(
        title: const Text('Link unavailable'),
        backgroundColor: const Color(0xFFFAF7F1),
        foregroundColor: const Color(0xFF251538),
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'This link is not a standalone destination. Open the feature from Home, Settings, or a live room.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: const Color(0xFF251538)),
          ),
        ),
      ),
    );
  }
}