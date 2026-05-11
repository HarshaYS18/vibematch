import 'package:flutter/material.dart';

import '../../../auth/models/role_badge.dart';
import '../models/public_profile_models.dart';
import 'official_role_badge_pill.dart';
import 'public_profile_shared_widgets.dart';

class PublicProfileHeader extends StatelessWidget {
  const PublicProfileHeader({
    super.key,
    required this.displayName,
    required this.username,
    required this.publicId,
    required this.roleTag,
    required this.roleBadge,
    required this.showOfficialTick,
    required this.vipLevel,
    required this.svipLevel,
    required this.presenceLabel,
    required this.currentRoomName,
    required this.familyName,
    required this.familyLevel,
    required this.coverPhotos,
    required this.coverController,
    required this.coverIndex,
    required this.followStatus,
    required this.matchScore,
    required this.onCoverChanged,
    required this.onBackTap,
    required this.onQrTap,
    required this.onShareTap,
    required this.onAddCoverTap,
    required this.onFollowTap,
    required this.onMessageTap,
    required this.onRoomTap,
    required this.onFamilyTap,
    required this.onVipTap,
    required this.onSvipTap,
    this.showSocialActions = true,
    this.showOwnerActions = false,
    this.followersCount,
    this.followingCount,
  });

  final String displayName;
  final String username;
  final String publicId;
  final String? roleTag;
  final RoleBadge? roleBadge;
  final bool showOfficialTick;
  final int vipLevel;
  final int svipLevel;
  final String presenceLabel;
  final String? currentRoomName;
  final String familyName;
  final int familyLevel;
  final List<PublicCoverPhoto> coverPhotos;
  final PageController coverController;
  final int coverIndex;
  final PublicFollowStatus followStatus;
  final int? matchScore;
  final ValueChanged<int> onCoverChanged;
  final VoidCallback onBackTap;
  final VoidCallback onQrTap;
  final VoidCallback onShareTap;
  final VoidCallback onAddCoverTap;
  final VoidCallback onFollowTap;
  final VoidCallback onMessageTap;
  final VoidCallback onRoomTap;
  final VoidCallback onFamilyTap;
  final VoidCallback onVipTap;
  final VoidCallback onSvipTap;
  final bool showSocialActions;
  final bool showOwnerActions;
  final int? followersCount;
  final int? followingCount;

  List<Widget> _badgeLineItems() {
    return [
      if (roleBadge != null)
        OfficialRoleBadgePill(badge: roleBadge!)
      else if (roleTag != null)
        PublicBadge(icon: Icons.workspace_premium_rounded, label: roleTag!, color: const Color(0xFFFFD36A)),
      PublicBadge(icon: Icons.diamond_rounded, label: 'VIP $vipLevel', color: const Color(0xFFE84C72), onTap: onVipTap),
      PublicBadge(icon: Icons.auto_awesome_rounded, label: 'SVIP $svipLevel', color: const Color(0xFF6D5DF6), onTap: onSvipTap),
      if (familyName.trim().isNotEmpty) PublicBadge(icon: Icons.family_restroom_rounded, label: familyName, color: const Color(0xFF12C7B7), onTap: onFamilyTap),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final badges = _badgeLineItems();
    final followersText = _compactCount(followersCount ?? 0);
    final followingText = _compactCount(followingCount ?? 0);
    final score = matchScore;

    return Container(
      margin: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      decoration: publicProfileWhitePanelDecoration(radius: 34),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                height: 164,
                child: PageView.builder(controller: coverController, itemCount: coverPhotos.length, onPageChanged: onCoverChanged, itemBuilder: (context, index) => PublicCoverPhotoView(cover: coverPhotos[index])),
              ),
              Positioned(left: 14, top: 14, child: PublicHeaderIconButton(icon: Icons.arrow_back_rounded, onTap: onBackTap)),
              Positioned(
                right: 14,
                top: 14,
                child: Row(children: [
                  if (showOwnerActions) ...[
                    PublicHeaderIconButton(icon: Icons.add_photo_alternate_rounded, onTap: onAddCoverTap),
                    const SizedBox(width: 8),
                  ],
                  PublicHeaderIconButton(icon: Icons.qr_code_2_rounded, onTap: onQrTap),
                  const SizedBox(width: 8),
                  PublicHeaderIconButton(icon: Icons.ios_share_rounded, onTap: onShareTap),
                ]),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    coverPhotos.length,
                    (index) => AnimatedContainer(duration: const Duration(milliseconds: 180), margin: const EdgeInsets.symmetric(horizontal: 3), width: index == coverIndex ? 18 : 6, height: 6, decoration: BoxDecoration(color: Colors.white.withValues(alpha: index == coverIndex ? 0.95 : 0.45), borderRadius: BorderRadius.circular(99))),
                  ),
                ),
              ),
              Positioned(left: 18, bottom: -54, child: _PublicAvatar(displayName: displayName)),
            ],
          ),
          const SizedBox(height: 62),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
                      Flexible(child: Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF251538), fontSize: 27, fontWeight: FontWeight.w900, letterSpacing: -0.6))),
                      if (showOfficialTick) ...[const SizedBox(width: 5), const Icon(Icons.verified_rounded, color: Color(0xFFFFC857), size: 24)],
                    ]),
                    const SizedBox(height: 6),
                    Text('ID $publicId', style: const TextStyle(color: Color(0xFF8C7B8F), fontSize: 13, fontWeight: FontWeight.w800)),
                  ]),
                ),
                if (score != null) ...[
                  const SizedBox(width: 10),
                  _PremiumMatchScorePill(score: score),
                ],
              ]),
              const SizedBox(height: 10),
              if (badges.isNotEmpty)
                SizedBox(height: 30, child: SingleChildScrollView(scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [for (var index = 0; index < badges.length; index++) ...[badges[index], if (index != badges.length - 1) const SizedBox(width: 8)]]))),
              const SizedBox(height: 12),
              _PresenceLine(presenceLabel: presenceLabel, currentRoomName: currentRoomName, onRoomTap: onRoomTap),
              if (showSocialActions) ...[
                const SizedBox(height: 16),
                Row(children: [Expanded(child: PublicMainProfileButton(label: followStatus.label, icon: followStatus.icon, filled: true, onTap: onFollowTap)), const SizedBox(width: 10), Expanded(child: PublicMainProfileButton(label: 'Message', icon: Icons.chat_bubble_rounded, filled: false, onTap: onMessageTap))]),
              ],
              const SizedBox(height: 16),
              Row(children: [Expanded(child: PublicStat(value: followersText, label: 'Followers')), const SizedBox(width: 6), Expanded(child: PublicStat(value: followingText, label: 'Following')), const SizedBox(width: 6), const Expanded(child: PublicStat(value: '0', label: 'Rooms')), const SizedBox(width: 6), const Expanded(child: PublicStat(value: '0', label: 'Received'))]),
            ]),
          ),
        ],
      ),
    );
  }
}

