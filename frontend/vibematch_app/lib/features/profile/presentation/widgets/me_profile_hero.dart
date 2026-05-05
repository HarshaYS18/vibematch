import 'package:flutter/material.dart';

import '../models/me_page_models.dart';
import 'me_shared_widgets.dart';

class MePremiumProfileHero extends StatelessWidget {
  const MePremiumProfileHero({
    super.key,
    required this.displayName,
    required this.publicId,
    required this.role,
    required this.roleTag,
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
    required this.onFamilyTap,
    required this.onAvatarTap,
    required this.onQrTap,
    required this.onWalletTap,
    required this.onVipTap,
    required this.onRoomTap,
  });

  final String displayName;
  final String publicId;
  final String role;
  final String? roleTag;
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
  final VoidCallback onFamilyTap;
  final VoidCallback onAvatarTap;
  final VoidCallback onQrTap;
  final VoidCallback onWalletTap;
  final VoidCallback onVipTap;
  final VoidCallback onRoomTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: vipDark,
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: vipColor.withValues(alpha: 0.24),
            blurRadius: 34,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -70,
            top: -70,
            child: Container(
              height: 190,
              width: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: vipColor.withValues(alpha: 0.20),
              ),
            ),
          ),
          Positioned(
            left: -48,
            bottom: -56,
            child: Container(
              height: 150,
              width: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            right: 18,
            bottom: 16,
            child: Icon(
              Icons.diamond_rounded,
              color: Colors.white.withValues(alpha: 0.09),
              size: 96,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: InkWell(
                        onTap: onAvatarTap,
                        customBorder: const CircleBorder(),
                        child: MePremiumAvatar(
                          displayName: displayName,
                          vipColor: vipColor,
                          presence: presence,
                          showOpenIcon: true,
                          size: 82,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MeNameWithOfficialTick(
                            displayName: displayName,
                            role: role,
                            fontSize: 23,
                            letterSpacing: -0.4,
                            centered: false,
                          ),
                          const SizedBox(height: 6),
                          MeFamilyTagLight(
                            familyName: familyName,
                            familyLevel: familyLevel,
                            onTap: onFamilyTap,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'ID $publicId',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 7),
                          _PresenceTextLight(
                            presence: presence,
                            lastSeenText: lastSeenText,
                          ),
                          if (currentRoomName != null) ...[
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: onRoomTap,
                              borderRadius: BorderRadius.circular(99),
                              child: _RoomStatusTextLight(roomName: currentRoomName!),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: [
                              if (roleTag != null)
                                MeProfileMiniBadge(
                                  label: roleTag!,
                                  icon: roleTag == 'Host'
                                      ? Icons.mic_external_on_rounded
                                      : Icons.verified_user_rounded,
                                  color: const Color(0xFFFFD36A),
                                ),
                              MeProfileMiniBadge(
                                label: vipFrozen ? 'VIP $vipLevel Frozen' : 'VIP $vipLevel',
                                icon: vipFrozen ? Icons.lock_rounded : Icons.workspace_premium_rounded,
                                color: vipColor,
                              ),
                              MeProfileMiniBadge(
                                label: 'SVIP $svipLevel',
                                icon: Icons.auto_awesome_rounded,
                                color: const Color(0xFFFFD36A),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: onQrTap,
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                        ),
                        child: const Icon(Icons.qr_code_rounded, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _HeroWalletTile(
                        label: 'Diamonds',
                        value: diamonds,
                        icon: Icons.diamond_rounded,
                        color: const Color(0xFF55B7FF),
                        onTap: onWalletTap,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HeroWalletTile(
                        label: 'Coins',
                        value: coins,
                        icon: Icons.monetization_on_rounded,
                        color: const Color(0xFFFFD36A),
                        onTap: onWalletTap,
                      ),
                    ),
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

class _PresenceTextLight extends StatelessWidget {
  const _PresenceTextLight({required this.presence, required this.lastSeenText});

  final MePresenceStatus presence;
  final String lastSeenText;

  @override
  Widget build(BuildContext context) {
    final isOnline = presence == MePresenceStatus.online;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 8,
          width: 8,
          decoration: BoxDecoration(
            color: isOnline ? const Color(0xFF12C7B7) : const Color(0xFFB8B0C2),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 7),
        Text(
          lastSeenText,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.80),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _RoomStatusTextLight extends StatelessWidget {
  const _RoomStatusTextLight({required this.roomName});

  final String roomName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF12C7B7).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0xFF12C7B7).withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.graphic_eq_rounded, color: Color(0xFF12C7B7), size: 14),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              'In chatroom: $roomName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroWalletTile extends StatelessWidget {
  const _HeroWalletTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 23),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.70),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
