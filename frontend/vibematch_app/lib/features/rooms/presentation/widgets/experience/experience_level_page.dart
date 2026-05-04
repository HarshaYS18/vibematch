import 'package:flutter/material.dart';

import '../../controllers/experience_level_controller.dart';
import '../../live_room_models.dart';
import '../economy/gold_coin_icon.dart';
import '../room_theme.dart';
import 'experience_level_models.dart';
import 'experience_level_pill.dart';

class ExperienceLevelPage extends StatelessWidget {
  const ExperienceLevelPage({
    super.key,
    required this.user,
    required this.type,
  });

  final SeatUser user;
  final ExperienceLevelType type;

  @override
  Widget build(BuildContext context) {
    const controller = ExperienceLevelController();
    final totalExp = type == ExperienceLevelType.sent ? user.sentExp : user.receivedExp;
    final progress = controller.progressForTotalExp(totalExp);
    final level = progress.level;
    final style = experiencePillStyleFor(type: type, level: level);
    final todayTimeExp = type == ExperienceLevelType.sent ? controller.timeSpentExpForMinutes(120) : 0;
    final todayCoinExp = type == ExperienceLevelType.sent
        ? controller.sentGiftExpForCoins(1200) + controller.storePurchaseExpForCoins(800)
        : controller.receivedGiftExpForCoins(1600);
    final todayTotalExp = todayTimeExp + todayCoinExp;
    final backendPath = controller.backendPath(type: type, userId: user.id);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: RoomColors.plum,
        title: Text(type.title, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: user.isCurrentUser
          ? ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _ExperienceHeroCard(
                  user: user,
                  type: type,
                  progress: progress,
                  todayTotalExp: todayTotalExp,
                  style: style,
                ),
                const SizedBox(height: 14),
                _ExperienceRulesCard(type: type),
                const SizedBox(height: 12),
                _ExperienceMetricGrid(
                  type: type,
                  totalExp: totalExp,
                  level: level,
                  timeExp: todayTimeExp,
                  coinExp: todayCoinExp,
                  todayTotalExp: todayTotalExp,
                  expNeededForCurrentLevel: progress.expNeededForNextLevel,
                ),
                const SizedBox(height: 12),
                Text(
                  'Backend later: GET $backendPath',
                  style: const TextStyle(color: Color(0xFF8B7B98), fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ],
            )
          : _PrivateExperienceState(type: type),
    );
  }
}

class _ExperienceHeroCard extends StatelessWidget {
  const _ExperienceHeroCard({
    required this.user,
    required this.type,
    required this.progress,
    required this.todayTotalExp,
    required this.style,
  });

