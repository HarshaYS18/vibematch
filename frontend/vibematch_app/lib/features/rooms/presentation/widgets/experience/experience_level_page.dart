import 'package:flutter/material.dart';

import '../../controllers/experience_level_controller.dart';
import '../../live_room_models.dart';
import '../economy/gold_coin_icon.dart';
import '../room_theme.dart';
import 'experience_level_models.dart';
import 'experience_level_pill.dart';

class ExperienceLevelPage extends StatefulWidget {
  const ExperienceLevelPage({
    super.key,
    required this.user,
    required this.type,
  });

  final SeatUser user;
  final ExperienceLevelType type;

  @override
  State<ExperienceLevelPage> createState() => _ExperienceLevelPageState();
}

class _ExperienceLevelPageState extends State<ExperienceLevelPage> {
  int _selectedPeriod = 0;

  void _switchType(ExperienceLevelType type) {
    if (type == widget.type) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ExperienceLevelPage(user: widget.user, type: type),
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF251538),
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    const controller = ExperienceLevelController();
    final user = widget.user;
    final type = widget.type;
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

    if (!user.isCurrentUser) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAF7F1),
        body: SafeArea(
          child: Column(
            children: [
              _LevelRankingHeader(
                selectedType: type,
                onBack: () => Navigator.pop(context),
                onHelp: () => _toast('${type.shortLabel} level rules will open here.'),
                onTypeSelected: _switchType,
              ),
              Expanded(child: _PrivateExperienceState(type: type)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _LevelRankingHeader(
                  selectedType: type,
                  onBack: () => Navigator.pop(context),
                  onHelp: () => _toast('${type.shortLabel} level rules will open here.'),
                  onTypeSelected: _switchType,
                ),
                _PeriodSwitch(
                  selectedIndex: _selectedPeriod,
                  onSelected: (index) => setState(() => _selectedPeriod = index),
                ),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 130),
                    children: [
                      _GoldRankingHero(
                        type: type,
                        periodLabel: _selectedPeriod == 0 ? 'Daily' : 'Monthly',
                        onRewardsTap: () => _toast('${type.shortLabel} ranking rewards will connect later.'),
                      ),
                      _TopThreeRanking(
                        type: type,
                        currentUser: user,
                        currentLevel: level,
                      ),
                      _RankingListCard(type: type),
                      const SizedBox(height: 12),
                      _ExperienceHeroCard(
                        user: user,
                        type: type,
                        progress: progress,
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
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _MyLevelRankBar(
                user: user,
                type: type,
                level: level,
                totalExp: totalExp,
                onAction: () => _toast('Unfreeze / boost flow will connect later.'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelRankingHeader extends StatelessWidget {
  const _LevelRankingHeader({
    required this.selectedType,
    required this.onBack,
    required this.onHelp,
    required this.onTypeSelected,
  });

  final ExperienceLevelType selectedType;
  final VoidCallback onBack;
  final VoidCallback onHelp;
  final ValueChanged<ExperienceLevelType> onTypeSelected;

  @override
  Widget build(BuildContext context) {
    final tabs = <ExperienceLevelType>[ExperienceLevelType.sent, ExperienceLevelType.received];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 10, 12, 14),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111111), size: 31),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: tabs.map((type) {
                final selected = type == selectedType;
                return InkWell(
                  onTap: () => onTypeSelected(type),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${type.shortLabel} Ranking',
                          style: TextStyle(
                            color: selected ? const Color(0xFF111111) : const Color(0xFF9A9A9A),
                            fontSize: 18,
                            fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                            letterSpacing: -0.35,
                          ),
                        ),
                        const SizedBox(height: 7),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          height: 4,
                          width: selected ? 34 : 0,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE100),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onHelp,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(color: Color(0xFF4A4A4A), shape: BoxShape.circle),
              child: const Icon(Icons.question_mark_rounded, color: Colors.white, size: 27),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodSwitch extends StatelessWidget {
  const _PeriodSwitch({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const periods = ['Daily', 'Monthly'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Container(
        height: 58,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: const Color(0xFFE9E9EB), borderRadius: BorderRadius.circular(999)),
        child: Row(
          children: List.generate(periods.length, (index) {
            final selected = index == selectedIndex;
            return Expanded(
              child: InkWell(
                onTap: () => onSelected(index),
                borderRadius: BorderRadius.circular(999),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: selected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))] : null,
                  ),
                  child: Center(
                    child: Text(
                      periods[index],
                      style: TextStyle(
                        color: selected ? const Color(0xFF111111) : const Color(0xFF9A9A9A),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _GoldRankingHero extends StatelessWidget {
  const _GoldRankingHero({required this.type, required this.periodLabel, required this.onRewardsTap});

  final ExperienceLevelType type;
  final String periodLabel;
  final VoidCallback onRewardsTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFF4C6), Color(0xFFFFD67A)]),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _GoldLinesPainter())),
          Positioned(
            top: 32,
            left: 0,
            right: 0,
            child: Text(
              'Settlement time 00 days 21:54:45',
              textAlign: TextAlign.center,
              style: TextStyle(color: const Color(0xFF6F5530).withValues(alpha: 0.92), fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
          Positioned(
            top: 18,
            right: 0,
            child: InkWell(
              onTap: onRewardsTap,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(999)),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 16, 10),
                decoration: const BoxDecoration(color: Color(0xFFFFA800), borderRadius: BorderRadius.horizontal(left: Radius.circular(999))),
                child: const Row(
                  children: [
                    Text('🎁', style: TextStyle(fontSize: 24)),
                    SizedBox(width: 5),
                    Text('Rewards', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 82,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const _WingedShield(),
                const SizedBox(height: 6),
                Text(
                  '$periodLabel · ${type.shortLabel} Level Ranking',
                  style: TextStyle(color: const Color(0xFF7A5922).withValues(alpha: 0.72), fontSize: 12, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopThreeRanking extends StatelessWidget {
  const _TopThreeRanking({required this.type, required this.currentUser, required this.currentLevel});

  final ExperienceLevelType type;
  final SeatUser currentUser;
  final int currentLevel;

  List<_RankUser> get _users => [
        _RankUser(rank: 1, name: currentUser.name, avatarText: avatarLetter(currentUser.name), score: 'Lv $currentLevel', colors: currentUser.avatarColors),
        _RankUser(rank: 2, name: type == ExperienceLevelType.sent ? 'Moon Sender' : 'Gift Queen', avatarText: 'M', score: 'Lv ${currentLevel > 3 ? currentLevel - 2 : currentLevel}', colors: const [Color(0xFFB7D4FF), Color(0xFFE9F4FF)]),
        _RankUser(rank: 3, name: type == ExperienceLevelType.sent ? 'Akhil Voice' : 'Riya Music', avatarText: type == ExperienceLevelType.sent ? 'A' : 'R', score: 'Lv ${currentLevel > 5 ? currentLevel - 4 : currentLevel}', colors: const [Color(0xFFE7C8B9), Color(0xFFFFEFE8)]),
      ];

  @override
  Widget build(BuildContext context) {
    final first = _users.firstWhere((user) => user.rank == 1);
    final second = _users.firstWhere((user) => user.rank == 2);
    final third = _users.firstWhere((user) => user.rank == 3);

    return Transform.translate(
      offset: const Offset(0, -34),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _PodiumCard(user: second, height: 210, crownColor: const Color(0xFF9FC6FF))),
          Expanded(child: _PodiumCard(user: first, height: 244, crownColor: const Color(0xFFE0A623), isCenter: true)),
          Expanded(child: _PodiumCard(user: third, height: 210, crownColor: const Color(0xFFC9A795))),
        ],
      ),
    );
  }
}

class _PodiumCard extends StatelessWidget {
  const _PodiumCard({required this.user, required this.height, required this.crownColor, this.isCenter = false});

  final _RankUser user;
  final double height;
  final Color crownColor;
  final bool isCenter;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: EdgeInsets.fromLTRB(10, isCenter ? 12 : 18, 10, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(isCenter ? 18 : 14)),
        border: Border.all(color: const Color(0xFFE8C77C).withValues(alpha: 0.44)),
        boxShadow: [BoxShadow(color: const Color(0xFFB1781E).withValues(alpha: 0.11), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Icon(Icons.workspace_premium_rounded, color: crownColor, size: isCenter ? 38 : 31),
          const SizedBox(height: 6),
          _RankAvatar(user: user, radius: isCenter ? 45 : 39, border: isCenter ? 5 : 4),
          const SizedBox(height: 12),
          Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF4A2A21), fontSize: 12.5, fontWeight: FontWeight.w900)),
          const Spacer(),
          _LevelScorePill(score: user.score, compact: true),
        ],
      ),
    );
  }
}

class _RankingListCard extends StatelessWidget {
  const _RankingListCard({required this.type});

  final ExperienceLevelType type;

  List<_RankUser> get _users => [
        _RankUser(rank: 4, name: type == ExperienceLevelType.sent ? 'Star Rider' : 'Rose Live', avatarText: 'S', score: 'Lv 28', colors: const [Color(0xFF191E3B), Color(0xFFFFC857)]),
        _RankUser(rank: 5, name: 'Gudiya Live', avatarText: 'G', score: 'Lv 26', colors: const [Color(0xFFE84C72), Color(0xFFFFD1DF)]),
        _RankUser(rank: 6, name: 'HAMSA Official', avatarText: 'H', score: 'Lv 24', colors: const [Color(0xFF251538), Color(0xFFEDE3D7)]),
        _RankUser(rank: 7, name: 'Rahul Gupta', avatarText: 'R', score: 'Lv 21', colors: const [Color(0xFF4E8F3A), Color(0xFFFFD36A)]),
      ];

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -34),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5D7BF)),
          boxShadow: [BoxShadow(color: const Color(0xFF4A2A21).withValues(alpha: 0.06), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: Column(
          children: _users.map((user) {
            final isLast = user == _users.last;
            return Column(
              children: [
                _RankingRow(user: user),
                if (!isLast) const Divider(height: 1, color: Color(0xFFEDE7DD)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({required this.user});

  final _RankUser user;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 86,
      child: Row(
        children: [
          SizedBox(width: 58, child: Center(child: Text('${user.rank}', style: const TextStyle(color: Color(0xFF333333), fontSize: 18, fontWeight: FontWeight.w900)))),
          _RankAvatar(user: user, radius: 27, border: 0),
          const SizedBox(width: 14),
          Expanded(child: Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF3C2A22), fontSize: 15, fontWeight: FontWeight.w900))),
          const SizedBox(width: 8),
          _LevelScorePill(score: user.score, compact: false),
          const SizedBox(width: 14),
        ],
      ),
    );
  }
}

class _MyLevelRankBar extends StatelessWidget {
  const _MyLevelRankBar({required this.user, required this.type, required this.level, required this.totalExp, required this.onAction});

  final SeatUser user;
  final ExperienceLevelType type;
  final int level;
  final int totalExp;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(18, 13, 18, 13 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E9).withValues(alpha: 0.98),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 18, offset: const Offset(0, -8))],
      ),
      child: Row(
        children: [
          const Text('999+', style: TextStyle(color: Color(0xFF111111), fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(width: 12),
          _RankAvatar(user: _RankUser(rank: 999, name: user.name, avatarText: avatarLetter(user.name), score: 'Lv $level', colors: user.avatarColors), radius: 30, border: 0),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF251538), fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Row(
                  children: [
                    ExperienceLevelPill(type: type, level: level),
                    const SizedBox(width: 6),
                    Flexible(child: Text(compactNumber(totalExp), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF8C8198), fontSize: 11, fontWeight: FontWeight.w900))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
              decoration: BoxDecoration(color: const Color(0xFFFFD28B), borderRadius: BorderRadius.circular(999)),
              child: const Text('Unfreeze', style: TextStyle(color: Color(0xFF4A2A21), fontSize: 18, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExperienceHeroCard extends StatelessWidget {
  const _ExperienceHeroCard({
    required this.user,
    required this.type,
    required this.progress,
    required this.style,
  });

  final SeatUser user;
  final ExperienceLevelType type;
  final ExperienceLevelProgress progress;
  final ExperiencePillStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: style.gradient),
        boxShadow: [BoxShadow(color: style.glowColor.withValues(alpha: 0.26), blurRadius: 24, offset: const Offset(0, 12))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(right: -34, top: -34, child: Icon(style.crownIcon, color: Colors.white.withValues(alpha: 0.10), size: 142)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 54, height: 54, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: user.avatarColors)), child: Text(avatarLetter(user.name), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900))),
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
                  progress.isMaxLevel ? 'Max level reached · ${compactNumber(progress.totalExp)} lifetime EXP' : '${compactNumber(progress.expIntoLevel)} / ${compactNumber(progress.expNeededForNextLevel)} EXP to finish Lv ${progress.level}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.90), fontSize: 12.5, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                _LevelProgressBar(style: style, value: progress.progress.clamp(0, 1)),
                const SizedBox(height: 8),
                Center(child: Text('Tier ${style.tier.label}', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.76), fontSize: 11.5, fontWeight: FontWeight.w900))),
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
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.20), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withValues(alpha: 0.12))),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Stack(
          children: [
            FractionallySizedBox(
              widthFactor: value,
              alignment: Alignment.centerLeft,
              child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [style.crownColor, style.glowColor, Colors.white.withValues(alpha: 0.92)]))),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.white.withValues(alpha: 0.0), Colors.white.withValues(alpha: 0.34), Colors.white.withValues(alpha: 0.0)], stops: const [0.18, 0.5, 0.82]),
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
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: RoomColors.softLine)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_rounded, color: type == ExperienceLevelType.sent ? const Color(0xFF0E6CFF) : const Color(0xFFFF4F93), size: 34),
              const SizedBox(height: 10),
              Text('${type.shortLabel} EXP details are private', textAlign: TextAlign.center, style: const TextStyle(color: RoomColors.plum, fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text('Detailed Sent and Received EXP pages are shown only on your own profile.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF7B6A86), fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.25)),
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: RoomColors.softLine), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 8))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: RoomColors.violet, size: 19), const SizedBox(width: 7), Text(title, style: const TextStyle(color: RoomColors.plum, fontSize: 14, fontWeight: FontWeight.w900))]),
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: RoomColors.softLine)),
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

