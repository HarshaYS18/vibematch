import 'package:flutter/material.dart';

import '../../../auth/models/current_user.dart';
import '../../../economy/presentation/merchant_seller_panel_page.dart';
import '../../../family/presentation/family_modular_page.dart';
import '../../../games/presentation/game_test_page.dart';
import '../../../vip/presentation/vip_program_page.dart';
import '../../../wallet/presentation/wallet_page.dart';
import '../control_center/coin_supply_grant_page.dart';
import '../control_center/super_power_panel_page.dart';
import '../control_center/vibes_reports_review_page.dart';
import '../control_center/vip_svip_admin_page.dart';
import '../cover_photos/edit_cover_photos_page.dart';
import '../edit_profile_page.dart';
import '../help_center/help_center_page.dart';
import '../love_bonds/love_bonds_page.dart';
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
  const MePageContent({super.key, required this.user, required this.onLogoutPressed, required this.onRefreshPressed});

  final CurrentUser user;
  final Future<void> Function() onLogoutPressed;
  final Future<void> Function() onRefreshPressed;

  void _showAction(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)), behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF251538)));
  }

  Future<void> _endSession(BuildContext context) async {
    final shouldEnd = await showMeSessionSheet(context);
    if (shouldEnd == true) await onLogoutPressed();
  }

  void _openEditProfile(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditProfilePage(user: user)));
  void _openProfileQrActions(BuildContext context) => ProfileQrActionsSheet.show(context, user: user);

  Future<void> _openEditCoverPhotos(BuildContext context) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => EditCoverPhotosPage(initialCoverPhotoUrls: user.coverPhotoUrls)));
    if (changed == true) await onRefreshPressed();
  }

  void _openAccountSettings(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AccountSettingsPage(svipLevel: user.vip.svipLevel)));
  void _openHelpCentre(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpCenterPage()));
  void _openStore(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VmStorePage()));
  void _openLoveBonds(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoveBondsPage()));
  void _openWallet(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WalletPage()));
  void _openControlCentre(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SuperPowerPanelPage(currentRole: user.primaryRole)));

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

  void _openGameTest(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GameTestPage()));
  void _openMerchantSellerPanel(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MerchantSellerPanelPage()));
  void _openFamily(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FamilyModularPage()));

  void _openProfile(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PublicProfileViewPage(user: user, vipLevel: user.vip.vipLevel, svipLevel: user.vip.svipLevel, presenceLabel: _presenceLabel, currentRoomName: null, relationshipLabel: '', familyName: '', familyLevel: 0)));
  }

  void _openVipProgram(BuildContext context, {int initialTabIndex = 0}) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => VipProgramPage(initialTabIndex: initialTabIndex, vipLevel: user.vip.vipLevel, svipLevel: user.vip.svipLevel, lifetimeRechargeCoins: user.wallet.lifetimeCoinsSpent, monthlyRechargeCoins: 0)));
  }

  void _openVisitors(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfileVisitorsPage(profileOwnerUserId: user.id)));
  void _openRooms(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfileRoomsPage(userId: user.id)));

  String get _presenceLabel {
    final lastSeen = user.lastSeenAt;
    if (lastSeen == null) return 'Offline';
    final diff = DateTime.now().difference(lastSeen.toLocal());
    if (diff.inMinutes < 2) return 'Online';
    if (diff.inMinutes < 60) return 'last seen ${diff.inMinutes} min ago';
    if (diff.inHours < 24) return 'last seen ${diff.inHours} hour ago';
    return 'last seen ${diff.inDays} day ago';
  }

  @override
  Widget build(BuildContext context) {
    final vipColor = MeProfileConstants.vipMainColor(user.vip.vipLevel);
    final vipDark = MeProfileConstants.vipDarkColor(user.vip.vipLevel);
    final items = buildMeActionItems(vipLevel: user.vip.vipLevel, svipLevel: user.vip.svipLevel, coverPhotoStatus: user.coverPhotoUrls.isEmpty ? 'No cover photos' : '${user.coverPhotoUrls.length} cover photos');

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 116),
      children: [
        MePremiumProfileHero(
          displayName: MeProfileConstants.displayNameFor(user),
          publicId: user.publicUserId.toString(),
          role: user.primaryRole,
          roleTag: MeProfileConstants.roleTagFor(user.primaryRole),
          roleBadge: user.primaryRoleBadge,
          vipLevel: user.vip.vipLevel,
          svipLevel: user.vip.svipLevel,
          vipFrozen: !user.vip.vipIsActive,
          vipColor: vipColor,
          vipDark: vipDark,
          diamonds: MeProfileConstants.formatNumber(user.wallet.lifetimeCoinsSpent),
          coins: MeProfileConstants.formatNumber(user.wallet.coinBalance),
          presence: user.lastSeenAt != null && DateTime.now().difference(user.lastSeenAt!.toLocal()).inMinutes < 2 ? MePresenceStatus.online : MePresenceStatus.offline,
          lastSeenText: _presenceLabel,
          currentRoomName: null,
          familyName: '',
          familyLevel: 0,
          coverPhotoUrls: user.coverPhotoUrls,
          onFamilyTap: () => _openFamily(context),
          onAvatarTap: () => _openProfile(context),
          onQrTap: () => _openProfileQrActions(context),
          onEditCoverPhotosTap: () => _openEditCoverPhotos(context),
          onWalletTap: () => _openWallet(context),
          onVipTap: () => _openVipProgram(context),
          onSvipTap: () => _openVipProgram(context, initialTabIndex: 1),
          onRoomTap: () => _showAction(context, 'No active room right now.'),
        ),
        const SizedBox(height: 14),
        MeStatsRow(onFollowingTap: () => _showAction(context, 'Following list will open when backend social counts are connected.'), onFollowersTap: () => _showAction(context, 'Followers list will open when backend social counts are connected.'), onRoomsTap: () => _openRooms(context), onVisitorsTap: () => _openVisitors(context)),
        const SizedBox(height: 18),
        const Text('Account', style: TextStyle(color: Color(0xFF251538), fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
        const SizedBox(height: 12),
        ...items.where((item) {
          if (item.action == 'vip_svip_admin' || item.action == 'coin_supply_grant' || item.action == 'vibes_reports_review') return user.canSeeOwnerControls;
          return true;
        }).map((item) => Padding(
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
            )),
      ],
    );
  }
}
