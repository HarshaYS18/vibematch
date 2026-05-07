import 'package:flutter/material.dart';

import '../../../auth/models/current_user.dart';
import '../../../family/models/family_ui_models.dart';
import '../../../family/presentation/family_modular_page.dart';
import '../../../rooms/presentation/live_room_models.dart';
import '../../../rooms/presentation/live_room_page.dart';
import '../../../rooms/presentation/widgets/followers_followed_page.dart';
import '../../../vip/presentation/vip_program_page.dart';
import '../edit_profile_page.dart';
import '../love_bonds/love_bond_detail_page.dart';
import '../love_bonds/models/love_bond_models.dart';
import '../models/me_page_models.dart';
import '../profile_visitors_page.dart';
import '../public_profile_view_page.dart';
import 'me_account_widgets.dart';
import 'me_family_details_sheet.dart';
import 'me_profile_constants.dart';
import 'me_profile_hero.dart';
import 'me_session_sheet.dart';
import 'me_stats_row.dart';

class MePageContent extends StatelessWidget {
  const MePageContent({
    super.key,
    required this.user,
    required this.onLogoutPressed,
    required this.onRefreshPressed,
  });

  final CurrentUser user;
  final Future<void> Function() onLogoutPressed;
  final Future<void> Function() onRefreshPressed;

  static const String _familyId = 'VMF6922';
  static const String _familyRank = 'No. 99+';
  static const String _familyRole = 'Member';
  static const int _familyMembers = 128;
  static const int _familyTotalExp = 1085000;

  FamilyProfileUiModel get _currentFamilyProfile {
    return const FamilyProfileUiModel(
      id: _familyId,
      name: MeProfileConstants.familyName,
      minimumVipLabel: 'VIP 5',
      memberCount: _familyMembers,
      maxMembers: 200,
      rankLabel: _familyRank,
      ownerUserId: 'family_owner_01',
      quarterCarryExp: _familyTotalExp,
      giftCoinsThisQuarter: _familyTotalExp,
      timeMinutesToday: 12240,
    );
  }

  SeatUser get _viewerSeatUser {
    return mockRoomUsers.firstWhere(
      (item) => item.isCurrentUser,
      orElse: () => mockRoomUsers.first,
    );
  }

  List<SeatUser> get _socialPreviewUsers => const [...mockRoomUsers, ...mockInviteUsers];

