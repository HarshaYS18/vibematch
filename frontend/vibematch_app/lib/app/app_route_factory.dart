import 'package:flutter/material.dart';

import '../features/auth/presentation/auth_gate.dart';
import '../features/control_center/presentation/control_center_page.dart';
import '../features/events/presentation/events_page.dart';
import '../features/family/presentation/family_page.dart';
import '../features/love_bond/presentation/love_bond_page.dart';
import '../features/notifications/presentation/notifications_page.dart';
import '../features/profile/presentation/public_profile_page.dart';
import '../features/rankings/presentation/rankings_page.dart';
import '../features/rooms/presentation/live_room_page.dart';
import '../features/rooms/presentation/room_preview_page.dart';
import '../features/search/presentation/search_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/store/presentation/store_page.dart';
import '../features/vip/presentation/vip_page.dart';
import '../features/wallet/presentation/wallet_page.dart';
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
          return _buildRoute(
            settings,
            LiveRoomPage(
              roomName: args.roomName,
              roomId: args.roomId,
              language: args.language,
              modeTitle: args.modeTitle,
              onlineCount: args.onlineCount,
            ),
          );
        }
        return _buildRoute(settings, const LiveRoomPage());

      case VmRoutes.roomPreview:
        final args = settings.arguments;
        if (args is RoomPreviewRouteArgs) {
          return _buildRoute(
            settings,
            RoomPreviewPage(
              roomName: args.roomName,
              roomId: args.roomId,
              language: args.language,
              modeTitle: args.modeTitle,
              onlineCount: args.onlineCount,
            ),
          );
        }
        return _buildRoute(settings, const RoomPreviewPage());

      case VmRoutes.profile:
        final args = settings.arguments;
        if (args is PublicProfileRouteArgs) {
          return _buildRoute(
            settings,
            PublicProfilePage(
              userId: args.userId,
              displayName: args.displayName,
              username: args.username,
            ),
          );
        }
        return _buildRoute(settings, const PublicProfilePage());

      case VmRoutes.events:
        return _buildRoute(settings, const EventsPage());
      case VmRoutes.rankings:
        return _buildRoute(settings, const RankingsPage());
      case VmRoutes.wallet:
        return _buildRoute(settings, const WalletPage());
      case VmRoutes.store:
        return _buildRoute(settings, const StorePage());
      case VmRoutes.settings:
        return _buildRoute(settings, const SettingsPage());
      case VmRoutes.family:
        return _buildRoute(settings, const FamilyPage());
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

      default:
        return _buildRoute(
          settings,
          UnknownRoutePage(routeName: settings.name ?? 'unknown'),
        );
    }
  }

  static MaterialPageRoute<dynamic> _buildRoute(
    RouteSettings settings,
    Widget page,
  ) {
    return MaterialPageRoute<dynamic>(
      settings: settings,
      builder: (_) => page,
    );
  }
}

class UnknownRoutePage extends StatelessWidget {
  const UnknownRoutePage({
    super.key,
    required this.routeName,
  });

  final String routeName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      appBar: AppBar(
        title: const Text('Route not found'),
        backgroundColor: const Color(0xFFFAF7F1),
        foregroundColor: const Color(0xFF251538),
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No route is registered for $routeName',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF251538),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
