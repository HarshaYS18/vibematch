import 'package:flutter/material.dart';

class RankingsPage extends StatefulWidget {
  const RankingsPage({super.key});

  @override
  State<RankingsPage> createState() => _RankingsPageState();
}

class _RankingsPageState extends State<RankingsPage> {
  final List<String> _tabs = const ['Global Ranking', 'Family Ranking', 'Wealth Ranking'];
  final List<String> _periods = const ['Daily', 'Monthly'];

  int _selectedTab = 2;
  int _selectedPeriod = 0;

  final List<_RankingUser> _users = const [
    _RankingUser(rank: 1, name: 'Founder Harsha', avatarText: 'H', score: '1******0', vip: 'VIP 32', colors: [Color(0xFF4B2B16), Color(0xFFFFD36A)]),
    _RankingUser(rank: 2, name: 'Moon Queen', avatarText: 'M', score: '1******0', vip: 'VIP 18', colors: [Color(0xFFB7D4FF), Color(0xFFE9F4FF)]),
    _RankingUser(rank: 3, name: 'Virat Reddy', avatarText: 'V', score: '1******0', vip: 'VIP 14', colors: [Color(0xFFE7C8B9), Color(0xFFFFEFE8)]),
    _RankingUser(rank: 4, name: 'Star Rider', avatarText: 'S', score: '6*****0', vip: 'VIP 12', colors: [Color(0xFF191E3B), Color(0xFFFFC857)]),
    _RankingUser(rank: 5, name: 'Gudiya Live', avatarText: 'G', score: '5*****0', vip: 'VIP 11', colors: [Color(0xFFE84C72), Color(0xFFFFD1DF)]),
    _RankingUser(rank: 6, name: 'HAMSA Official', avatarText: 'H', score: '4*****0', vip: 'VIP 9', colors: [Color(0xFF251538), Color(0xFFEDE3D7)]),
    _RankingUser(rank: 7, name: 'Rahul Gupta', avatarText: 'R', score: '3*****0', vip: 'VIP 8', colors: [Color(0xFF4E8F3A), Color(0xFFFFD36A)]),
    _RankingUser(rank: 8, name: 'Akhil Voice', avatarText: 'A', score: '2*****0', vip: 'VIP 7', colors: [Color(0xFF12C7B7), Color(0xFF6D5DF6)]),
  ];

  void _showRewardsInfo() {
    _toast('Ranking rewards will connect to backend rewards rules later.');
  }

  void _openHelp() {
    _toast('Ranking rules/help will open here.');
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
    final listUsers = _users.where((user) => user.rank > 3).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _RankingHeader(
                  tabs: _tabs,
                  selectedTab: _selectedTab,
                  onBack: () => Navigator.pop(context),
                  onHelp: _openHelp,
                  onTabSelected: (index) => setState(() => _selectedTab = index),
                ),
                _PeriodSwitch(
                  periods: _periods,
                  selectedIndex: _selectedPeriod,
                  onSelected: (index) => setState(() => _selectedPeriod = index),
                ),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 116),
                    children: [
                      _GoldHeroSection(
                        selectedTab: _tabs[_selectedTab],
                        period: _periods[_selectedPeriod],
                        onRewardsTap: _showRewardsInfo,
                      ),
                      _TopThreePodium(users: _users.take(3).toList()),
                      _RankingListCard(users: listUsers),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _MyRankBar(
                user: const _RankingUser(rank: 999, name: 'Harsha Reddy', avatarText: 'H', score: 'Unfreeze', vip: 'VIP 32', colors: [Color(0xFF251538), Color(0xFFFFD36A)]),
                onAction: () => _toast('VIP unfreeze / ranking boost flow will connect later.'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankingHeader extends StatelessWidget {
  const _RankingHeader({
    required this.tabs,
    required this.selectedTab,
    required this.onBack,
    required this.onHelp,
    required this.onTabSelected,
  });

  final List<String> tabs;
  final int selectedTab;
  final VoidCallback onBack;
  final VoidCallback onHelp;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 14),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111111), size: 31),
          ),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: tabs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 24),
                itemBuilder: (context, index) {
                  final selected = index == selectedTab;
                  return InkWell(
                    onTap: () => onTabSelected(index),
                    borderRadius: BorderRadius.circular(14),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          tabs[index],
                          style: TextStyle(
                            color: selected ? const Color(0xFF111111) : const Color(0xFF9A9A9A),
                            fontSize: 19,
                            fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                            letterSpacing: -0.4,
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
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onHelp,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: Color(0xFF4A4A4A),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.question_mark_rounded, color: Colors.white, size: 27),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodSwitch extends StatelessWidget {
  const _PeriodSwitch({required this.periods, required this.selectedIndex, required this.onSelected});

  final List<String> periods;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Container(
        height: 58,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFE9E9EB),
          borderRadius: BorderRadius.circular(999),
        ),
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
                    boxShadow: selected
                        ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))]
                        : null,
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

