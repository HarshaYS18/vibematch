import 'package:flutter/material.dart';

import '../models/public_profile_models.dart';
import 'public_profile_shared_widgets.dart';

class PublicProfileHeader extends StatelessWidget {
  const PublicProfileHeader({
    super.key,
    required this.displayName,
    required this.username,
    required this.publicId,
    required this.roleTag,
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
    required this.onCoverChanged,
    required this.onBackTap,
    required this.onShareTap,
    required this.onAddCoverTap,
    required this.onFollowTap,
    required this.onMessageTap,
    required this.onRoomTap,
  });

  final String displayName;
  final String username;
  final String publicId;
  final String? roleTag;
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
  final ValueChanged<int> onCoverChanged;
  final VoidCallback onBackTap;
  final VoidCallback onShareTap;
  final VoidCallback onAddCoverTap;
  final VoidCallback onFollowTap;
  final VoidCallback onMessageTap;
  final VoidCallback onRoomTap;

  @override
  Widget build(BuildContext context) {
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
                child: PageView.builder(
                  controller: coverController,
                  itemCount: coverPhotos.length,
                  onPageChanged: onCoverChanged,
                  itemBuilder: (context, index) {
                    return PublicCoverPhotoView(cover: coverPhotos[index]);
                  },
                ),
              ),
              Positioned(
                left: 14,
                top: 14,
                child: PublicHeaderIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: onBackTap,
                ),
              ),
              Positioned(
                right: 14,
                top: 14,
                child: Row(
                  children: [
                    PublicHeaderIconButton(
                      icon: Icons.add_photo_alternate_rounded,
                      onTap: onAddCoverTap,
                    ),
                    const SizedBox(width: 8),
                    PublicHeaderIconButton(
                      icon: Icons.ios_share_rounded,
                      onTap: onShareTap,
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    coverPhotos.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: index == coverIndex ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: index == coverIndex ? 0.95 : 0.45,
                        ),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 18,
                bottom: -54,
                child: _PublicAvatar(displayName: displayName),
              ),
            ],
          ),
          const SizedBox(height: 62),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF251538),
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ),
                    if (showOfficialTick) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.verified_rounded,
                        color: Color(0xFFFFC857),
                        size: 24,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'ID $publicId',
                  style: const TextStyle(
                    color: Color(0xFF8C7B8F),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (roleTag != null)
                      PublicBadge(
                        icon: Icons.workspace_premium_rounded,
                        label: roleTag!,
                        color: const Color(0xFFFFD36A),
                      ),
                    PublicBadge(
                      icon: Icons.diamond_rounded,
                      label: 'VIP $vipLevel',
                      color: const Color(0xFFE84C72),
                    ),
                    PublicBadge(
                      icon: Icons.auto_awesome_rounded,
                      label: 'SVIP $svipLevel',
                      color: const Color(0xFF6D5DF6),
                    ),
                    PublicBadge(
                      icon: Icons.family_restroom_rounded,
                      label: '$familyName Lv.$familyLevel',
                      color: const Color(0xFF12C7B7),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _PresenceLine(
                  presenceLabel: presenceLabel,
                  currentRoomName: currentRoomName,
                  onRoomTap: onRoomTap,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: PublicMainProfileButton(
                        label: followStatus.label,
                        icon: followStatus.icon,
                        filled: true,
                        onTap: onFollowTap,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PublicMainProfileButton(
                        label: 'Message',
                        icon: Icons.chat_bubble_rounded,
                        filled: false,
                        onTap: onMessageTap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Expanded(child: PublicStat(value: '12.5K', label: 'Followers')),
                    SizedBox(width: 6),
                    Expanded(child: PublicStat(value: '864', label: 'Following')),
                    SizedBox(width: 6),
                    Expanded(child: PublicStat(value: '42', label: 'Rooms')),
                    SizedBox(width: 6),
                    Expanded(child: PublicStat(value: '3.6M', label: 'Received')),
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

class _PublicAvatar extends StatelessWidget {
  const _PublicAvatar({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    final firstLetter = displayName.trim().isEmpty ? 'V' : displayName.trim()[0].toUpperCase();

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF251538).withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Container(
        width: 96,
        height: 96,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6D5DF6),
              Color(0xFFE84C72),
              Color(0xFFFFD36A),
            ],
          ),
        ),
        child: Center(
          child: Text(
            firstLetter,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _PresenceLine extends StatelessWidget {
  const _PresenceLine({
    required this.presenceLabel,
    required this.currentRoomName,
    required this.onRoomTap,
  });

  final String presenceLabel;
  final String? currentRoomName;
  final VoidCallback onRoomTap;

  @override
  Widget build(BuildContext context) {
    final roomName = currentRoomName;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        PublicTinyStatusChip(
          icon: Icons.circle,
          label: presenceLabel,
          color: const Color(0xFF12C7B7),
        ),
        if (roomName != null)
          InkWell(
            onTap: onRoomTap,
            borderRadius: BorderRadius.circular(99),
            child: PublicTinyStatusChip(
              icon: Icons.graphic_eq_rounded,
              label: 'In chatroom: $roomName',
              color: const Color(0xFF6D5DF6),
            ),
          ),
      ],
    );
  }
}
