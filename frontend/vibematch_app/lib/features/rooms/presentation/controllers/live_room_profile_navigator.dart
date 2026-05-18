import 'package:flutter/material.dart';

import '../../../auth/models/current_user.dart';
import '../../../auth/models/role_badge.dart';
import '../../../profile/presentation/public_profile_view_page.dart';
import '../../../social/data/social_api_service.dart';
import '../../../vip/presentation/vip_program_page.dart';
import '../live_room_models.dart';
import '../widgets/experience/experience_level_models.dart';
import '../widgets/experience/experience_level_page.dart';
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
    final publicUserId = publicUserIdFromRoomUserId(user.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicProfileViewPage(
          user: seatUserToCurrentUser(user),
          publicUserId: publicUserId,
          vipLevel: user.vipLevel,
          svipLevel: user.svipLevel,
          presenceLabel: 'online',
          currentRoomName: privacyMode == RoomPrivacyMode.privateVibe
              ? null
              : roomName,
          relationshipLabel: user.relationshipText,
          familyName: user.familyName,
          familyLevel: 0,
        ),
      ),
    );
  }

  static CurrentUser seatUserToCurrentUser(SeatUser user) {
    final publicUserId = publicUserIdFromRoomUserId(user.id) ?? 0;
    final isFounder = publicUserId == 6922022 || user.id == 'founder_owner';
    final isAdmin = user.isRoomAdmin || user.isHost;

    final role = isFounder
        ? 'founder_owner'
        : user.isHost
        ? 'owner'
        : isAdmin
        ? 'admin'
        : 'user';
    final roleBadge = RoleBadge.fromRole(role);

    return CurrentUser(
      id: publicUserId > 0
          ? publicUserId
          : user.id.hashCode.abs() % 900000 + 100000,
      publicUserId: publicUserId > 0 ? publicUserId : 0,
      displayCustomId: isFounder ? 6922022 : null,
      username: user.name.toLowerCase().replaceAll(' ', '_'),
      displayName: user.name,
      avatarUrl: user.avatarUrl,
      bio: null,
      coverPhotoUrls: const [],
      dateOfBirth: null,
      gender: null,
      profession: null,
      maritalStatus: null,
      friendGenderPreference: null,
      friendMaritalPreference: null,
      interests: const [],
      roles: [role],
      primaryRole: role,
      primaryRoleBadge: roleBadge,
      roleBadges: [roleBadge],
      isActive: true,
      isBanned: false,
      lastDeviceId: null,
      lastLoginAt: DateTime.now(),
      lastSeenAt: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static void openFollowersPage({
    required BuildContext context,
    required SeatUser user,
    required List<SeatUser> users,
  }) {
    _pushRoomActionPageFromSheet(
      context,
      FollowersFollowedPage(user: user, users: users, initialTabIndex: 0),
    );
  }

  static void openFollowedPage({
    required BuildContext context,
    required SeatUser user,
    required List<SeatUser> users,
  }) {
    _pushRoomActionPageFromSheet(
      context,
      FollowersFollowedPage(user: user, users: users, initialTabIndex: 1),
    );
  }

  static void openVipCentrePage({
    required BuildContext context,
    required SeatUser user,
  }) {
    _openVipProgram(context: context, user: user, initialTabIndex: 0);
  }

  static void openSvipCentrePage({
    required BuildContext context,
    required SeatUser user,
  }) {
    _openVipProgram(context: context, user: user, initialTabIndex: 1);
  }

  static void _openVipProgram({
    required BuildContext context,
    required SeatUser user,
    required int initialTabIndex,
  }) {
    Navigator.pop(context);
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VipProgramPage(
            initialTabIndex: initialTabIndex,
            vipLevel: user.vipLevel,
            svipLevel: user.svipLevel,
          ),
        ),
      );
    });
  }

  static void openSendingExperiencePage({
    required BuildContext context,
    required SeatUser user,
  }) {
    _pushRoomActionPageFromSheet(
      context,
      ExperienceLevelPage(user: user, type: ExperienceLevelType.sent),
    );
  }

  static void openReceivingExperiencePage({
    required BuildContext context,
    required SeatUser user,
  }) {
    _pushRoomActionPageFromSheet(
      context,
      ExperienceLevelPage(user: user, type: ExperienceLevelType.received),
    );
  }

  static void openSentRankingsPage({
    required BuildContext context,
    required List<SeatUser> users,
  }) {
    _pushRoomActionPageFromSheet(
      context,
      RoomRankingsPage(title: 'Sent Rankings', users: users, sentRanking: true),
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
          const RoomActionCard(
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
          const RoomActionCard(
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
            value: user.medals.isEmpty
                ? 'No medals yet'
                : user.medals.join('  '),
            icon: Icons.military_tech_rounded,
            color: RoomColors.gold,
          ),
          const RoomActionCard(
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
      RoomActionPage(title: title, subtitle: subtitle, icon: icon),
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