  final SeatUser user;
  final ExperienceLevelType type;
  final ExperienceLevelProgress progress;
  final int todayTotalExp;
  final ExperiencePillStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: style.gradient,
        ),
        boxShadow: [
          BoxShadow(color: style.glowColor.withValues(alpha: 0.26), blurRadius: 24, offset: const Offset(0, 12)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              right: -34,
              top: -34,
              child: Icon(style.crownIcon, color: Colors.white.withValues(alpha: 0.10), size: 142),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: user.avatarColors)),
                      child: Text(avatarLetter(user.name), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 5),
                          ExperienceLevelPill(type: type, level: progress.level),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  progress.isMaxLevel
                      ? 'Max level reached · ${compactNumber(progress.totalExp)} lifetime EXP'
                      : '${compactNumber(progress.expIntoLevel)} / ${compactNumber(progress.expNeededForNextLevel)} EXP to finish Lv ${progress.level}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.90), fontSize: 12.5, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                _LevelProgressBar(style: style, value: progress.progress.clamp(0, 1)),
                const SizedBox(height: 10),
                Text(
                  'Today +${compactNumber(todayTotalExp)} EXP · Tier ${style.tier.label}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 11.5, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelProgressBar extends StatelessWidget {
  const _LevelProgressBar({required this.style, required this.value});

  final ExperiencePillStyle style;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 12,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Stack(
          children: [
            FractionallySizedBox(
              widthFactor: value,
              alignment: Alignment.centerLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [style.crownColor, style.glowColor, Colors.white.withValues(alpha: 0.92)],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.0),
                      Colors.white.withValues(alpha: 0.34),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                    stops: const [0.18, 0.5, 0.82],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivateExperienceState extends StatelessWidget {
  const _PrivateExperienceState({required this.type});

  final ExperienceLevelType type;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: RoomColors.softLine),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_rounded, color: type == ExperienceLevelType.sent ? const Color(0xFF0E6CFF) : const Color(0xFFFF4F93), size: 34),
              const SizedBox(height: 10),
              Text(
                '${type.shortLabel} EXP details are private',
                textAlign: TextAlign.center,
                style: const TextStyle(color: RoomColors.plum, fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'Detailed Sent and Received EXP pages are shown only on your own profile.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF7B6A86), fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.25),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExperienceRulesCard extends StatelessWidget {
  const _ExperienceRulesCard({required this.type});

  final ExperienceLevelType type;

  @override
  Widget build(BuildContext context) {
    final isSent = type == ExperienceLevelType.sent;
    return _ExpCard(
      title: 'Level-up rules',
      icon: Icons.rule_rounded,
      children: [
        if (isSent) ...[
          const _RuleRow(icon: Icons.schedule_rounded, text: 'Time spent: 20 EXP every 5 minutes'),
          const _RuleRow(icon: Icons.lock_clock_rounded, text: 'Time-spent EXP max: 800 EXP per day'),
          const _RuleRow(icon: Icons.card_giftcard_rounded, text: 'Gift sent: every 20 coins = 2 EXP'),
          const _RuleRow(icon: Icons.storefront_rounded, text: 'Store purchases: every 20 coins = 2 EXP'),
          const _RuleRow(icon: Icons.all_inclusive_rounded, text: 'Coin-related EXP has no daily limit'),
        ] else ...[
          const _RuleRow(icon: Icons.card_giftcard_rounded, text: 'Gift received: every 20 coins = 2 EXP'),
          const _RuleRow(icon: Icons.all_inclusive_rounded, text: 'Receive EXP has no daily limit'),
        ],
      ],
    );
  }
}

class _ExperienceMetricGrid extends StatelessWidget {
  const _ExperienceMetricGrid({
    required this.type,
    required this.totalExp,
    required this.level,
    required this.timeExp,
    required this.coinExp,
    required this.todayTotalExp,
    required this.expNeededForCurrentLevel,
  });

  final ExperienceLevelType type;
  final int totalExp;
  final int level;
  final int timeExp;
  final int coinExp;
  final int todayTotalExp;
  final int expNeededForCurrentLevel;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.45,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: [
        _MetricTile(title: 'Current level', value: 'Lv $level', icon: type.baseIcon),
        _MetricTile(title: 'EXP for this level', value: compactNumber(expNeededForCurrentLevel), icon: Icons.flag_rounded),
        _MetricTile(title: 'Today EXP', value: compactNumber(todayTotalExp), icon: Icons.today_rounded),
        if (type == ExperienceLevelType.sent)
          _MetricTile(title: 'Today time EXP', value: '$timeExp / 800', icon: Icons.schedule_rounded)
        else
          _MetricTile(title: 'Gift receive EXP', value: compactNumber(coinExp), iconWidget: const GoldCoinIcon(size: 18)),
      ],
    );
  }
}

class _ExpCard extends StatelessWidget {
  const _ExpCard({required this.title, required this.icon, required this.children});

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: RoomColors.softLine),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: RoomColors.violet, size: 19),
              const SizedBox(width: 7),
              Text(title, style: const TextStyle(color: RoomColors.plum, fontSize: 14, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: RoomColors.gold, size: 17),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: Color(0xFF6F627A), fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.25))),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.title, required this.value, this.icon, this.iconWidget});

  final String title;
  final String value;
  final IconData? icon;
  final Widget? iconWidget;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RoomColors.softLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          iconWidget ?? Icon(icon, color: RoomColors.violet, size: 20),
          const SizedBox(height: 8),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: RoomColors.plum, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
