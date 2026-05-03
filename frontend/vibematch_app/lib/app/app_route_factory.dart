import 'package:flutter/material.dart';

import '../core/presentation/vm_skeleton_page.dart';
import '../features/auth/presentation/auth_gate.dart';
import '../features/control_center/presentation/control_center_page.dart';
import '../features/events/presentation/events_page.dart';
import '../features/family/presentation/family_page.dart';
import '../features/love_bond/presentation/love_bond_page.dart';
import '../features/notifications/presentation/notifications_page.dart';
import '../features/profile/presentation/public_profile_page.dart';
import '../features/rankings/presentation/rankings_page.dart';
import '../features/rooms/presentation/live_room_page.dart';
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
        return _buildRoute(
          settings,
          args is LiveRoomRouteArgs
              ? LiveRoomPage(
                  roomName: args.roomName,
                  roomId: args.roomId,
                  language: args.language,
                  modeTitle: args.modeTitle,
                  onlineCount: args.onlineCount,
                )
              : const LiveRoomPage(),
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
          VmSkeletonPage(
            title: _titleForRoute(settings.name),
            subtitle: 'This module route is registered and ready for backend wiring.',
            icon: Icons.auto_awesome_rounded,
            highlights: const [
              'Route is intentionally lightweight for performance.',
              'Feature-specific modules can be connected here without touching the main shell.',
            ],
          ),
        );
    }
  }

  static MaterialPageRoute<dynamic> _buildRoute(RouteSettings settings, Widget page) {
    return MaterialPageRoute<dynamic>(settings: settings, builder: (_) => page);
  }

  static String _titleForRoute(String? routeName) {
    if (routeName == null || routeName.trim().isEmpty) return 'Vibe Match';
    final clean = routeName.replaceAll('/', ' ').replaceAll('-', ' ').trim();
    if (clean.isEmpty) return 'Vibe Match';
    return clean
        .split(RegExp(r'\s+'))
        .map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }
}
