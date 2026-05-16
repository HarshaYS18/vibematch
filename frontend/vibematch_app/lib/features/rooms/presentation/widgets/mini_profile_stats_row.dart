import 'package:flutter/material.dart';

import '../../data/mini_profile_economy_service.dart';
import '../live_room_models.dart';
import 'vip_badge.dart';

class MiniProfileStatsRow extends StatelessWidget {
  const MiniProfileStatsRow({
    super.key,
    required this.user,
    required this.onVipTap,
    required this.onSentRankingTap,
    required this.onReceivedRankingTap,
  });

  final SeatUser user;
  final VoidCallback onVipTap;
  final VoidCallback onSentRankingTap;
  final VoidCallback onReceivedRankingTap;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MiniProfileEconomySummary>(
      future: MiniProfileEconomyService.instance.summaryForSeatUser(user),
      builder: (context, snapshot) {
        final data =
            snapshot.data ?? MiniProfileEconomySummary.fromSeatUser(user);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: MiniProfileMonthStatCard(
                title: 'Sent',
                value: compactNumber(data.monthlyGiftCoinsSent),
                onTap: onSentRankingTap,
                tint: const Color(0xFFEFF7FF),
                borderColor: const Color(0xFFC8DEF3),
                titleColor: const Color(0xFF6B8198),
                valueColor: const Color(0xFF326B9E),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MiniProfileMonthStatCard(
                title: 'Received',
                value: compactNumber(data.monthlyGiftCoinsReceived),
                onTap: onReceivedRankingTap,
                tint: const Color(0xFFFFEEF5),
                borderColor: const Color(0xFFF3D3DF),
                titleColor: const Color(0xFF9A7483),
                valueColor: const Color(0xFFC45A80),
              ),
            ),
          ],
        );
      },
    );
  }
}

class MiniProfileVipStatCard extends StatelessWidget {
  const MiniProfileVipStatCard({
    super.key,
    required this.vipLevel,
    required this.onTap,
  });
  final int vipLevel;
  final VoidCallback onTap;

  Color get _accentColor {
    if (vipLevel >= 41) return const Color(0xFF9C3BCE);
    if (vipLevel >= 30) return const Color(0xFF0F9A5A);
    if (vipLevel >= 21) return const Color(0xFF0C78CF);
    if (vipLevel >= 11) return const Color(0xFFD33B47);
    if (vipLevel >= 6) return const Color(0xFFC99A3B);
    return const Color(0xFF89909A);
  }

  Color get _tintColor {
    if (vipLevel >= 41) return const Color(0xFFF5EBFF);
    if (vipLevel >= 30) return const Color(0xFFE8F8EF);
    if (vipLevel >= 21) return const Color(0xFFEAF4FF);
    if (vipLevel >= 11) return const Color(0xFFFFECEF);
    if (vipLevel >= 6) return const Color(0xFFFFF7E8);
    return const Color(0xFFF2F4F7);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _tintColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _accentColor.withValues(alpha: 0.22)),
          boxShadow: [
            BoxShadow(
              color: _accentColor.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              const _MiniProfileStatCardShine(),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'VIP Level',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFF7B7282),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: VipBadge(
                        level: vipLevel,
                        size: VipBadgeSize.small,
                        showWhenZero: false,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MiniProfileMonthStatCard extends StatelessWidget {
  const MiniProfileMonthStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.onTap,
    required this.tint,
    required this.borderColor,
    required this.titleColor,
    required this.valueColor,
  });
  final String title;
  final String value;
  final VoidCallback onTap;
  final Color tint;
  final Color borderColor;
  final Color titleColor;
  final Color valueColor;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: titleColor,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: valueColor,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniProfileStatCardShine extends StatelessWidget {
  const _MiniProfileStatCardShine();
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.28),
                  Colors.white.withValues(alpha: 0.10),
                  Colors.white.withValues(alpha: 0.00),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
