import 'dart:async';

import 'package:flutter/material.dart';

import '../../../auth/models/current_user.dart';
import '../../../control_center/presentation/control_center_hub_page.dart';
import '../../../economy/presentation/merchant_seller_panel_page.dart';
import '../../../family/models/family_ui_models.dart';
import '../../../family/presentation/family_modular_page.dart';
import '../../../games/presentation/game_test_page.dart';
import '../../../presence/data/presence_api_service.dart';
import '../../../rooms/presentation/live_room_models.dart';
import '../../../rooms/presentation/live_room_page.dart';
import '../../../rooms/presentation/widgets/followers_followed_page.dart';
import '../../../vip/presentation/vip_program_page.dart';
import '../../../wallet/data/wallet_api_service.dart';
import '../../../wallet/presentation/wallet_page_modular.dart';
import '../../data/love_bond_realtime_service.dart';
import '../../data/profile_api_service.dart';
import '../control_center/coin_supply_grant_page.dart';
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

class MePageContent extends StatefulWidget {
  const MePageContent({super.key, required this.user, required this.onLogoutPressed, required this.onRefreshPressed});
  final CurrentUser user;
  final Future<void> Function() onLogoutPressed;
  final Future<void> Function() onRefreshPressed;
  @override
  State<MePageContent> createState() => _MePageContentState();
}

class _MePageContentState extends State<MePageContent> {
  final WalletApiService _walletApi = const WalletApiService();
  final PresenceApiService _presenceApi = const PresenceApiService();
  final ProfileApiService _profileApi = const ProfileApiService();

  CurrentUser? _freshUser;
  VmWallet? _wallet;
  PresenceDto? _presence;
  FamilySummaryDto? _family;
  bool _loadingRealData = true;
  String? _loadError;

  CurrentUser get user => _freshUser ?? widget.user;

  SeatUser get _viewerSeatUser => SeatUser(
        id: 'user_${user.publicUserId}',
        name: _displayName,
        roleLabel: user.roleDisplayLabel,
        familyName: _family?.shouldShow == true ? _family!.safeName : '',
        familyLevel: (_family?.level ?? 0).toString(),
        relationshipText: '',
        vipLevel: _vipLevel,
        svipLevel: _svipLevel,
        sendingLevel: 0,
        receivingLevel: 0,
        sentExp: 0,
        receivedExp: 0,
        medals: const [],
        avatarColors: const [Color(0xFF12C7B7), Color(0xFF6D5DF6)],
        avatarUrl: user.avatarUrl,
        isCurrentUser: true,
        isHost: user.canSeeOwnerControls,
        isRoomAdmin: user.canSeeOwnerControls,
      );

  List<SeatUser> get _socialPreviewUsers => <SeatUser>[_viewerSeatUser];

  String get _displayName {
    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    final username = user.username?.trim();
    if (username != null && username.isNotEmpty) return username;
    return 'User ${user.publicUserId}';
  }

  int get _vipLevel => _wallet?.vipLevel ?? user.vip.vipLevel;
  int get _svipLevel => _wallet?.svipLevel ?? user.vip.svipLevel;
  int get _coinBalance => _wallet?.coinBalance ?? user.wallet.coinBalance;
  int get _rubyBalance => _wallet?.rubyBalance ?? user.wallet.rubyBalance;
  int get _lifetimeRechargeCoins => _wallet?.lifetimeRechargeCoins ?? user.wallet.lifetimeCoinsSpent;
  int get _monthlyRechargeCoins => _wallet?.monthlyRechargeCoins ?? 0;
  String? get _currentRoomName => _presence?.hasVisibleRoom == true ? _presence!.roomName : null;
  String? get _currentRoomId => _presence?.hasVisibleRoom == true ? _presence!.roomPublicId : null;
  String get _lastSeenText => _presence?.onlineLabel ?? _lastSeenFromUser;
  MePresenceStatus get _presenceStatus => (_presence?.isOnline ?? false) ? MePresenceStatus.online : MePresenceStatus.offline;

