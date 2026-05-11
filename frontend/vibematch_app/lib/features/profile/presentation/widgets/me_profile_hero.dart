import 'dart:async';

import 'package:flutter/material.dart';

import '../../../auth/models/role_badge.dart';
import '../models/me_page_models.dart';
import '../models/public_profile_models.dart';
import 'me_shared_widgets.dart';
import 'official_role_badge_pill.dart';
import 'public_profile_shared_widgets.dart';

class MePremiumProfileHero extends StatefulWidget {
  const MePremiumProfileHero({
    super.key,
    required this.displayName,
    required this.publicId,
    required this.role,
    required this.roleTag,
    required this.roleBadge,
    required this.vipLevel,
    required this.svipLevel,
    required this.vipFrozen,
    required this.vipColor,
    required this.vipDark,
    required this.diamonds,
    required this.coins,
    required this.presence,
    required this.lastSeenText,
    required this.currentRoomName,
    required this.familyName,
    required this.familyLevel,
    required this.coverPhotoUrls,
    required this.onFamilyTap,
    required this.onAvatarTap,
    required this.onQrTap,
    required this.onEditCoverPhotosTap,
    required this.onWalletTap,
    required this.onVipTap,
    required this.onSvipTap,
    required this.onRoomTap,
  });

  final String displayName;
  final String publicId;
  final String role;
  final String? roleTag;
  final RoleBadge? roleBadge;
  final int vipLevel;
  final int svipLevel;
  final bool vipFrozen;
  final Color vipColor;
  final Color vipDark;
  final String diamonds;
  final String coins;
  final MePresenceStatus presence;
  final String lastSeenText;
  final String? currentRoomName;
  final String familyName;
  final int familyLevel;
  final List<String> coverPhotoUrls;
  final VoidCallback onFamilyTap;
  final VoidCallback onAvatarTap;
  final VoidCallback onQrTap;
  final VoidCallback onEditCoverPhotosTap;
  final VoidCallback onWalletTap;
  final VoidCallback onVipTap;
  final VoidCallback onSvipTap;
  final VoidCallback onRoomTap;

  @override
  State<MePremiumProfileHero> createState() => _MePremiumProfileHeroState();
}

class _MePremiumProfileHeroState extends State<MePremiumProfileHero> {
  final PageController _coverController = PageController();
  Timer? _coverTimer;
  int _coverIndex = 0;

  List<PublicCoverPhoto> get _coverPhotos => publicCoverPhotosFromUrls(widget.coverPhotoUrls);

  bool get _showOfficialTick {
    final normalized = widget.role.toLowerCase().trim();
    return widget.roleBadge?.showVerifiedTick == true || normalized == 'founder_owner' || normalized == 'super_owner' || normalized == 'owner';
  }

  @override
  void initState() {
    super.initState();
    _startCoverAutoScroll();
  }

