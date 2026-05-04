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
          const _SectionTitle('Today’s EXP'),
          const SizedBox(height: 10),
          RoomLevelDailyExpCards(snapshot: snapshot),
          const SizedBox(height: 18),
          const _SectionTitle('How room EXP works'),
          const SizedBox(height: 10),
          for (final rule in RoomLevelController.rules) ...[
            RoomLevelRuleCard(rule: rule),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
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
