import 'package:flutter/material.dart';

import '../../../rooms/presentation/widgets/mini_profile_family_badge.dart';
import '../../../rooms/presentation/widgets/mini_profile_level_row.dart';
import '../../../rooms/presentation/widgets/vip_badge.dart';
import '../models/public_profile_models.dart';

BoxDecoration publicProfileWhitePanelDecoration({double radius = 28}) {
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

class PublicCoverPhotoView extends StatelessWidget {
  const PublicCoverPhotoView({super.key, required this.cover});

  final PublicCoverPhoto cover;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: cover.colors,
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: PublicCoverPatternPainter())),
          Positioned(
            right: 24,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
              ),
              child: Row(
                children: [
                  Icon(cover.icon, color: Colors.white, size: 18),
                  const SizedBox(width: 7),
                  Text(
                    cover.title,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PublicCoverPatternPainter extends CustomPainter {
  const PublicCoverPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (var i = -size.height; i < size.width; i += 18) {
      canvas.drawLine(Offset(i.toDouble(), size.height), Offset(i + size.height, 0), paint);
    }

    final circlePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.25), 46, circlePaint);
    canvas.drawCircle(Offset(size.width * 0.16, size.height * 0.76), 28, circlePaint);
  }

  @override
  bool shouldRepaint(covariant PublicCoverPatternPainter oldDelegate) => false;
}

class PublicHeaderIconButton extends StatelessWidget {
  const PublicHeaderIconButton({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.20),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, color: Colors.white, size: 21),
        ),
      ),
    );
  }
}

class PublicTinyStatusChip extends StatelessWidget {
  const PublicTinyStatusChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF251538), fontSize: 11, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class PublicBadge extends StatelessWidget {
  const PublicBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  int? _levelForPrefix(String prefix) {
    final clean = label.trim();
    if (!clean.startsWith('$prefix ')) return null;
    final parts = clean.split(' ');
    if (parts.length < 2) return null;
    return int.tryParse(parts[1]);
  }

  String get _familyTier {
    final parts = label.split('Lv.');
    final level = parts.length > 1 ? int.tryParse(parts.last.trim()) ?? 1 : 1;
    if (level >= 20) return 'platinum';
    if (level >= 10) return 'gold';
    if (level >= 5) return 'silver';
    return 'bronze';
  }

  bool get _isFamilyBadge {
    return icon == Icons.family_restroom_rounded || label.toLowerCase().contains('fam');
  }

  @override
  Widget build(BuildContext context) {
    final vipLevel = _levelForPrefix('VIP');
    if (vipLevel != null) {
      return VipBadge(
        level: vipLevel,
        size: VipBadgeSize.small,
        showWhenZero: true,
      );
    }

    final svipLevel = _levelForPrefix('SVIP');
    if (svipLevel != null) {
      return MiniProfileCleanLevelPill(
        label: 'SVIP $svipLevel',
        icon: Icons.diamond_rounded,
        width: 82,
        background: const Color(0xFF30220B),
        border: const Color(0xFFD7AA45),
        textColor: const Color(0xFFFFE2A1),
        shineColor: const Color(0xFFFFF1B8),
        active: svipLevel > 0,
        onTap: () {},
      );
    }

    if (_isFamilyBadge) {
      return MiniProfileFamilyBadge(
        familyName: label,
        familyLevel: _familyTier,
        onTap: () {},
        height: 24,
        minWidth: 88,
        maxWidth: 150,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
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

class PublicMainProfileButton extends StatelessWidget {
  const PublicMainProfileButton({
    super.key,
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: filled ? const Color(0xFF251538) : const Color(0xFFFAF7F1),
        foregroundColor: filled ? Colors.white : const Color(0xFF251538),
        side: BorderSide(color: filled ? const Color(0xFF251538) : const Color(0xFFECE2D8)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.symmetric(vertical: 13),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: filled ? Colors.white : const Color(0xFF251538)),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: filled ? Colors.white : const Color(0xFF251538),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class PublicStat extends StatelessWidget {
  const PublicStat({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFECE2D8)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(color: Color(0xFF251538), fontSize: 13, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF8C7B8F), fontSize: 10, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
