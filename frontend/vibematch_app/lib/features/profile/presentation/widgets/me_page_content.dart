import 'package:flutter/material.dart';

import '../../../auth/models/current_user.dart';
import '../../../family/presentation/family_page.dart';
import '../edit_profile_page.dart';
import '../love_bonds/love_bond_detail_page.dart';
import '../love_bonds/models/love_bond_models.dart';
import '../models/me_page_models.dart';
import '../public_profile_view_page.dart';
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
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FamilyPage()));
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

  void _openBondDetail(BuildContext context, LoveBondCardData bond) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => LoveBondDetailPage(bond: bond)));
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
          onFamilyTap: () => _openFamily(context),
          onAvatarTap: () => _openProfile(context),
          onQrTap: () => _showAction(context, 'Profile QR / share card will open.'),
          onWalletTap: () => _showAction(context, 'Wallet page will open.'),
          onVipTap: () => _showAction(context, 'VIP / SVIP details will open.'),
          onRoomTap: () => _showAction(context, 'Open ${MeProfileConstants.currentRoomName} room preview. Secret Vibe rooms will be hidden later.'),
        ),
        const SizedBox(height: 14),
        MeStatsRow(onAction: (message) => _showAction(context, message)),
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
                } else if (item.action == 'family') {
                  _openFamily(context);
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
