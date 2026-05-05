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
      padding: const EdgeInsets.all(16),
      decoration: meWhitePanelDecoration(radius: 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: onAvatarTap,
                customBorder: const CircleBorder(),
                child: MePremiumAvatar(
                  displayName: displayName,
                  vipColor: vipColor,
                  presence: presence,
                  showOpenIcon: true,
                  size: 78,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF251538),
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.45,
                            ),
                          ),
                        ),
                        if (_showOfficialTick) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified_rounded, color: Color(0xFFFFC857), size: 23),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'ID $publicId',
                      style: const TextStyle(
                        color: Color(0xFF8C7B8F),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (roleTag != null)
                          MeProfileMiniBadge(
                            label: roleTag!,
                            icon: roleTag == 'Host' ? Icons.mic_external_on_rounded : Icons.verified_user_rounded,
                            color: const Color(0xFFC99A3B),
                          ),
                        InkWell(
                          onTap: onVipTap,
                          borderRadius: BorderRadius.circular(99),
                          child: MeProfileMiniBadge(
                            label: vipFrozen ? 'VIP $vipLevel Frozen' : 'VIP $vipLevel',
                            icon: vipFrozen ? Icons.lock_rounded : Icons.workspace_premium_rounded,
                            color: vipColor,
                          ),
                        ),
                        InkWell(
                          onTap: onVipTap,
                          borderRadius: BorderRadius.circular(99),
                          child: MeProfileMiniBadge(
                            label: 'SVIP $svipLevel',
                            icon: Icons.auto_awesome_rounded,
                            color: const Color(0xFFC99A3B),
                          ),
                        ),
                        MeFamilyTagLight(
                          familyName: familyName,
                          familyLevel: familyLevel,
                          onTap: onFamilyTap,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: onQrTap,
                borderRadius: BorderRadius.circular(17),
                child: Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF7F1),
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: const Color(0xFFECE2D8)),
                  ),
                  child: const Icon(Icons.qr_code_rounded, color: Color(0xFF251538), size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _PresenceChip(presence: presence, lastSeenText: lastSeenText),
              if (currentRoomName != null)
                InkWell(
                  onTap: onRoomTap,
                  borderRadius: BorderRadius.circular(99),
                  child: _RoomStatusChip(roomName: currentRoomName!),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _BalanceCapsule(
                  label: 'Rubies',
                  value: diamonds,
                  icon: Icons.diamond_rounded,
                  color: const Color(0xFFE84C72),
                  onTap: onWalletTap,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BalanceCapsule(
                  label: 'Coins',
                  value: coins,
                  icon: Icons.monetization_on_rounded,
                  color: const Color(0xFFC99A3B),
                  onTap: onWalletTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool get _showOfficialTick {
    final normalized = role.toLowerCase().trim();
    return normalized == 'founder_owner' || normalized == 'super_owner' || normalized == 'owner';
  }
}

class _PresenceChip extends StatelessWidget {
  const _PresenceChip({required this.presence, required this.lastSeenText});

  final MePresenceStatus presence;
  final String lastSeenText;

  @override
  Widget build(BuildContext context) {
    final isOnline = presence == MePresenceStatus.online;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF12C7B7).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 9,
            width: 9,
            decoration: BoxDecoration(
              color: isOnline ? const Color(0xFF12C7B7) : const Color(0xFFB8B0C2),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            lastSeenText,
            style: const TextStyle(
              color: Color(0xFF251538),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomStatusChip extends StatelessWidget {
  const _RoomStatusChip({required this.roomName});

  final String roomName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF6D5DF6).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.graphic_eq_rounded, color: Color(0xFF6D5DF6), size: 14),
          const SizedBox(width: 6),
          Text(
            'In chatroom: $roomName',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF251538), fontSize: 11, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _BalanceCapsule extends StatelessWidget {
  const _BalanceCapsule({
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
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF7F1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFECE2D8)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF251538),
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF8C7B8F),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFB8A8BD), size: 20),
          ],
        ),
      ),
    );
  }
}