class _RankAvatar extends StatelessWidget {
  const _RankAvatar({required this.user, required this.radius, required this.border});

  final _RankUser user;
  final double radius;
  final double border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(border),
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: user.colors.first,
        child: Container(
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: user.colors)),
          child: Center(child: Text(user.avatarText, style: TextStyle(color: Colors.white, fontSize: radius * 0.72, fontWeight: FontWeight.w900))),
        ),
      ),
    );
  }
}

class _LevelScorePill extends StatelessWidget {
  const _LevelScorePill({required this.score, required this.compact});

  final String score;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 7 : 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFF8E2), Color(0xFFFFD98D)]),
        borderRadius: BorderRadius.circular(compact ? 7 : 999),
        border: Border.all(color: const Color(0xFFE8C77C)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shield_rounded, color: Color(0xFFD8A11F), size: 18),
          const SizedBox(width: 5),
          Text(score, style: const TextStyle(color: Color(0xFF151515), fontSize: 15, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _WingedShield extends StatelessWidget {
  const _WingedShield();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 126,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(left: 5, child: Transform.rotate(angle: -0.15, child: const _Wing(side: _WingSide.left))),
          Positioned(right: 5, child: Transform.rotate(angle: 0.15, child: const _Wing(side: _WingSide.right))),
          Container(
            width: 94,
            height: 104,
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFF7BA), Color(0xFFE4A72A)]),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [BoxShadow(color: const Color(0xFFB1781E).withValues(alpha: 0.28), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: const Icon(Icons.star_rounded, color: Colors.white, size: 58),
          ),
        ],
      ),
    );
  }
}