  void _showAction(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF251538),
        ),
      );
  }

  Future<void> _endSession(BuildContext context) async {
    final shouldEnd = await showMeSessionSheet(context);
    if (shouldEnd == true) await onLogoutPressed();
  }

  void _openEditProfile(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditProfilePage(user: user)));
  }

  void _openFamily(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FamilyModularPage()));
  }

  void _openCurrentFamily(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FamilyModularPage(
          openCurrentFamily: true,
          initialFamilyProfile: _currentFamilyProfile,
        ),
      ),
    );
  }

  void _openFamilyDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MeFamilyDetailsSheet(
        familyName: MeProfileConstants.familyName,
        familyLevel: MeProfileConstants.familyLevel,
        familyId: _familyId,
        rankLabel: _familyRank,
        memberRole: _familyRole,
        memberCount: _familyMembers,
        totalExp: _familyTotalExp,
        onOpenFamily: () => _openCurrentFamily(context),
      ),
    );
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PublicProfileViewPage(
          user: user,
          vipLevel: MeProfileConstants.vipLevel,
          svipLevel: MeProfileConstants.svipLevel,
          presenceLabel: MeProfileConstants.lastSeenText,
          currentRoomName: MeProfileConstants.currentRoomName,
          relationshipLabel: MeProfileConstants.relationshipTypeFor(user),
          familyName: MeProfileConstants.familyName,
          familyLevel: MeProfileConstants.familyLevel,
        ),
      ),
    );
  }

  void _openVipProgram(BuildContext context, {int initialTabIndex = 0}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VipProgramPage(
          initialTabIndex: initialTabIndex,
          vipLevel: MeProfileConstants.vipLevel,
          svipLevel: MeProfileConstants.svipLevel,
          lifetimeRechargeCoins: MeProfileConstants.diamonds,
          monthlyRechargeCoins: 42000,
        ),
      ),
    );
  }

  void _openBondDetail(BuildContext context, LoveBondCardData bond) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => LoveBondDetailPage(bond: bond)));
  }

  void _openFollowersFollowed(BuildContext context, {required int initialTabIndex}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FollowersFollowedPage(
          user: _viewerSeatUser,
          users: _socialPreviewUsers,
          initialTabIndex: initialTabIndex,
        ),
      ),
    );
  }

  void _openVisitors(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileVisitorsPage(profileOwnerUserId: user.id),
      ),
    );
  }

  void _openCurrentRoom(BuildContext context) {
    final roomName = MeProfileConstants.currentRoomName;
    if (roomName == null || roomName.trim().isEmpty) {
      _showAction(context, 'No active room right now.');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveRoomPage(
          roomName: roomName,
          roomId: 'VM257808',
          language: 'Telugu',
          modeTitle: 'Open',
          onlineCount: 128,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vipColor = MeProfileConstants.vipMainColor(MeProfileConstants.vipLevel);
    final vipDark = MeProfileConstants.vipDarkColor(MeProfileConstants.vipLevel);
    final relationshipType = MeProfileConstants.relationshipTypeFor(user);
    final items = buildMeActionItems(
      vipLevel: MeProfileConstants.vipLevel,
      svipLevel: MeProfileConstants.svipLevel,
      coverPhotoStatus: MeProfileConstants.coverPhotoStatus,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 116),
      children: [
        MePremiumProfileHero(
          displayName: MeProfileConstants.displayNameFor(user),
          publicId: user.publicUserId.toString(),
          role: user.primaryRole,
          roleTag: MeProfileConstants.roleTagFor(user.primaryRole),
          vipLevel: MeProfileConstants.vipLevel,
          svipLevel: MeProfileConstants.svipLevel,
          vipFrozen: MeProfileConstants.vipFrozen,
          vipColor: vipColor,
          vipDark: vipDark,
          diamonds: MeProfileConstants.formatNumber(MeProfileConstants.diamonds),
          coins: MeProfileConstants.formatNumber(MeProfileConstants.coins),
          presence: MeProfileConstants.presence,
          lastSeenText: MeProfileConstants.lastSeenText,
          currentRoomName: MeProfileConstants.currentRoomName,
          familyName: MeProfileConstants.familyName,
          familyLevel: MeProfileConstants.familyLevel,
          onFamilyTap: () => _openFamilyDetails(context),
          onAvatarTap: () => _openProfile(context),
          onQrTap: () => _showAction(context, 'Profile QR / share card will open.'),
          onWalletTap: () => _showAction(context, 'Wallet page will open.'),
          onVipTap: () => _openVipProgram(context),
          onSvipTap: () => _openVipProgram(context, initialTabIndex: 1),
          onRoomTap: () => _openCurrentRoom(context),
        ),
        const SizedBox(height: 14),
        MeStatsRow(
          onFollowingTap: () => _openFollowersFollowed(context, initialTabIndex: 1),
          onFollowersTap: () => _openFollowersFollowed(context, initialTabIndex: 0),
          onRoomsTap: () => _openCurrentRoom(context),
          onVisitorsTap: () => _openVisitors(context),
        ),
        const SizedBox(height: 14),
        MeRelationshipPanel(
          relationshipLabel: relationshipType,
          onBondTap: (bond) => _openBondDetail(context, bond),
        ),
        const SizedBox(height: 18),
        const Text('Account', style: TextStyle(color: Color(0xFF251538), fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
        const SizedBox(height: 12),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: MeAccountCard(
              item: item,
              onTap: () async {
                if (item.action == 'edit_profile') {
                  _openEditProfile(context);
                } else if (item.action == 'family' || item.title == 'Family') {
                  _openFamily(context);
                } else if (item.title == 'VIP / SVIP Center' || item.title == 'VIP / SVIP') {
                  _openVipProgram(context, initialTabIndex: item.subtitle.contains('SVIP') ? 1 : 0);
                } else if (item.action == 'logout') {
                  await _endSession(context);
                } else if (item.action == 'refresh') {
                  await onRefreshPressed();
                  if (context.mounted) _showAction(context, 'Profile refreshed.');
                } else {
                  _showAction(context, item.action);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}
