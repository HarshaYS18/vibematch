import 'package:flutter/material.dart';

import '../core/presentation/vm_skeleton_page.dart';
import '../features/auth/presentation/auth_gate.dart';
import '../features/banner_manager/presentation/banner_manager_page.dart';
import '../features/control_center/presentation/control_center_page.dart';
import '../features/events/presentation/events_page.dart';
import '../features/family/presentation/family_page.dart';
import '../features/love_bond/presentation/love_bond_page.dart';
import '../features/notifications/presentation/notifications_page.dart';
import '../features/profile/presentation/public_profile_page.dart';
import '../features/rankings/presentation/rankings_page.dart';
import '../features/rooms/presentation/live_room_page.dart';
import '../features/rooms/presentation/room_preview_page.dart';
import '../features/rooms/presentation/routes/live_room_route_args.dart';
import '../features/rooms/presentation/routes/live_room_routes.dart';
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
          return LiveRoomRoutes.liveRoom(
            LiveRoomRouteViewArgs(
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
      case VmRoutes.bannerManager:
        return _buildRoute(settings, const BannerManagerPage());

      case VmRoutes.agency:
        return _buildRoute(settings, const VmSkeletonPage(title: 'Agency', subtitle: 'Agency Owner, Agency Admin, Hosts, BD hierarchy, commission, leave requests, and agency performance.', icon: Icons.groups_2_rounded, highlights: ['Agency Owner can invite, approve, remove hosts, and appoint up to 2 admins.', 'Agency Admin can invite and approve hosts but cannot remove hosts or manage admins.', 'Future backend: agency membership, host rewards, commissions, and audit logs.']));
      case VmRoutes.gifts:
        return _buildRoute(settings, const VmSkeletonPage(title: 'Gifts', subtitle: 'Gift catalog, normal gifts, lucky gifts, relationship gifts, premium animations, combo history, and received gifts.', icon: Icons.card_giftcard_rounded, highlights: ['Gift catalog must come from backend before production testing.', 'Gift sending must be wallet-ledger and WebSocket controlled.', 'Future backend: gift catalog, send gift, combo, received gift, and lucky gift APIs.']));
      case VmRoutes.inventory:
        return _buildRoute(settings, const VmSkeletonPage(title: 'Inventory', subtitle: 'Owned avatar frames, entrance effects, chat bubbles, room backgrounds, badges, and equipped cosmetics.', icon: Icons.inventory_2_rounded, highlights: ['Inventory should separate owned, expired, equipped, and pending-review items.', 'Custom room backgrounds require official approval before activation.', 'Future backend: inventory, equip, unequip, expiry, and review status APIs.']));
      case VmRoutes.recharge:
        return _buildRoute(settings, const VmSkeletonPage(title: 'Recharge', subtitle: 'Coin purchase, recharge packages, monthly SVIP progress, and test recharge flow.', icon: Icons.bolt_rounded, highlights: ['Recharge increases wallet balance through backend ledger transactions.', 'VIP/SVIP status should update from recharge rules.', 'Future backend: packages, payment intent, receipt verification, and recharge history APIs.']));
      case VmRoutes.transactions:
        return _buildRoute(settings, const VmSkeletonPage(title: 'Transactions', subtitle: 'Wallet ledger for recharge, gifts, store purchases, games, admin adjustments, and refunds.', icon: Icons.receipt_long_rounded, highlights: ['Every coin movement must be traceable.', 'Gift/game/store spending should never be client-authoritative.', 'Future backend: paginated wallet transaction APIs.']));
      case VmRoutes.earnings:
        return _buildRoute(settings, const VmSkeletonPage(title: 'Earnings', subtitle: 'Creator earnings, beans/rewards, host targets, gift revenue share, and fraud-review status.', icon: Icons.savings_rounded, highlights: ['Receivers earn from gifts based on backend economy rules.', 'Agency/host target rewards should remain audit logged.', 'Future backend: earnings summary, target progress, and fraud review APIs.']));
      case VmRoutes.payouts:
        return _buildRoute(settings, const VmSkeletonPage(title: 'Payouts', subtitle: 'Payout requests, payout eligibility, fraud review, approval history, and settlement status.', icon: Icons.payments_rounded, highlights: ['Payouts must stay below incoming revenue and pass fraud checks.', 'Admin approval/rejection must be audit logged.', 'Future backend: payout request, review, approval, and settlement APIs.']));

      case VmRoutes.admin:
        return _buildRoute(settings, const VmSkeletonPage(title: 'Admin', subtitle: 'Admin routes for users, roles, bans, device bans, audit logs, login history, reports, and reviews.', icon: Icons.shield_rounded, highlights: ['Admin tools must be backend role/permission enforced.', 'Every sensitive action must be audit logged.', 'Future: split into users, roles, audit logs, bans, device bans, reports, and review pages.']));
      case VmRoutes.reports:
        return _buildRoute(settings, const VmSkeletonPage(title: 'Reports', subtitle: 'User, room, message, profile, gift, and safety reports review queue.', icon: Icons.report_rounded, highlights: ['Reports should route to CS/Monitor/Admin queues based on severity.', 'Actions must respect protected role hierarchy.', 'Future backend: report queue, status, reviewer notes, and moderation action APIs.']));
      case VmRoutes.privacy:
        return _buildRoute(settings, const VmSkeletonPage(title: 'Privacy', subtitle: 'Profile privacy, stranger messages, room presence, Secret Vibe visibility, and blocked access rules.', icon: Icons.privacy_tip_rounded, highlights: ['Secret Vibe room presence must never leak to unauthorized users.', 'Stranger messages and online/last-seen settings live here.', 'Future backend: privacy preferences and enforcement APIs.']));
      case VmRoutes.blockList:
        return _buildRoute(settings, const VmSkeletonPage(title: 'Block List', subtitle: 'Blocked users, unblock actions, chat restrictions, and safety preferences.', icon: Icons.block_rounded, highlights: ['Blocked users should not message or interact where restricted.', 'Block/unblock must sync across Inbox and profile modules.', 'Future backend: block relationships and privacy enforcement APIs.']));
      case VmRoutes.security:
        return _buildRoute(settings, const VmSkeletonPage(title: 'Security', subtitle: 'Login devices, device ID, sessions, bans, account safety, and security history.', icon: Icons.security_rounded, highlights: ['Device bans are enforced at login.', 'Login history should be visible to authorized users/admins.', 'Future backend: sessions, device trust, and account security APIs.']));
      case VmRoutes.language:
        return _buildRoute(settings, const VmSkeletonPage(title: 'Language', subtitle: 'App language, room language preferences, content language filters, and regional discovery.', icon: Icons.language_rounded, highlights: ['Home already supports room language filtering.', 'This page will hold user-level language preferences.', 'Future backend: language preferences and region-aware discovery APIs.']));

      case VmRoutes.games:
        return _buildRoute(settings, const VmSkeletonPage(title: 'Games', subtitle: 'Free-to-play games and coin games for live rooms, including Ludo, Carrom, Chess, Bingo, Sheep Fight, and Crystal Hunt.', icon: Icons.sports_esports_rounded, highlights: ['Games should lazy-load only when opened.', 'Coin games must be backend-authoritative with RTP/liability controls.', 'Future backend: game sessions, bets, results, anti-whale, and audit APIs.']));
      case VmRoutes.watchParty:
        return _buildRoute(settings, const VmSkeletonPage(title: 'Watch Party', subtitle: 'YouTube-first synced watch mode with 10-seat layout, video area, host controls, and viewer sync.', icon: Icons.ondemand_video_rounded, highlights: ['Watch Party should be a room mode, not a separate room.', 'Host controls play, pause, seek, and load video through WebSocket.', 'Future backend: watch session state and server-time sync APIs.']));
      case VmRoutes.cricketMode:
        return _buildRoute(settings, const VmSkeletonPage(title: 'Cricket Mode', subtitle: 'Room mode for cricket scoring, teams, innings, overs, balls, score events, and permissions.', icon: Icons.sports_cricket_rounded, highlights: ['Cricket Mode reuses the same room seats and members.', 'Owner/admins control rules and score updates.', 'Future backend: cricket mode state, rules, score, and WebSocket sync APIs.']));
      case VmRoutes.vibeSync:
        return _buildRoute(settings, const VmSkeletonPage(title: 'VibeSync', subtitle: 'Pulse Match and Mic Chemistry room interaction engine with realtime matching and chemistry overlays.', icon: Icons.favorite_border_rounded, highlights: ['Pulse Match records server timestamps and sync windows.', 'Mic Chemistry calculates engagement and chemistry scores.', 'Future backend: VibeSync sessions, pulse events, matches, and chemistry APIs.']));

      case VmRoutes.vibeDetail:
        return _buildRoute(settings, const VmSkeletonPage(title: 'Vibe Detail', subtitle: 'Detailed view for a single vibe post with media, caption, mentions, likes, comments, and reactions.', icon: Icons.auto_awesome_rounded, highlights: ['Reusable post detail route for feed and profile.', 'Comments and reactions should notify Inbox/Reactions.', 'Future backend: vibe detail, comments, likes, and reaction APIs.']));
      case VmRoutes.vibeComposer:
        return _buildRoute(settings, const VmSkeletonPage(title: 'Create Vibe', subtitle: 'Create text, photo, or video vibes with captions, mentions, @all fans, and upload limits.', icon: Icons.add_photo_alternate_rounded, highlights: ['Media upload limits: avatars/dynamic avatars under 10MB; vibe media under 20MB.', 'Mention rules should use fixed user ID/public ID logic.', 'Future backend: upload, create vibe, mention notification, and moderation APIs.']));
      case VmRoutes.vibeComments:
        return _buildRoute(settings, const VmSkeletonPage(title: 'Vibe Comments', subtitle: 'Comments, replies, reactions, mentions, and moderation actions for vibe posts.', icon: Icons.mode_comment_rounded, highlights: ['Comments should support mentions and report actions.', 'Reactions should appear in Inbox reactions.', 'Future backend: comment thread, reactions, report, and notification APIs.']));

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