  String get _lastSeenFromUser {
    final seen = user.lastSeenAt;
    if (seen == null) return 'Offline';
    final diff = DateTime.now().difference(seen.toLocal());
    if (diff.inMinutes < 1) return 'last seen just now';
    if (diff.inMinutes < 60) return 'last seen ${diff.inMinutes} min ago';
    if (diff.inHours < 24) return 'last seen ${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    if (diff.inDays < 30) return 'last seen ${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    return 'last seen a month ago';
  }

  String get _coverPhotoStatus => user.coverPhotoUrls.isEmpty ? 'No cover photo' : '${user.coverPhotoUrls.length} active';

  @override
  void initState() {
    super.initState();
    unawaited(_loadRealData());
  }

  @override
  void didUpdateWidget(covariant MePageContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.publicUserId != widget.user.publicUserId) {
      _freshUser = null;
      unawaited(_loadRealData());
    }
  }

  Future<void> _loadRealData() async {
    setState(() {
      _loadingRealData = true;
      _loadError = null;
    });
    try {
      final freshUser = await _profileApi.getMe(forceRefresh: true);
      final results = await Future.wait<Object?>([_walletApi.getWallet(), _presenceApi.getPublicPresence(freshUser.publicUserId), _profileApi.getMyFamily()]);
      if (!mounted) return;
      setState(() {
        _freshUser = freshUser;
        _wallet = results[0] as VmWallet;
        _presence = results[1] as PresenceDto;
        _family = results[2] as FamilySummaryDto;
        _loadingRealData = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.toString().replaceFirst('Exception: ', '');
        _loadingRealData = false;
      });
    }
  }

