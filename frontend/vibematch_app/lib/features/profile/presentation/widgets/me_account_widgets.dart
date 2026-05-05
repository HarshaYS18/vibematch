import 'package:flutter/material.dart';

import '../models/me_page_models.dart';
import 'me_shared_widgets.dart';

class MeVipSvipPanel extends StatelessWidget {
  const MeVipSvipPanel({
    super.key,
    required this.vipLevel,
    required this.svipLevel,
    required this.vipFrozen,
    required this.vipColor,
    required this.vipDark,
    required this.onVipTap,
    required this.onSvipTap,
  });

  final int vipLevel;
  final int svipLevel;
  final bool vipFrozen;
  final Color vipColor;
  final Color vipDark;
  final VoidCallback onVipTap;
  final VoidCallback onSvipTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _CompactLevelCard(
            title: 'VIP',
            levelText: 'VIP $vipLevel',
            subtitle: vipFrozen ? 'Frozen' : 'Active',
            icon: vipFrozen ? Icons.lock_rounded : Icons.workspace_premium_rounded,
            gradient: vipFrozen
                ? const [Color(0xFFAAA2B4), Color(0xFF6B6178)]
                : [vipDark, vipColor],
            onTap: onVipTap,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _CompactLevelCard(
            title: 'SVIP',
            levelText: 'SVIP $svipLevel',
            subtitle: 'Monthly status',
            icon: Icons.auto_awesome_rounded,
            gradient: const [Color(0xFF251538), Color(0xFFFFD36A)],
            onTap: onSvipTap,
          ),
        ),
      ],
    );
  }
}

class MeRelationshipPanel extends StatelessWidget {
  const MeRelationshipPanel({
    super.key,
    required this.relationshipLabel,
    required this.onSeeAllTap,
    required this.onCpTap,
    required this.onBestieTap,
    required this.onFamilyTap,
  });

  final String relationshipLabel;
  final VoidCallback onSeeAllTap;
  final VoidCallback onCpTap;
  final VoidCallback onBestieTap;
  final VoidCallback onFamilyTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: meWhitePanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Love & Bonds',
                  style: TextStyle(
                    color: Color(0xFF251538),
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              InkWell(
                onTap: onSeeAllTap,
                borderRadius: BorderRadius.circular(99),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF7F1),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: const Color(0xFFECE2D8)),
                  ),
                  child: const Text(
                    'See all',
                    style: TextStyle(
                      color: Color(0xFF251538),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: _BondCard(
                  title: 'CP',
                  name: 'Not linked',
                  value: 'Open',
                  icon: Icons.favorite_rounded,
                  colors: const [Color(0xFFE84C72), Color(0xFFFFD36A)],
                  onTap: onCpTap,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BondCard(
                  title: 'Bestie',
                  name: 'Aadhya',
                  value: 'Lv.8',
                  icon: Icons.handshake_rounded,
                  colors: const [Color(0xFF6D5DF6), Color(0xFF12C7B7)],
                  onTap: onBestieTap,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BondCard(
                  title: relationshipLabel,
                  name: 'Moon Fam',
                  value: 'Lv.12',
                  icon: Icons.family_restroom_rounded,
                  colors: const [Color(0xFF12C7B7), Color(0xFF064D46)],
                  onTap: onFamilyTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MeAccountCard extends StatelessWidget {
  const MeAccountCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  final MeActionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.97),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: meWhitePanelDecoration(radius: 24),
          child: Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(item.icon, color: item.color),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: Color(0xFF251538),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      style: const TextStyle(
                        color: Color(0xFF7A6B86),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Color(0xFF8C8198),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactLevelCard extends StatelessWidget {
  const _CompactLevelCard({
    required this.title,
    required this.levelText,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  final String title;
  final String levelText;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: gradient.last.withValues(alpha: 0.20),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    levelText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
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

class _BondCard extends StatelessWidget {
  const _BondCard({
    required this.title,
    required this.name,
    required this.value,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  final String title;
  final String name;
  final String value;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(height: 9),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.94),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.17),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
