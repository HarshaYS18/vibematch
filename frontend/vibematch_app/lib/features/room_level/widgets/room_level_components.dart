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

class RoomLevelExpExampleCard extends StatelessWidget {
  const RoomLevelExpExampleCard({super.key});

  @override
  Widget build(BuildContext context) {
    final stayExp = RoomLevelController.stayExpForMinutes(30);
    final giftExp = RoomLevelController.giftExpForCoins(10000);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9EE),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF2DEB8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'EXP example',
            style: TextStyle(
              color: Color(0xFF251538),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          _ExampleLine(label: '30 min seated stay', value: '+$stayExp EXP'),
          _ExampleLine(label: '10,000 gift coins spent', value: '+$giftExp EXP'),
          const SizedBox(height: 6),
          const Text(
            'Backend later: daily stay EXP must be capped per user per room per day. Gift EXP should come only from confirmed wallet-ledger gift spend.',
            style: TextStyle(
              color: Color(0xFF7B6A86),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExampleLine extends StatelessWidget {
  const _ExampleLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF7B6A86),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFC99A3B),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