  void _showAction(BuildContext context, String message) {
    ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(SnackBar(content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)), behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF251538)));
  }

  Future<void> _refreshAll() async {
    await widget.onRefreshPressed();
    await _loadRealData();
  }

  Future<void> _endSession(BuildContext context) async {
    final shouldEnd = await showMeSessionSheet(context);
    if (shouldEnd == true) await widget.onLogoutPressed();
  }

  void _openEditProfile(BuildContext context) => Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => EditProfilePage(user: user))).then((changed) { if (changed == true) unawaited(_refreshAll()); });
  void _openProfileQrActions(BuildContext context) => ProfileQrActionsSheet.show(context, user: user);
  Future<void> _openEditCoverPhotos(BuildContext context) async { final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => EditCoverPhotosPage(initialCoverPhotoUrls: user.coverPhotoUrls))); if (changed == true) await _refreshAll(); }
  void _openAccountSettings(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AccountSettingsPage(svipLevel: _svipLevel)));
  void _openHelpCentre(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpCenterPage()));
  void _openStore(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VmStorePage()));
  void _openLoveBonds(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoveBondsPage()));
  void _openWallet(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WalletPageModular())).then((_) => _loadRealData());
  void _openControlCentre(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ControlCenterHubPage())).then((_) => _refreshAll());

  void _openVipSvipAdmin(BuildContext context) { if (!user.canSeeOwnerControls) { _showAction(context, 'Only Owner/Super Owner can adjust VIP/SVIP levels.'); return; } Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VipSvipAdminPage())).then((_) => _refreshAll()); }
  void _openCoinSupplyGrant(BuildContext context) { if (!user.canSeeOwnerControls) { _showAction(context, 'Only Owner/Super Owner can grant coin supply.'); return; } Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CoinSupplyGrantPage())).then((_) => _refreshAll()); }
  void _openGameTest(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GameTestPage()));
  void _openMerchantSellerPanel(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MerchantSellerPanelPage())).then((_) => _refreshAll());

  void _openFamily(BuildContext context) {
    final family = _family;
    if (family == null || !family.shouldShow) { _showAction(context, 'You are not in a family yet.'); return; }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => FamilyModularPage(openCurrentFamily: true, initialFamilyProfile: FamilyProfileUiModel(id: family.safeId, name: family.safeName, minimumVipLabel: 'VIP 0', memberCount: family.memberCount, maxMembers: family.memberCount > 0 ? family.memberCount : 1, rankLabel: 'Family Lv. ${family.level}', ownerUserId: family.ownerPublicUserId?.toString() ?? '', quarterCarryExp: family.totalExp, giftCoinsThisQuarter: family.totalExp, timeMinutesToday: 0)))).then((_) => _loadRealData());
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PublicProfileViewPage(user: user, publicUserId: user.publicUserId, vipLevel: _vipLevel, svipLevel: _svipLevel, presenceLabel: _lastSeenText, currentRoomName: _currentRoomName, relationshipLabel: '', familyName: _family?.shouldShow == true ? _family!.safeName : '', familyLevel: _family?.level ?? 0)));
  }

  void _openVipProgram(BuildContext context, {int initialTabIndex = 0}) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => VipProgramPage(initialTabIndex: initialTabIndex, vipLevel: _vipLevel, svipLevel: _svipLevel, lifetimeRechargeCoins: _lifetimeRechargeCoins, monthlyRechargeCoins: _monthlyRechargeCoins)));
  void _openBondDetail(BuildContext context, LoveBondCardData bond) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LoveBondDetailPage(bond: bond)));
  void _openFollowersFollowed(BuildContext context, {required int initialTabIndex}) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FollowersFollowedPage(user: _viewerSeatUser, users: _socialPreviewUsers, initialTabIndex: initialTabIndex)));
  void _openVisitors(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfileVisitorsPage(profileOwnerUserId: user.id)));
  void _openRooms(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfileRoomsPage(userId: user.id, publicUserId: user.publicUserId)));

  void _openCurrentRoom(BuildContext context) {
    final roomName = _currentRoomName;
    final roomId = _currentRoomId;
    if (roomName == null || roomName.trim().isEmpty || roomId == null || roomId.trim().isEmpty) { _showAction(context, 'No active room right now.'); return; }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => LiveRoomPage(roomName: roomName, roomId: roomId, language: 'English', modeTitle: _presence?.roomMode ?? 'Open', onlineCount: 1, currentUser: user)));
  }

  @override
  Widget build(BuildContext context) {
    final vipColor = MeProfileConstants.vipMainColor(_vipLevel);
    final vipDark = MeProfileConstants.vipDarkColor(_vipLevel);
    final items = buildMeActionItems(vipLevel: _vipLevel, svipLevel: _svipLevel, coverPhotoStatus: _coverPhotoStatus);
    return RefreshIndicator(
      color: const Color(0xFF12C7B7),
      onRefresh: _refreshAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 116),
        children: [
          _MeLoveBondBackendSyncGate(user: user),
          if (_loadingRealData) const LinearProgressIndicator(minHeight: 3, color: Color(0xFF12C7B7), backgroundColor: Color(0xFFECE2D8)),
          if (_loadError != null) _RealDataErrorBanner(message: _loadError!, onRetry: _loadRealData),
          MePremiumProfileHero(
            displayName: _displayName,
            publicId: user.visibleId,
            role: user.primaryRole,
            roleTag: MeProfileConstants.roleTagFor(user.primaryRole),
            roleBadge: user.primaryRoleBadge,
            vipLevel: _vipLevel,
            svipLevel: _svipLevel,
            vipFrozen: !user.vip.vipIsActive,
            vipColor: vipColor,
            vipDark: vipDark,
            diamonds: MeProfileConstants.formatNumber(_rubyBalance),
            coins: MeProfileConstants.formatNumber(_coinBalance),
            presence: _presenceStatus,
            lastSeenText: _lastSeenText,
            currentRoomName: _currentRoomName,
            familyName: _family?.shouldShow == true ? _family!.safeName : '',
            familyLevel: _family?.level ?? 0,
            avatarUrl: user.avatarUrl,
            coverPhotoUrls: user.coverPhotoUrls,
            onFamilyTap: () => _openFamily(context),
            onAvatarTap: () => _openProfile(context),
            onQrTap: () => _openProfileQrActions(context),
            onEditCoverPhotosTap: () => _openEditCoverPhotos(context),
            onWalletTap: () => _openWallet(context),
            onVipTap: () => _openVipProgram(context),
            onSvipTap: () => _openVipProgram(context, initialTabIndex: 1),
            onRoomTap: () => _openCurrentRoom(context),
          ),
          const SizedBox(height: 14),
          MeStatsRow(userId: user.id, publicUserId: user.publicUserId, onFollowingTap: () => _openFollowersFollowed(context, initialTabIndex: 1), onFollowersTap: () => _openFollowersFollowed(context, initialTabIndex: 0), onRoomsTap: () => _openRooms(context), onVisitorsTap: () => _openVisitors(context)),
          const SizedBox(height: 14),
          MeRelationshipPanel(publicUserId: user.publicUserId, relationshipLabel: '', onBondTap: (bond) => _openBondDetail(context, bond)),
          const SizedBox(height: 18),
          const Text('Account', style: TextStyle(color: Color(0xFF251538), fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
          const SizedBox(height: 12),
          ...items.where((item) => (item.action == 'vip_svip_admin' || item.action == 'coin_supply_grant') ? user.canSeeOwnerControls : true).map((item) => Padding(padding: const EdgeInsets.only(bottom: 12), child: MeAccountCard(item: item, onTap: () async {
            if (item.action == 'edit_profile') { _openEditProfile(context); }
            else if (item.action == 'edit_cover_photos') { await _openEditCoverPhotos(context); }
            else if (item.action == 'vip_svip_admin') { _openVipSvipAdmin(context); }
            else if (item.action == 'coin_supply_grant') { _openCoinSupplyGrant(context); }
            else if (item.action == 'game_test') { _openGameTest(context); }
            else if (item.action == 'family' || item.title == 'Family') { _openFamily(context); }
            else if (item.title == 'VIP / SVIP Center' || item.title == 'VIP / SVIP') { _openVipProgram(context, initialTabIndex: item.subtitle.contains('SVIP') ? 1 : 0); }
            else if (item.title == 'Love & Bonds') { _openLoveBonds(context); }
            else if (item.title == 'Store & Inventory') { _openStore(context); }
            else if (item.title == 'Control Center') { _openControlCentre(context); }
            else if (item.title == 'Merchant & Seller Panel') { _openMerchantSellerPanel(context); }
            else if (item.title == 'Settings') { _openAccountSettings(context); }
            else if (item.title == 'Help Centre') { _openHelpCentre(context); }
            else if (item.action == 'logout') { await _endSession(context); }
            else if (item.action == 'refresh') { await _refreshAll(); if (context.mounted) _showAction(context, 'Profile refreshed.'); }
            else { _showAction(context, item.action); }
          }))),
        ],
      ),
    );
  }
}

class _RealDataErrorBanner extends StatelessWidget {
  const _RealDataErrorBanner({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE8C77C))), child: Row(children: [const Icon(Icons.wifi_off_rounded, color: Color(0xFFC99A3B), size: 18), const SizedBox(width: 8), Expanded(child: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w800))), TextButton(onPressed: onRetry, child: const Text('Retry'))]));
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
  void initState() { super.initState(); _sync(); }
  @override
  void didUpdateWidget(covariant _MeLoveBondBackendSyncGate oldWidget) { super.didUpdateWidget(oldWidget); if (oldWidget.user.publicUserId != widget.user.publicUserId) { _started = false; _sync(); } }
  Future<void> _sync() async { if (_started) return; _started = true; try { await LoveBondRealtimeService.syncMyBondsFromBackend(currentUserId: widget.user.id, currentPublicUserId: widget.user.publicUserId, currentDisplayName: widget.user.displayName ?? widget.user.username ?? 'Vibe User', currentGender: widget.user.gender, currentAvatarUrl: widget.user.avatarUrl); } catch (_) {} }
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
