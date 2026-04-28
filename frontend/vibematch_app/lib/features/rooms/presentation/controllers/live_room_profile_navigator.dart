import 'package:flutter/material.dart';

import '../../../auth/models/current_user.dart';
import '../../../profile/presentation/public_profile_view_page.dart';
import '../live_room_models.dart';
import '../widgets/followers_followed_page.dart';
import '../widgets/room_action_pages.dart';
import '../widgets/room_theme.dart';

class LiveRoomProfileNavigator {
  const LiveRoomProfileNavigator._();

  static void openExistingPublicProfile({
    required BuildContext context,
    required SeatUser user,
    required RoomPrivacyMode privacyMode,
    required String roomName,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicProfileViewPage(
          user: seatUserToCurrentUser(user),
          vipLevel: user.vipLevel,
          svipLevel: user.svipLevel,
          presenceLabel: 'online',
          currentRoomName: privacyMode == RoomPrivacyMode.privateVibe
              ? null
              : roomName,
          relationshipLabel: user.relationshipText,
          familyName: user.familyName,
          familyLevel: 12,
        ),
      ),
    );
  }

  static CurrentUser seatUserToCurrentUser(SeatUser user) {
    final isFounder = user.id == 'founder_owner';
    final isAdmin = user.isRoomAdmin || user.isHost;

    final role = isFounder
        ? 'founder_owner'
        : user.isHost
            ? 'owner'
            : isAdmin
                ? 'admin'
                : 'user';

    return CurrentUser(
      id: _mockInternalUserId(user),
      publicUserId: _mockPublicUserId(user),
      displayCustomId: isFounder ? 6922022 : null,
      username: user.name.toLowerCase().replaceAll(' ', '_'),
      displayName: user.name,
      avatarUrl: null,
      roles: [role],
      primaryRole: role,
      isActive: true,
      isBanned: false,
      lastDeviceId: null,
      lastLoginAt: DateTime.now(),
      lastSeenAt: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static int _mockInternalUserId(SeatUser user) {
    switch (user.id) {
      case 'founder_owner':
        return 1;
      case 'riya':
        return 2;
      case 'arjun':
        return 3;
      default:
        return user.id.hashCode.abs() % 900000 + 100000;
    }
  }

  static int _mockPublicUserId(SeatUser user) {
    switch (user.id) {
      case 'founder_owner':
        return 6922022;
      case 'riya':
        return 6418001245;
      case 'arjun':
        return 6418002480;
      default:
        return 6418000000 + (user.id.hashCode.abs() % 999999);
    }
  }

  static void openFollowersPage({
    required BuildContext context,
    required SeatUser user,
    required List<SeatUser> users,
  }) {
    _pushRoomActionPageFromSheet(
      context,
      FollowersFollowedPage(
        user: user,
        users: users,
        initialTabIndex: 0,
      ),
    );
  }

  static void openFollowedPage({
    required BuildContext context,
    required SeatUser user,
    required List<SeatUser> users,
  }) {
    _pushRoomActionPageFromSheet(
      context,
      FollowersFollowedPage(
        user: user,
        users: users,
        initialTabIndex: 1,
      ),
    );
  }

  static void openVipCentrePage({
    required BuildContext context,
    required SeatUser user,
  }) {
    _pushRoomActionPageFromSheet(
      context,
      RoomActionPage(
        title: 'VIP Centre',
        subtitle:
            '${user.name} is VIP ${user.vipLevel}. VIP benefits, SVIP rules, badges, and recharge progress will connect here.',
        icon: Icons.workspace_premium_rounded,
        cards: [
          RoomActionCard(
            title: 'Current VIP',
            value: 'VIP ${user.vipLevel}',
            icon: Icons.workspace_premium_rounded,
            color: RoomColors.gold,
          ),
          RoomActionCard(
            title: 'Monthly SVIP',
            value: user.svipLevel > 0 ? 'SVIP ${user.svipLevel}' : 'Not active',
            icon: Icons.auto_awesome_rounded,
            color: RoomColors.violet,
          ),
        ],
      ),
    );
  }

  static void openSendingExperiencePage({
    required BuildContext context,
    required SeatUser user,
  }) {
    _pushRoomActionPageFromSheet(
      context,
      RoomActionPage(
        title: 'Sending Experience',
        subtitle:
            '${user.name}\'s total sending level progress and monthly coin-send history.',
        icon: Icons.north_east_rounded,
        cards: [
          RoomActionCard(
            title: 'Send level',
            value: 'Lv ${user.sendingLevel}',
            icon: Icons.north_east_rounded,
            color: RoomColors.violet,
          ),
          RoomActionCard(
            title: 'This month sent',
            value: compactNumber(user.sentExp),
            icon: Icons.toll_rounded,
            color: RoomColors.gold,
          ),
        ],
      ),
    );
  }

  static void openReceivingExperiencePage({
    required BuildContext context,
    required SeatUser user,
  }) {
    _pushRoomActionPageFromSheet(
      context,
      RoomActionPage(
        title: 'Receiving Experience',
        subtitle:
            '${user.name}\'s receiving level progress and monthly received coin history.',
        icon: Icons.favorite_rounded,
        cards: [
          RoomActionCard(
            title: 'Receive level',
            value: 'Lv ${user.receivingLevel}',
            icon: Icons.favorite_rounded,
            color: RoomColors.coral,
          ),
          RoomActionCard(
            title: 'This month received',
            value: compactNumber(user.receivedExp),
            icon: Icons.toll_rounded,
            color: RoomColors.gold,
          ),
        ],
      ),
    );
  }

  static void openSentRankingsPage({
    required BuildContext context,
    required List<SeatUser> users,
  }) {
    _pushRoomActionPageFromSheet(
      context,
      RoomRankingsPage(
        title: 'Sent Rankings',
        users: users,
        sentRanking: true,
      ),
    );
  }

  static void openReceivedRankingsPage({
    required BuildContext context,
    required List<SeatUser> users,
  }) {
    _pushRoomActionPageFromSheet(
      context,
      RoomRankingsPage(
        title: 'Received Rankings',
        users: users,
        sentRanking: false,
      ),
    );
  }

  static void openFamilyPage({
    required BuildContext context,
    required SeatUser user,
  }) {
    final hasFamily = user.familyName.trim().isNotEmpty;

    _pushRoomActionPageFromSheet(
      context,
      RoomActionPage(
        title: hasFamily ? user.familyName : 'Join Family',
        subtitle: hasFamily
            ? '${user.name}\'s family profile, contribution, family rooms, events, and rankings.'
            : '${user.name} is not in a family yet. Family discovery and create/join flow will connect here.',
        icon: Icons.groups_rounded,
        cards: [
          RoomActionCard(
            title: hasFamily ? 'Family name' : 'Status',
            value: hasFamily ? user.familyName : 'No family joined',
            icon: Icons.groups_rounded,
            color: RoomColors.aqua,
          ),
          RoomActionCard(
            title: 'Family events',
            value: 'Family-vs-family activities and rewards connect here',
            icon: Icons.emoji_events_rounded,
            color: RoomColors.gold,
          ),
        ],
      ),
    );
  }

  static void openLoveAndBondCentre({
    required BuildContext context,
    required SeatUser user,
  }) {
    _pushRoomActionPageFromSheet(
      context,
      RoomActionPage(
        title: 'Love & Bond Centre',
        subtitle: user.relationshipText.trim().isEmpty
            ? '${user.name} has no active love or bond relationship yet.'
            : user.relationshipText,
        icon: Icons.favorite_rounded,
        cards: [
          RoomActionCard(
            title: 'Relationship',
            value: user.relationshipText.trim().isEmpty
                ? 'No love or bonds yet'
                : user.relationshipText,
            icon: Icons.favorite_rounded,
            color: RoomColors.coral,
          ),
          RoomActionCard(
            title: 'Cards',
            value: 'Relationship cards and bond actions connect here',
            icon: Icons.style_rounded,
            color: RoomColors.violet,
          ),
        ],
      ),
    );
  }

  static void openMedalsPage({
    required BuildContext context,
    required SeatUser user,
  }) {
    _pushRoomActionPageFromSheet(
      context,
      RoomActionPage(
        title: 'Medals',
        subtitle:
            '${user.name}\'s earned medals and upcoming achievement badges.',
        icon: Icons.military_tech_rounded,
        cards: [
          RoomActionCard(
            title: 'Current medals',
            value:
                user.medals.isEmpty ? 'No medals yet' : user.medals.join('  '),
            icon: Icons.military_tech_rounded,
            color: RoomColors.gold,
          ),
          RoomActionCard(
            title: 'Achievement centre',
            value: 'Medal progress and rules connect here',
            icon: Icons.auto_graph_rounded,
            color: RoomColors.aqua,
          ),
        ],
      ),
    );
  }

  static void openModulePage({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    _pushRoomActionPageFromSheet(
      context,
      RoomActionPage(
        title: title,
        subtitle: subtitle,
        icon: icon,
      ),
    );
  }

  static void _pushRoomActionPageFromSheet(BuildContext context, Widget page) {
    Navigator.pop(context);

    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (!context.mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    });
  }
}