  @override
  void didUpdateWidget(covariant MePremiumProfileHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverPhotoUrls.join('|') != widget.coverPhotoUrls.join('|')) {
      _coverIndex = 0;
      _startCoverAutoScroll();
    }
  }

  @override
  void dispose() {
    _coverTimer?.cancel();
    _coverController.dispose();
    super.dispose();
  }

  void _startCoverAutoScroll() {
    _coverTimer?.cancel();
    final photos = _coverPhotos;
    if (photos.length < 2) return;
    _coverTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final currentPhotos = _coverPhotos;
      if (!mounted || !_coverController.hasClients || currentPhotos.length < 2) return;
      final nextIndex = (_coverIndex + 1) % currentPhotos.length;
      _coverController.animateToPage(nextIndex, duration: const Duration(milliseconds: 520), curve: Curves.easeOutCubic);
    });
  }

  List<Widget> _badgeLineItems() {
    final badge = widget.roleBadge;
    return [
      if (badge != null && badge.badgeLabel.trim().isNotEmpty)
        OfficialRoleBadgePill(badge: badge)
      else if (widget.roleTag != null && widget.roleTag!.trim().isNotEmpty)
        MeProfileMiniBadge(label: widget.roleTag!, icon: widget.roleTag == 'Host' ? Icons.mic_external_on_rounded : Icons.verified_user_rounded, color: const Color(0xFFC99A3B)),
      if (widget.vipLevel > 0)
        MeProfileMiniBadge(label: widget.vipFrozen ? 'VIP ${widget.vipLevel} Frozen' : 'VIP ${widget.vipLevel}', icon: widget.vipFrozen ? Icons.lock_rounded : Icons.workspace_premium_rounded, color: widget.vipColor, onTap: widget.onVipTap),
      if (widget.svipLevel > 0)
        MeProfileMiniBadge(label: 'SVIP ${widget.svipLevel}', icon: Icons.auto_awesome_rounded, color: const Color(0xFFC99A3B), onTap: widget.onSvipTap),
      if (widget.familyName.trim().isNotEmpty)
        MeFamilyTagLight(familyName: widget.familyName, familyLevel: widget.familyLevel, onTap: widget.onFamilyTap),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final badges = _badgeLineItems();
    final coverPhotos = _coverPhotos;
    final hasCovers = coverPhotos.isNotEmpty;
    final safeCoverIndex = _coverIndex.clamp(0, hasCovers ? coverPhotos.length - 1 : 0);

    return Container(
      decoration: publicProfileWhitePanelDecoration(radius: 34),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              if (hasCovers)
                SizedBox(
                  height: 164,
                  child: PageView.builder(
                    controller: _coverController,
                    itemCount: coverPhotos.length,
                    onPageChanged: (index) => setState(() => _coverIndex = index),
                    itemBuilder: (context, index) => PublicCoverPhotoView(cover: coverPhotos[index]),
                  ),
                )
              else
                const SizedBox(height: 72),
              Positioned(
                right: 14,
                top: 14,
                child: Row(children: [PublicHeaderIconButton(icon: Icons.qr_code_rounded, onTap: widget.onQrTap), const SizedBox(width: 8), PublicHeaderIconButton(icon: Icons.edit_rounded, onTap: widget.onEditCoverPhotosTap)]),
              ),
              if (coverPhotos.length > 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      coverPhotos.length,
                      (index) => AnimatedContainer(duration: const Duration(milliseconds: 180), margin: const EdgeInsets.symmetric(horizontal: 3), width: index == safeCoverIndex ? 18 : 6, height: 6, decoration: BoxDecoration(color: Colors.white.withValues(alpha: index == safeCoverIndex ? 0.95 : 0.45), borderRadius: BorderRadius.circular(99))),
                    ),
                  ),
                ),
              Positioned(left: 18, bottom: -54, child: InkWell(onTap: widget.onAvatarTap, customBorder: const CircleBorder(), child: _MeCoverAvatar(displayName: widget.displayName))),
            ],
          ),
          const SizedBox(height: 62),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Flexible(child: Text(widget.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF251538), fontSize: 27, fontWeight: FontWeight.w900, letterSpacing: -0.6))),
                  if (_showOfficialTick) ...[const SizedBox(width: 5), const Icon(Icons.verified_rounded, color: Color(0xFFFFC857), size: 24)],
                ]),
                const SizedBox(height: 6),
                Text('ID ${widget.publicId}', style: const TextStyle(color: Color(0xFF8C7B8F), fontSize: 13, fontWeight: FontWeight.w800)),
                if (badges.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(height: 30, child: SingleChildScrollView(scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [for (var index = 0; index < badges.length; index++) ...[badges[index], if (index != badges.length - 1) const SizedBox(width: 8)]]))),
                ],
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  _PresenceChip(presence: widget.presence, lastSeenText: widget.lastSeenText),
                  if (widget.currentRoomName != null) InkWell(onTap: widget.onRoomTap, borderRadius: BorderRadius.circular(99), child: _RoomStatusChip(roomName: widget.currentRoomName!)),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _BalanceCapsule(label: 'Rubies', value: widget.diamonds, icon: Icons.diamond_rounded, color: const Color(0xFFE84C72), onTap: widget.onWalletTap)),
                  const SizedBox(width: 10),
                  Expanded(child: _BalanceCapsule(label: 'Coins', value: widget.coins, icon: Icons.monetization_on_rounded, color: const Color(0xFFC99A3B), onTap: widget.onWalletTap)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MeCoverAvatar extends StatelessWidget {
  const _MeCoverAvatar({required this.displayName});
  final String displayName;
  @override
  Widget build(BuildContext context) {
    final firstLetter = displayName.trim().isEmpty ? 'V' : displayName.trim()[0].toUpperCase();
    return Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 9))]), child: Container(width: 96, height: 96, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF6D5DF6), Color(0xFFE84C72), Color(0xFFFFD36A)])), child: Center(child: Text(firstLetter, style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900)))));
  }
}

class _PresenceChip extends StatelessWidget {
  const _PresenceChip({required this.presence, required this.lastSeenText});
  final MePresenceStatus presence;
  final String lastSeenText;
  @override
  Widget build(BuildContext context) {
    final isOnline = presence == MePresenceStatus.online;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8), decoration: BoxDecoration(color: const Color(0xFF12C7B7).withValues(alpha: 0.10), borderRadius: BorderRadius.circular(99)), child: Row(mainAxisSize: MainAxisSize.min, children: [Container(height: 9, width: 9, decoration: BoxDecoration(color: isOnline ? const Color(0xFF12C7B7) : const Color(0xFFB8B0C2), shape: BoxShape.circle)), const SizedBox(width: 7), Text(lastSeenText, style: const TextStyle(color: Color(0xFF251538), fontSize: 12, fontWeight: FontWeight.w900))]));
  }
}

class _RoomStatusChip extends StatelessWidget {
  const _RoomStatusChip({required this.roomName});
  final String roomName;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8), decoration: BoxDecoration(color: const Color(0xFF6D5DF6).withValues(alpha: 0.10), borderRadius: BorderRadius.circular(99)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.graphic_eq_rounded, color: Color(0xFF6D5DF6), size: 14), const SizedBox(width: 6), Text('In chatroom: $roomName', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF251538), fontSize: 11, fontWeight: FontWeight.w900))]));
}

class _BalanceCapsule extends StatelessWidget {
  const _BalanceCapsule({required this.label, required this.value, required this.icon, required this.color, required this.onTap});
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12), decoration: BoxDecoration(color: const Color(0xFFFAF7F1), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFECE2D8))), child: Row(children: [Icon(icon, color: color, size: 22), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF251538), fontSize: 17, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(color: Color(0xFF8C7B8F), fontSize: 11, fontWeight: FontWeight.w800))])), const Icon(Icons.chevron_right_rounded, color: Color(0xFFB8A8BD), size: 20)])));
}
