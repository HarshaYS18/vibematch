import 'package:flutter/material.dart';

import '../controllers/room_level_controller.dart';
import '../models/room_level_models.dart';
import 'room_level_gradient_pill.dart';

class RoomLevelHeroCard extends StatelessWidget {
  const RoomLevelHeroCard({
    super.key,
    required this.snapshot,
    required this.band,
  });

  final RoomLevelSnapshot snapshot;
  final RoomLevelBand band;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: band.colors),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: band.colors.last.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Room Level',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      band.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ],
                ),
              ),
              RoomLevelGradientPill(
                level: snapshot.level,
                label: band.name,
                colors: [Colors.white.withValues(alpha: 0.26), Colors.white.withValues(alpha: 0.12)],
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: snapshot.progress,
              minHeight: 12,
              backgroundColor: Colors.white.withValues(alpha: 0.20),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${snapshot.currentLevelExp} / ${snapshot.nextLevelRequiredExp} EXP',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${snapshot.remainingExp} left',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.86),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            band.description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class RoomLevelRuleCard extends StatelessWidget {
  const RoomLevelRuleCard({super.key, required this.rule});

  final RoomLevelRule rule;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFECE2D8)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: rule.colors),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(rule.icon, color: Colors.white, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule.title,
                  style: const TextStyle(
                    color: Color(0xFF251538),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rule.description,
                  style: const TextStyle(
                    color: Color(0xFF7B6A86),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RoomLevelDailyExpCards extends StatelessWidget {
  const RoomLevelDailyExpCards({super.key, required this.snapshot});

  final RoomLevelSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RoomLevelExpProgressCard(
          title: 'Daily stay EXP',
          subtitle: '${snapshot.dailyStayMinutes} seated minutes today',
          valueLabel: '${snapshot.dailyStayExp} / ${RoomLevelController.maxDailyStayExp} EXP',
          progress: snapshot.dailyStayExp / RoomLevelController.maxDailyStayExp,
          icon: Icons.timer_rounded,
          colors: const [Color(0xFF12C7B7), Color(0xFF5E6DFF)],
          note: 'Stay EXP is capped at 10,000 per room per day.',
        ),
        const SizedBox(height: 10),
        RoomLevelExpProgressCard(
          title: 'Gift EXP',
          subtitle: '10 gift coins = 1 EXP',
          valueLabel: '${snapshot.giftCoinExp} / ∞ EXP',
          progress: null,
          icon: Icons.card_giftcard_rounded,
          colors: const [Color(0xFFE84C72), Color(0xFFFFB45E)],
          note: 'Gift EXP has no daily cap. The bar stays open-ended.',
        ),
      ],
    );
  }
}

class RoomLevelExpProgressCard extends StatelessWidget {
  const RoomLevelExpProgressCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.valueLabel,
    required this.progress,
    required this.icon,
    required this.colors,
    required this.note,
  });

  final String title;
  final String subtitle;
  final String valueLabel;
  final double? progress;
  final IconData icon;
  final List<Color> colors;
  final String note;

  @override
  Widget build(BuildContext context) {
    final safeProgress = progress?.clamp(0.0, 1.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFECE2D8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF251538),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF7B6A86),
                        fontSize: 11.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                valueLabel,
                style: const TextStyle(
                  color: Color(0xFF251538),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: [
                Container(
                  height: 11,
                  decoration: const BoxDecoration(color: Color(0xFFEDE3D7)),
                ),
                if (safeProgress == null)
                  Container(
                    height: 11,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: colors),
                    ),
                  )
                else
                  FractionallySizedBox(
                    widthFactor: safeProgress,
                    child: Container(
                      height: 11,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: colors),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            note,
            style: const TextStyle(
              color: Color(0xFF7B6A86),
              fontSize: 10.8,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class RoomLevelBandCard extends StatelessWidget {
  const RoomLevelBandCard({super.key, required this.band});

  final RoomLevelBand band;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFECE2D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RoomLevelGradientPill(
            level: band.startLevel,
            label: '${band.startLevel}-${band.endLevel}',
            colors: band.colors,
            compact: true,
          ),
          const SizedBox(height: 12),
          Text(
            band.name,
            style: const TextStyle(
              color: Color(0xFF251538),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Levels ${band.startLevel}-${band.endLevel}',
            style: const TextStyle(
              color: Color(0xFF7B6A86),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            band.description,
            style: const TextStyle(
              color: Color(0xFF7B6A86),
              fontSize: 11.2,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}