class _GoldHeroSection extends StatelessWidget {
  const _GoldHeroSection({required this.selectedTab, required this.period, required this.onRewardsTap});

  final String selectedTab;
  final String period;
  final VoidCallback onRewardsTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF4C6), Color(0xFFFFD67A)],
        ),
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
              style: TextStyle(
                color: const Color(0xFF6F5530).withValues(alpha: 0.92),
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
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
                decoration: const BoxDecoration(
                  color: Color(0xFFFFA800),
                  borderRadius: BorderRadius.horizontal(left: Radius.circular(999)),
                ),
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
                  '$period · $selectedTab',
                  style: TextStyle(
                    color: const Color(0xFF7A5922).withValues(alpha: 0.72),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
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

class _TopThreePodium extends StatelessWidget {
  const _TopThreePodium({required this.users});

  final List<_RankingUser> users;

  @override
  Widget build(BuildContext context) {
    final first = users.firstWhere((user) => user.rank == 1);
    final second = users.firstWhere((user) => user.rank == 2);
    final third = users.firstWhere((user) => user.rank == 3);

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

  final _RankingUser user;
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
          _RankingAvatar(user: user, radius: isCenter ? 45 : 39, border: isCenter ? 5 : 4),
          const SizedBox(height: 12),
          Text(
            user.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF4A2A21), fontSize: 12.5, fontWeight: FontWeight.w900),
          ),
          const Spacer(),
          _ScorePill(score: user.score, compact: true),
        ],
      ),
    );
  }
}

class _RankingListCard extends StatelessWidget {
  const _RankingListCard({required this.users});

  final List<_RankingUser> users;

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
          children: users.map((user) {
            final isLast = user == users.last;
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

  final _RankingUser user;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 86,
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Center(
              child: Text(
                '${user.rank}',
                style: const TextStyle(color: Color(0xFF333333), fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          _RankingAvatar(user: user, radius: 27, border: 0),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              user.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF3C2A22), fontSize: 15, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 8),
          _ScorePill(score: user.score, compact: false),
          const SizedBox(width: 14),
        ],
      ),
    );
  }
}

class _MyRankBar extends StatelessWidget {
  const _MyRankBar({required this.user, required this.onAction});

  final _RankingUser user;
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
          Text('999+', style: const TextStyle(color: Color(0xFF111111), fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(width: 12),
          _RankingAvatar(user: user, radius: 30, border: 0),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF251538), fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFE6E0DC), borderRadius: BorderRadius.circular(999)),
                  child: Text(user.vip, style: const TextStyle(color: Color(0xFF8C8198), fontSize: 10, fontWeight: FontWeight.w900)),
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
              decoration: BoxDecoration(
                color: const Color(0xFFFFD28B),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text('Unfreeze', style: TextStyle(color: Color(0xFF4A2A21), fontSize: 18, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingAvatar extends StatelessWidget {
  const _RankingAvatar({required this.user, required this.radius, required this.border});

  final _RankingUser user;
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
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: user.colors),
          ),
          child: Center(
            child: Text(
              user.avatarText,
              style: TextStyle(color: Colors.white, fontSize: radius * 0.72, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.score, required this.compact});

  final String score;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 4, vertical: compact ? 7 : 3),
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
              gradient: LinearGradient(
                begin: align,
                end: side == _WingSide.left ? Alignment.centerLeft : Alignment.centerRight,
                colors: const [Colors.white, Color(0xFFEAF5FF)],
              ),
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

class _RankingUser {
  const _RankingUser({
    required this.rank,
    required this.name,
    required this.avatarText,
    required this.score,
    required this.vip,
    required this.colors,
  });

  final int rank;
  final String name;
  final String avatarText;
  final String score;
  final String vip;
  final List<Color> colors;
}