String _compactCount(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
  return value.toString();
}

class _PremiumMatchScorePill extends StatelessWidget {
  const _PremiumMatchScorePill({required this.score});
  final int score;
  @override
  Widget build(BuildContext context) {
    final progress = (score / 100).clamp(0.0, 1.0);
    return Container(width: 82, padding: const EdgeInsets.all(7), decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFF7FB), Color(0xFFFFEAF2)]), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE84C72).withValues(alpha: 0.20)), boxShadow: [BoxShadow(color: const Color(0xFFE84C72).withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 7))]), child: Column(mainAxisSize: MainAxisSize.min, children: [Stack(alignment: Alignment.center, children: [SizedBox(width: 34, height: 34, child: CircularProgressIndicator(value: progress, strokeWidth: 3.2, backgroundColor: const Color(0xFFE84C72).withValues(alpha: 0.12), color: const Color(0xFFE84C72))), const Icon(Icons.favorite_rounded, color: Color(0xFFE84C72), size: 18)]), const SizedBox(height: 5), Text('$score%', style: const TextStyle(color: Color(0xFFE84C72), fontSize: 13, fontWeight: FontWeight.w900, height: 1)), const SizedBox(height: 2), const Text('Match', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Color(0xFF7B6A86), fontSize: 9.5, fontWeight: FontWeight.w900, height: 1))]));
  }
}

class _PublicAvatar extends StatelessWidget {
  const _PublicAvatar({required this.displayName});
  final String displayName;
  @override
  Widget build(BuildContext context) {
    final firstLetter = displayName.trim().isEmpty ? 'V' : displayName.trim()[0].toUpperCase();
    return Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 9))]), child: Container(width: 96, height: 96, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF6D5DF6), Color(0xFFE84C72), Color(0xFFFFD36A)])), child: Center(child: Text(firstLetter, style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900)))));
  }
}

class _PresenceLine extends StatelessWidget {
  const _PresenceLine({required this.presenceLabel, required this.currentRoomName, required this.onRoomTap});
  final String presenceLabel;
  final String? currentRoomName;
  final VoidCallback onRoomTap;
  @override
  Widget build(BuildContext context) {
    final roomName = currentRoomName;
    return Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [PublicTinyStatusChip(icon: Icons.circle, label: presenceLabel, color: const Color(0xFF12C7B7)), if (roomName != null) InkWell(onTap: onRoomTap, borderRadius: BorderRadius.circular(99), child: PublicTinyStatusChip(icon: Icons.graphic_eq_rounded, label: 'In chatroom: $roomName', color: const Color(0xFF6D5DF6)))]);
  }
}
