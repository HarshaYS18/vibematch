import 'package:flutter/material.dart';

import '../../../rooms/presentation/widgets/mini_profile_family_badge.dart';
import '../../../rooms/presentation/widgets/mini_profile_level_row.dart';
import '../../../rooms/presentation/widgets/vip_badge.dart';
import '../models/me_page_models.dart';

BoxDecoration meWhitePanelDecoration({double radius = 28}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: const Color(0xFFECE2D8)),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF251538).withValues(alpha: 0.045),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

String meFamilyTierFromLevel(int level) {
  if (level >= 20) return 'platinum';
  if (level >= 10) return 'gold';
  if (level >= 5) return 'silver';
  return 'bronze';
}

class MePremiumAvatar extends StatelessWidget {
  const MePremiumAvatar({
    super.key,
    required this.displayName,
    required this.vipColor,
    required this.presence,
    required this.showOpenIcon,
    required this.size,
  });

  final String displayName;
  final Color vipColor;
  final MePresenceStatus presence;
  final bool showOpenIcon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isOnline = presence == MePresenceStatus.online;
    final letter = displayName.trim().isEmpty ? 'V' : displayName.trim()[0].toUpperCase();

    return Container(
      height: size,
      width: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Colors.white, vipColor, const Color(0xFFFFD36A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF251538),
              border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
            ),
            child: Center(
              child: Text(
                letter,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.41,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          Positioned(
            right: size * 0.02,
            bottom: size * 0.02,
            child: Container(
              height: size * 0.25,
              width: size * 0.25,
              decoration: BoxDecoration(
                color: isOnline ? const Color(0xFF12C7B7) : const Color(0xFF8C8198),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.3),
              ),
            ),
          ),
          if (showOpenIcon)
            Positioned(
              left: size * 0.02,
              bottom: size * 0.02,
              child: Container(
                height: size * 0.25,
                width: size * 0.25,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: vipColor, width: 1.5),
                ),
                child: const Icon(Icons.open_in_new_rounded, color: Color(0xFF251538), size: 13),
              ),
            ),
        ],
      ),
    );
  }
}

class MeNameWithOfficialTick extends StatelessWidget {
  const MeNameWithOfficialTick({
    super.key,
    required this.displayName,
    required this.role,
    required this.fontSize,
    required this.letterSpacing,
    required this.centered,
  });

  final String displayName;
  final String role;
  final double fontSize;
  final double letterSpacing;
  final bool centered;

  bool get _showTick {
    final normalized = role.toLowerCase().trim();
    return normalized == 'founder_owner' || normalized == 'super_owner' || normalized == 'owner';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: centered ? MainAxisAlignment.center : MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: letterSpacing,
            ),
          ),
        ),
        if (_showTick) ...[
          const SizedBox(width: 5),
          const Icon(Icons.verified_rounded, color: Color(0xFFFFD36A), size: 21),
        ],
      ],
    );
  }
}

class MeFamilyTagLight extends StatelessWidget {
  const MeFamilyTagLight({
    super.key,
    required this.familyName,
    required this.familyLevel,
    required this.onTap,
  });

  final String familyName;
  final int familyLevel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MiniProfileFamilyBadge(
      familyName: '$familyName Lv.$familyLevel',
      familyLevel: meFamilyTierFromLevel(familyLevel),
      onTap: onTap,
      height: 26,
      minWidth: 92,
      maxWidth: 152,
    );
  }
}

class MeProfileMiniBadge extends StatelessWidget {
  const MeProfileMiniBadge({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  int? _levelForPrefix(String prefix) {
    final parts = label.split(' ');
    if (parts.isEmpty || parts.first.toUpperCase() != prefix) return null;
    return parts.length > 1 ? int.tryParse(parts[1]) : null;
  }

  @override
  Widget build(BuildContext context) {
    final vipLevel = _levelForPrefix('VIP');
    if (vipLevel != null) {
      return SizedBox(
        height: 28,
        child: Center(
          child: VipBadge(level: vipLevel, size: VipBadgeSize.small, showWhenZero: true),
        ),
      );
    }

    final svipLevel = _levelForPrefix('SVIP');
    if (svipLevel != null) {
      return SizedBox(
        height: 28,
        child: Center(
          child: MiniProfileCleanLevelPill(
            label: 'SVIP $svipLevel',
            icon: Icons.diamond_rounded,
            width: 86,
            background: const Color(0xFF30220B),
            border: const Color(0xFFD7AA45),
            textColor: const Color(0xFFFFE2A1),
            shineColor: const Color(0xFFFFF1B8),
            active: svipLevel > 0,
            onTap: () {},
          ),
        ),
      );
    }

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF251538), fontSize: 11, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class MeHeaderIconButton extends StatelessWidget {
  const MeHeaderIconButton({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 44,
        width: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class MeProfileStat extends StatelessWidget {
  const MeProfileStat({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: meWhitePanelDecoration(radius: 24),
          child: Column(
            children: [
              Icon(icon, color: const Color(0xFF6D5DF6), size: 20),
              const SizedBox(height: 5),
              Text(value, style: const TextStyle(color: Color(0xFF251538), fontWeight: FontWeight.w900, fontSize: 17)),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(color: Color(0xFF8C8198), fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
