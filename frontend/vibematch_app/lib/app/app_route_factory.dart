import 'package:flutter/material.dart';

import '../core/presentation/vm_skeleton_page.dart';
import '../features/auth/presentation/auth_gate.dart';
import '../features/banner_manager/presentation/banner_manager_page.dart';
import '../features/control_center/presentation/control_center_page.dart';
import '../features/events/presentation/events_page.dart';
import '../features/experience/presentation/experience_detail_page.dart';
import '../features/family/presentation/family_modular_page.dart';
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
          return LiveRoomRoutes.liveRoom(LiveRoomRouteViewArgs(roomName: args.roomName, roomId: args.roomId, language: args.language, modeTitle: args.modeTitle, onlineCount: args.onlineCount, currentUser: args.currentUser, lockPassword: args.lockPassword));
        }
        return _buildRoute(settings, const VmSkeletonPage(title: 'Room Locked', subtitle: 'Open rooms from Home after access check.', icon: Icons.lock_rounded));

      case VmRoutes.roomLevel:
        return _buildRoute(settings, const RoomLevelPage());
      case VmRoutes.experienceDetail:
        final args = settings.arguments;
        return _buildRoute(settings, args is ExperienceDetailRouteArgs ? ExperienceDetailPage(args: args) : const ExperienceDetailPage(args: ExperienceDetailRouteArgs(kind: ExperienceDetailKind.sent)));
      case VmRoutes.profile:
        final args = settings.arguments;
        return _buildRoute(settings, args is PublicProfileRouteArgs ? PublicProfilePage(userId: args.userId, displayName: args.displayName, username: args.username) : const PublicProfilePage());
      case VmRoutes.events:
        return _buildRoute(settings, const EventsPage());
      case VmRoutes.rankings:
        return _buildRoute(settings, const RankingsPage());
      case VmRoutes.wallet:
      case VmRoutes.recharge:
      case VmRoutes.transactions:
        return _buildRoute(settings, const WalletPageModular(initialSection: WalletSection.coins));
      case VmRoutes.earnings:
      case VmRoutes.payouts:
        return _buildRoute(settings, const WalletPageModular(initialSection: WalletSection.ruby));
      case VmRoutes.store:
        return _buildRoute(settings, const StorePage());
      case VmRoutes.inventory:
        return _buildRoute(settings, const InventoryPage());
      case VmRoutes.settings:
        return _buildRoute(settings, const SettingsPage());
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
      case VmRoutes.agency:
        return _buildRoute(settings, const VmSkeletonPage(title: 'Agency', subtitle: 'Manage hosts, admins and agency rewards.', icon: Icons.groups_2_rounded));
      case VmRoutes.gifts:
        return _buildRoute(settings, const VmSkeletonPage(title: 'Gifts', subtitle: 'Gift catalog, combos and received gifts.', icon: Icons.card_giftcard_rounded));
      case VmRoutes.admin:
        return _buildRoute(settings, const VmSkeletonPage(title: 'Admin', subtitle: 'Manage users, roles, reports and safety.', icon: Icons.shield_rounded));
      case VmRoutes.reports:
        return _buildRoute(settings, const VmSkeletonPage(title: 'Reports', subtitle: 'Review reports and safety actions.', icon: Icons.report_rounded));
      case VmRoutes.privacy:
        return _buildRoute(settings, const VmSkeletonPage(title: 'Privacy', subtitle: 'Profile, messages and presence settings.', icon: Icons.privacy_tip_rounded));
      case VmRoutes.blockList:
        return _buildRoute(settings, const VmSkeletonPage(title: 'Block List', subtitle: 'Blocked users and safety controls.', icon: Icons.block_rounded));
      case VmRoutes.security:
        return _buildRoute(settings, const VmSkeletonPage(title: 'Security', subtitle: 'Devices, sessions and login safety.', icon: Icons.security_rounded));
      case VmRoutes.language:
        return _buildRoute(settings, const VmSkeletonPage(title: 'Language', subtitle: 'App, room and discovery language.', icon: Icons.language_rounded));
      case VmRoutes.games:
        return _buildRoute(settings, const VmSkeletonPage(title: 'Games', subtitle: 'Free and coin games for rooms.', icon: Icons.sports_esports_rounded));
      case VmRoutes.watchParty:
        return _buildRoute(settings, const VmSkeletonPage(title: 'Watch Party', subtitle: 'Synced YouTube watch mode.', icon: Icons.ondemand_video_rounded));
      case VmRoutes.cricketMode:
        return _buildRoute(settings, const VmSkeletonPage(title: 'Cricket Mode', subtitle: 'Live cricket scoring room mode.', icon: Icons.sports_cricket_rounded));
      case VmRoutes.vibeSync:
        return _buildRoute(settings, const VmSkeletonPage(title: 'VibeSync', subtitle: 'Pulse Match and Mic Chemistry.', icon: Icons.favorite_border_rounded));
      case VmRoutes.vibeDetail:
        return _buildRoute(settings, const VmSkeletonPage(title: 'Vibe Detail', subtitle: 'Post, comments and reactions.', icon: Icons.auto_awesome_rounded));
      case VmRoutes.vibeComposer:
        return _buildRoute(settings, const VmSkeletonPage(title: 'Create Vibe', subtitle: 'Post photos, videos and captions.', icon: Icons.add_photo_alternate_rounded));
      case VmRoutes.vibeComments:
        return _buildRoute(settings, const VmSkeletonPage(title: 'Comments', subtitle: 'Replies, reactions and mentions.', icon: Icons.mode_comment_rounded));
      default:
        return _buildRoute(settings, UnknownRoutePage(routeName: settings.name ?? 'unknown'));
    }
  }

  static PageRouteBuilder<dynamic> _buildRoute(RouteSettings settings, Widget page) {
    return PageRouteBuilder<dynamic>(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 210),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0.045, 0.012), end: Offset.zero).animate(curved),
            child: ScaleTransition(scale: Tween<double>(begin: 0.988, end: 1).animate(curved), child: child),
          ),
        );
      },
    );
  }
}

class UnknownRoutePage extends StatelessWidget {
  const UnknownRoutePage({super.key, required this.routeName});
  final String routeName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      appBar: AppBar(title: const Text('Not found'), backgroundColor: const Color(0xFFFAF7F1), foregroundColor: const Color(0xFF251538), elevation: 0),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('This page is not available yet.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: const Color(0xFF251538))),
        ),
      ),
    );
  }
}
