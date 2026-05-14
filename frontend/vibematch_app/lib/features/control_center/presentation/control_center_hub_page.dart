import 'package:flutter/material.dart';

import 'control_center_page.dart';
import 'game_pool_management_page.dart';
import 'game_props_page.dart';
import '../../profile/presentation/control_center/vibes_reports_review_page.dart';

class ControlCenterHubPage extends StatelessWidget {
  const ControlCenterHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7F1),
        foregroundColor: const Color(0xFF251538),
        elevation: 0,
        title: const Text('Control Center', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(colors: [Color(0xFF120D1F), Color(0xFF4A2A63), Color(0xFFFFC857)]),
              boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.14), blurRadius: 22, offset: const Offset(0, 12))],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFF0A8), size: 28),
                    SizedBox(width: 10),
                    Expanded(child: Text('Super Owner Management', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Choose the management area. Existing CP is under Management, report review is under Moderation, and game risk pools are under Game Pool Management.',
                  style: TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _HubOptionCard(
            icon: Icons.admin_panel_settings_rounded,
            title: 'Management',
            subtitle: 'Existing users, roles, bans, coins, VIP/SVIP, logs and reviews.',
            gradient: const [Color(0xFF12C7B7), Color(0xFF6D5DF6)],
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ControlCenterPage())),
          ),
          const SizedBox(height: 12),
          _HubOptionCard(
            icon: Icons.shield_rounded,
            title: 'Moderation',
            subtitle: 'Review reported Vibes, close reports, delete unsafe posts, and handle content safety.',
            gradient: const [Color(0xFFE84C72), Color(0xFFFFC857)],
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VibesReportsReviewPage())),
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 12),
          _HubOptionCard(
            icon: Icons.tune_rounded,
            title: 'Game Props',
            subtitle: 'Jungle Hunt testing mode, exposure controls, whale rules, probabilities and round flow.',
            gradient: const [Color(0xFF8C5CF6), Color(0xFF12C7B7), Color(0xFFFFC857)],
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GamePropsPage())),
          ),

          _HubOptionCard(
            icon: Icons.account_balance_rounded,
            title: 'Game Pool Management',
            subtitle: 'Main game house pool, game-wise pool, RTP, caps, freeze/unfreeze and allocations.',
            gradient: const [Color(0xFFFFC857), Color(0xFFE84C72), Color(0xFF8C5CF6)],
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GamePoolManagementPage())),
          ),
        ],
      ),
    );
  }
}

class _HubOptionCard extends StatelessWidget {
  const _HubOptionCard({required this.icon, required this.title, required this.subtitle, required this.gradient, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFEDE3D7)),
            boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.045), blurRadius: 16, offset: const Offset(0, 8))],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(19),
                  gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
                child: Icon(icon, color: Colors.white, size: 27),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Color(0xFF251538), fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.25)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF8C8198)),
            ],
          ),
        ),
      ),
    );
  }
}

