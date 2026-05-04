import 'package:flutter/material.dart';

import '../controllers/room_level_controller.dart';
import '../widgets/room_level_components.dart';

class RoomLevelPage extends StatelessWidget {
  const RoomLevelPage({super.key});

  @override
  Widget build(BuildContext context) {
    final snapshot = RoomLevelController.mockSnapshot();
    final band = RoomLevelController.bandForLevel(snapshot.level);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7F1),
        foregroundColor: const Color(0xFF251538),
        elevation: 0,
        title: const Text(
          'Room Level',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          RoomLevelHeroCard(snapshot: snapshot, band: band),
          const SizedBox(height: 16),
          const _SectionTitle('How room EXP works'),
          const SizedBox(height: 10),
          for (final rule in RoomLevelController.rules) ...[
            RoomLevelRuleCard(rule: rule),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
          const RoomLevelExpExampleCard(),
          const SizedBox(height: 18),
          const _SectionTitle('Level badge gradient bands'),
          const SizedBox(height: 10),
          SizedBox(
            height: 178,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: RoomLevelController.bands.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                return RoomLevelBandCard(band: RoomLevelController.bands[index]);
              },
            ),
          ),
          const SizedBox(height: 18),
          const _SectionTitle('Difficulty nature'),
          const SizedBox(height: 10),
          const _DifficultyCard(),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF251538),
        fontSize: 17,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.2,
      ),
    );
  }
}

class _DifficultyCard extends StatelessWidget {
  const _DifficultyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFECE2D8)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DifficultyLine(
            title: 'Levels 1-10',
            body: 'Very easy. New rooms can level quickly through basic activity.',
          ),
          _DifficultyLine(
            title: 'Levels 11-50',
            body: 'Steady grind. Each level asks for stronger stay activity and gift economy.',
          ),
          _DifficultyLine(
            title: 'Levels 51-70',
            body: 'Major jump. Each level feels like 1-20 earlier levels of effort.',
          ),
          _DifficultyLine(
            title: 'Levels 71-100',
            body: 'Insane prestige range. Only long-running rich rooms should reach this range.',
            last: true,
          ),
        ],
      ),
    );
  }
}

class _DifficultyLine extends StatelessWidget {
  const _DifficultyLine({
    required this.title,
    required this.body,
    this.last = false,
  });

  final String title;
  final String body;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5),
            decoration: const BoxDecoration(
              color: Color(0xFFC99A3B),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF251538),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(
                    color: Color(0xFF7B6A86),
                    fontSize: 11.4,
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
