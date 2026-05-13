import 'package:flutter/material.dart';

import '../../../auth/models/current_user.dart';
import '../../../control_center/presentation/control_center_page.dart';
import '../../../economy/presentation/merchant_seller_panel_page.dart';
import '../../../family/models/family_ui_models.dart';
import '../../../family/presentation/family_modular_page.dart';
import '../../../games/presentation/game_test_page.dart';
import '../../../rooms/presentation/live_room_models.dart';
import '../../../rooms/presentation/live_room_page.dart';
import '../../../rooms/presentation/widgets/followers_followed_page.dart';
import '../../../vip/presentation/vip_program_page.dart';
import '../../../wallet/presentation/wallet_page.dart';
import '../../data/love_bond_realtime_service.dart';
import '../../data/profile_api_service.dart';
import '../control_center/coin_supply_grant_page.dart';
import '../control_center/vibes_reports_review_page.dart';
import '../control_center/vip_svip_admin_page.dart';
import '../cover_photos/edit_cover_photos_page.dart';
import '../edit_profile_page.dart';
import '../help_center/help_center_page.dart';
import '../love_bonds/love_bond_detail_page.dart';
import '../love_bonds/love_bonds_page.dart';
import '../love_bonds/models/love_bond_models.dart';
import '../models/me_page_models.dart';
import '../profile_qr/profile_qr_pages.dart';
import '../profile_rooms_page.dart';
import '../profile_visitors_page.dart';
import '../public_profile_view_page.dart';
import '../settings/account_settings_page.dart';
import '../store/store_page.dart';
import 'me_account_widgets.dart';
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
SeatUser get _viewerSeatUser {
    return mockRoomUsers.firstWhere(
      (item) => item.isCurrentUser,
      orElse: () => mockRoomUsers.isNotEmpty ? mockRoomUsers.first : _fallbackSeatUser,
    );
  }

  SeatUser get _fallbackSeatUser {
    return SeatUser(
      id: 'user_${user.publicUserId}',
      name: MeProfileConstants.displayNameFor(user),
      roleLabel: user.roleDisplayLabel,
      familyName: MeProfileConstants.familyName,
      familyLevel: 'bronze',
      relationshipText: MeProfileConstants.relationshipTypeFor(user),
      vipLevel: user.vip.vipLevel,
      svipLevel: user.vip.svipLevel,
      sendingLevel: 1,
      receivingLevel: 1,
      sentExp: 0,
      receivedExp: 0,
      medals: const [],
      avatarColors: const [Color(0xFF12C7B7), Color(0xFF6D5DF6)],
      isCurrentUser: true,
      isHost: user.canSeeOwnerControls,
      isRoomAdmin: user.canSeeOwnerControls,
    );
  }

  List<SeatUser> get _socialPreviewUsers {
    final users = <SeatUser>[...mockRoomUsers, ...mockInviteUsers];
    return users.isEmpty ? <SeatUser>[_fallbackSeatUser] : users;
  }

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

  void _openProfileQrActions(BuildContext context) {
    ProfileQrActionsSheet.show(context, user: user);
  }

  Future<void> _openEditCoverPhotos(BuildContext context) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => EditCoverPhotosPage(initialCoverPhotoUrls: user.coverPhotoUrls)));
    if (changed == true) await onRefreshPressed();
  }

  void _openAccountSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AccountSettingsPage(svipLevel: user.vip.svipLevel),
      ),
    );
  }

  void _openHelpCentre(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpCenterPage()));
  }

  void _openStore(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VmStorePage()));
  }

  void _openLoveBonds(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoveBondsPage()));
  }

  void _openWallet(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WalletPage()));
  }

  void _openControlCentre(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ControlCenterPage(),
      ),
    );
  }

  void _openVibesReportsReview(BuildContext context) {
    if (!user.canSeeOwnerControls) {
      _showAction(context, 'Only Owner/Super Owner control users can open Vibes reports review.');
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VibesReportsReviewPage()));
  }

  void _openVipSvipAdmin(BuildContext context) {
    if (!user.canSeeOwnerControls) {
      _showAction(context, 'Only Owner/Super Owner can adjust VIP/SVIP levels.');
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VipSvipAdminPage()));
  }

  void _openCoinSupplyGrant(BuildContext context) {
    if (!user.canSeeOwnerControls) {
      _showAction(context, 'Only Owner/Super Owner can grant coin supply.');
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CoinSupplyGrantPage()));
  }

  void _openGameTest(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GameTestPage()));
  }

  void _openMerchantSellerPanel(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MerchantSellerPanelPage()));
  }

  void _openFamily(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FamilyModularPage()));
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PublicProfileViewPage(
          user: user,
          vipLevel: user.vip.vipLevel,
          svipLevel: user.vip.svipLevel,
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
          vipLevel: user.vip.vipLevel,
          svipLevel: user.vip.svipLevel,
          lifetimeRechargeCoins: user.wallet.lifetimeCoinsSpent,
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

  void _openRooms(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfileRoomsPage(userId: user.id, publicUserId: user.publicUserId)),
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
    final vipColor = MeProfileConstants.vipMainColor(user.vip.vipLevel);
    final vipDark = MeProfileConstants.vipDarkColor(user.vip.vipLevel);
    final relationshipType = MeProfileConstants.relationshipTypeFor(user);
    final items = buildMeActionItems(
      vipLevel: user.vip.vipLevel,
      svipLevel: user.vip.svipLevel,
      coverPhotoStatus: MeProfileConstants.coverPhotoStatus,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 116),
      children: [
        _MeLoveBondBackendSyncGate(user: user),
        _MeRealFamilyHero(
          user: user,
          vipColor: vipColor,
          vipDark: vipDark,
          onAvatarTap: () => _openProfile(context),
          onQrTap: () => _openProfileQrActions(context),
          onEditCoverPhotosTap: () => _openEditCoverPhotos(context),
          onWalletTap: () => _openWallet(context),
          onVipTap: () => _openVipProgram(context),
          onSvipTap: () => _openVipProgram(context, initialTabIndex: 1),
          onRoomTap: () => _openCurrentRoom(context),
          onNoFamilyTap: () => _showAction(context, 'You are not in a family yet.'),
        ),
        const SizedBox(height: 14),
        MeStatsRow(
          userId: user.id,
          publicUserId: user.publicUserId,
          onFollowingTap: () => _openFollowersFollowed(context, initialTabIndex: 1),
          onFollowersTap: () => _openFollowersFollowed(context, initialTabIndex: 0),
          onRoomsTap: () => _openRooms(context),
          onVisitorsTap: () => _openVisitors(context),
        ),
        const SizedBox(height: 14),
        MeRelationshipPanel(
          publicUserId: user.publicUserId,
          relationshipLabel: relationshipType,
          onBondTap: (bond) => _openBondDetail(context, bond),
        ),
        const SizedBox(height: 18),
        const Text('Account', style: TextStyle(color: Color(0xFF251538), fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
        const SizedBox(height: 12),
        ...items.where((item) {
          if (item.action == 'vip_svip_admin' || item.action == 'coin_supply_grant' || item.action == 'vibes_reports_review') return user.canSeeOwnerControls;
          return true;
        }).map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: MeAccountCard(
              item: item,
              onTap: () async {
                if (item.action == 'edit_profile') {
                  _openEditProfile(context);
                } else if (item.action == 'edit_cover_photos') {
                  await _openEditCoverPhotos(context);
                } else if (item.action == 'vibes_reports_review') {
                  _openVibesReportsReview(context);
                } else if (item.action == 'vip_svip_admin') {
                  _openVipSvipAdmin(context);
                } else if (item.action == 'coin_supply_grant') {
                  _openCoinSupplyGrant(context);
                } else if (item.action == 'game_test') {
                  _openGameTest(context);
                } else if (item.action == 'family' || item.title == 'Family') {
                  _openFamily(context);
                } else if (item.title == 'VIP / SVIP Center' || item.title == 'VIP / SVIP') {
                  _openVipProgram(context, initialTabIndex: item.subtitle.contains('SVIP') ? 1 : 0);
                } else if (item.title == 'Love & Bonds') {
                  _openLoveBonds(context);
                } else if (item.title == 'Store & Inventory') {
                  _openStore(context);
                } else if (item.title == 'Control Center') {
                  _openControlCentre(context);
                } else if (item.title == 'Merchant & Seller Panel') {
                  _openMerchantSellerPanel(context);
                } else if (item.title == 'Settings') {
                  _openAccountSettings(context);
                } else if (item.title == 'Help Centre') {
                  _openHelpCentre(context);
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



class _MeRealFamilyHero extends StatefulWidget {
  const _MeRealFamilyHero({
    required this.user,
    required this.vipColor,
    required this.vipDark,
    required this.onAvatarTap,
    required this.onQrTap,
    required this.onEditCoverPhotosTap,
    required this.onWalletTap,
    required this.onVipTap,
    required this.onSvipTap,
    required this.onRoomTap,
    required this.onNoFamilyTap,
  });

  final CurrentUser user;
  final Color vipColor;
  final Color vipDark;
  final VoidCallback onAvatarTap;
  final VoidCallback onQrTap;
  final VoidCallback onEditCoverPhotosTap;
  final VoidCallback onWalletTap;
  final VoidCallback onVipTap;
  final VoidCallback onSvipTap;
  final VoidCallback onRoomTap;
  final VoidCallback onNoFamilyTap;

  @override
  State<_MeRealFamilyHero> createState() => _MeRealFamilyHeroState();
}

class _MeRealFamilyHeroState extends State<_MeRealFamilyHero> {
  final ProfileApiService _profileApi = const ProfileApiService();
  FamilySummaryDto? _family;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFamily();
  }

  @override
  void didUpdateWidget(covariant _MeRealFamilyHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.publicUserId != widget.user.publicUserId) {
      _loadFamily();
    }
  }

  Future<void> _loadFamily() async {
    setState(() => _loading = true);
    try {
      final family = await _profileApi.getMyFamily();
      if (!mounted) return;
      setState(() => _family = family);
    } catch (_) {
      if (!mounted) return;
      setState(() => _family = FamilySummaryDto.empty());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openRealFamily() {
    final family = _family;
    if (family == null || !family.shouldShow) {
      widget.onNoFamilyTap();
      return;
    }

    final familyProfile = FamilyProfileUiModel(
      id: family.safeId,
      name: family.safeName,
      minimumVipLabel: 'VIP 0',
      memberCount: family.memberCount,
      maxMembers: family.memberCount > 0 ? family.memberCount : 1,
      rankLabel: 'Family Lv. ${family.level}',
      ownerUserId: family.ownerPublicUserId?.toString() ?? '',
      quarterCarryExp: family.totalExp,
      giftCoinsThisQuarter: family.totalExp,
      timeMinutesToday: 0,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FamilyModularPage(
          openCurrentFamily: true,
          initialFamilyProfile: familyProfile,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final family = _family;
    final hasFamily = family != null && family.shouldShow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MePremiumProfileHero(
          displayName: MeProfileConstants.displayNameFor(widget.user),
          publicId: widget.user.publicUserId.toString(),
          role: widget.user.primaryRole,
          roleTag: MeProfileConstants.roleTagFor(widget.user.primaryRole),
          roleBadge: widget.user.primaryRoleBadge,
          vipLevel: widget.user.vip.vipLevel,
          svipLevel: widget.user.vip.svipLevel,
          vipFrozen: !widget.user.vip.vipIsActive,
          vipColor: widget.vipColor,
          vipDark: widget.vipDark,
          diamonds: MeProfileConstants.formatNumber(widget.user.wallet.lifetimeCoinsSpent),
          coins: MeProfileConstants.formatNumber(widget.user.wallet.coinBalance),
          presence: MeProfileConstants.presence,
          lastSeenText: MeProfileConstants.lastSeenText,
          currentRoomName: MeProfileConstants.currentRoomName,
          familyName: hasFamily ? family.safeName : '',
          familyLevel: hasFamily ? family.level : 0,
          onFamilyTap: _openRealFamily,
          onAvatarTap: widget.onAvatarTap,
          onQrTap: widget.onQrTap,
          onEditCoverPhotosTap: widget.onEditCoverPhotosTap,
          onWalletTap: widget.onWalletTap,
          onVipTap: widget.onVipTap,
          onSvipTap: widget.onSvipTap,
          onRoomTap: widget.onRoomTap,
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(
              minHeight: 3,
              color: Color(0xFF12C7B7),
              backgroundColor: Color(0xFFECE2D8),
            ),
          ),
      ],
    );
  }
}

class _MeRealVibesSection extends StatefulWidget {
  const _MeRealVibesSection();

  @override
  State<_MeRealVibesSection> createState() => _MeRealVibesSectionState();
}

class _MeRealVibesSectionState extends State<_MeRealVibesSection> {
  final ProfileApiService _profileApi = const ProfileApiService();
  late Future<List<ProfileVibeDto>> _future;

  @override
  void initState() {
    super.initState();
    _future = _profileApi.listMyVibes();
  }

  Future<void> _refresh() async {
    final nextFuture = _profileApi.listMyVibes();
    setState(() => _future = nextFuture);
    await nextFuture;
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.97),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: const Color(0xFFECE2D8)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF251538).withValues(alpha: 0.045),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProfileVibeDto>>(
      future: _future,
      builder: (context, snapshot) {
        final vibes = snapshot.data ?? const <ProfileVibeDto>[];

        return Container(
          padding: const EdgeInsets.all(15),
          decoration: _panelDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'My Vibes',
                      style: TextStyle(color: Color(0xFF251538), fontSize: 19, fontWeight: FontWeight.w900),
                    ),
                  ),
                  Text(
                    '${vibes.length}',
                    style: const TextStyle(color: Color(0xFFE84C72), fontSize: 12, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              if (snapshot.connectionState == ConnectionState.waiting && vibes.isEmpty)
                const LinearProgressIndicator(minHeight: 3, color: Color(0xFF6D5DF6), backgroundColor: Color(0xFFECE2D8))
              else if (snapshot.hasError && vibes.isEmpty)
                _MeVibesMessage(
                  icon: Icons.wifi_off_rounded,
                  title: 'Could not load Vibes',
                  body: snapshot.error.toString().replaceFirst('Exception: ', ''),
                  onTap: _refresh,
                )
              else if (vibes.isEmpty)
                const _MeVibesMessage(
                  icon: Icons.auto_awesome_rounded,
                  title: 'No Vibes yet',
                  body: 'When you post real Vibes, they will appear here.',
                )
              else
                Column(
                  children: [
                    for (var index = 0; index < vibes.take(3).length; index++) ...[
                      _MeRealVibeCard(vibe: vibes[index]),
                      if (index != vibes.take(3).length - 1) const SizedBox(height: 10),
                    ],
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MeRealVibeCard extends StatelessWidget {
  const _MeRealVibeCard({required this.vibe});

  final ProfileVibeDto vibe;

  @override
  Widget build(BuildContext context) {
    final mediaType = vibe.mediaType.trim().toLowerCase();
    final icon = switch (mediaType) {
      'photo' => Icons.photo_rounded,
      'video' => Icons.play_circle_fill_rounded,
      _ => Icons.notes_rounded,
    };

    final colors = switch (mediaType) {
      'photo' => const <Color>[Color(0xFF6D5DF6), Color(0xFFE84C72)],
      'video' => const <Color>[Color(0xFF12C7B7), Color(0xFF6D5DF6)],
      _ => const <Color>[Color(0xFF251538), Color(0xFFC99A3B)],
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFECE2D8)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vibe.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF251538), fontSize: 14, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  vibe.caption.trim().isEmpty ? 'Shared a Vibe.' : vibe.caption.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF7A6B86), fontSize: 12, fontWeight: FontWeight.w700, height: 1.25),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(vibe.timeAgo, style: const TextStyle(color: Color(0xFF12A99E), fontSize: 10.5, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 9),
                    Text('❤ ${vibe.likesLabel}', style: const TextStyle(color: Color(0xFFE84C72), fontSize: 10.5, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 9),
                    Text('💬 ${vibe.commentsLabel}', style: const TextStyle(color: Color(0xFF6D5DF6), fontSize: 10.5, fontWeight: FontWeight.w900)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MeVibesMessage extends StatelessWidget {
  const _MeVibesMessage({
    required this.icon,
    required this.title,
    required this.body,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final Future<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap == null ? null : () => onTap!.call(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF7F1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFECE2D8)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF6D5DF6), size: 30),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: Color(0xFF251538), fontSize: 15, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF7A6B86), fontSize: 12, fontWeight: FontWeight.w700, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}
class _MeLoveBondBackendSyncGate extends StatefulWidget {
  const _MeLoveBondBackendSyncGate({required this.user});

  final CurrentUser user;

  @override
  State<_MeLoveBondBackendSyncGate> createState() => _MeLoveBondBackendSyncGateState();
}

class _MeLoveBondBackendSyncGateState extends State<_MeLoveBondBackendSyncGate> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _MeLoveBondBackendSyncGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.publicUserId != widget.user.publicUserId) {
      _started = false;
      _sync();
    }
  }

  Future<void> _sync() async {
    if (_started) return;
    _started = true;

    try {
      await LoveBondRealtimeService.syncMyBondsFromBackend(
        currentUserId: widget.user.id,
        currentPublicUserId: widget.user.publicUserId,
        currentDisplayName: widget.user.displayName ?? widget.user.username ?? 'Vibe User',
        currentGender: widget.user.gender,
        currentAvatarUrl: widget.user.avatarUrl,
      );
    } catch (_) {
      // Keep current local state if backend is temporarily unavailable.
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}