enum _WingSide { left, right }

class _Wing extends StatelessWidget {
  const _Wing({required this.side});

  final _WingSide side;

  @override
  Widget build(BuildContext context) {
    final align = side == _WingSide.left ? Alignment.centerRight : Alignment.centerLeft;
    return SizedBox(
      width: 104,
      height: 72,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: side == _WingSide.left ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: List.generate(5, (index) {
          return Container(
            width: 98 - index * 12,
            height: 9,
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: align, end: side == _WingSide.left ? Alignment.centerLeft : Alignment.centerRight, colors: const [Colors.white, Color(0xFFEAF5FF)]),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFD8A11F).withValues(alpha: 0.22)),
            ),
          );
        }),
      ),
    );
  }
}

class _GoldLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFFE0A623).withValues(alpha: 0.15)
      ..strokeWidth = 2;
    final sparklePaint = Paint()..color = Colors.white.withValues(alpha: 0.72);

    for (var i = 0; i < 12; i++) {
      final x = i * size.width / 10;
      canvas.drawLine(Offset(x - 150, 0), Offset(x + 60, size.height), linePaint);
      canvas.drawLine(Offset(size.width - x + 150, 0), Offset(size.width - x - 60, size.height), linePaint);
    }

    final sparkles = <Offset>[
      Offset(size.width * 0.10, size.height * 0.30),
      Offset(size.width * 0.18, size.height * 0.67),
      Offset(size.width * 0.38, size.height * 0.20),
      Offset(size.width * 0.74, size.height * 0.33),
      Offset(size.width * 0.88, size.height * 0.58),
    ];

    for (final point in sparkles) {
      canvas.drawCircle(point, 4.5, sparklePaint);
      canvas.drawCircle(point.translate(7, -5), 2.5, sparklePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RankUser {
  const _RankUser({required this.rank, required this.name, required this.avatarText, required this.score, required this.colors});

  final int rank;
  final String name;
  final String avatarText;
  final String score;
  final List<Color> colors;
}
