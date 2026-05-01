import 'package:flutter/material.dart';

import 'modules/control_panel_module.dart';
import 'modules/room_realtime_audit_logs_module.dart';

class FounderControlCenterPage extends StatelessWidget {
  const FounderControlCenterPage({super.key});

  List<ControlPanelModule> get _modules => [
        ControlPanelModule(
          id: 'room_realtime_audit_logs',
          title: 'Room Realtime Audit Logs',
          subtitle: 'Seat actions, locks, switches, and mic moderation history',
          icon: Icons.history_edu_rounded,
          color: const Color(0xFF6D5DF6),
          builder: (_) => const RoomRealtimeAuditLogsModule(),
        ),
        ControlPanelModule(
          id: 'room_state_monitor',
          title: 'Room State Monitor',
          subtitle: 'Coming next: active Redis room-state snapshots and live room status',
          icon: Icons.radar_rounded,
          color: const Color(0xFF12C7B7),
          enabled: false,
          builder: (_) => const _ComingSoonModule(title: 'Room State Monitor'),
        ),
        ControlPanelModule(
          id: 'moderation_actions',
          title: 'Moderation Actions',
          subtitle: 'Coming next: kick, mute, ban, device action review and approvals',
          icon: Icons.shield_rounded,
          color: const Color(0xFFE84C72),
          enabled: false,
          builder: (_) => const _ComingSoonModule(title: 'Moderation Actions'),
        ),
        ControlPanelModule(
          id: 'media_review',
          title: 'Media Review',
          subtitle: 'Coming next: DP, room background, and upload moderation queue',
          icon: Icons.image_search_rounded,
          color: const Color(0xFFFF9F43),
          enabled: false,
          builder: (_) => const _ComingSoonModule(title: 'Media Review'),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F5FF),
        elevation: 0,
        foregroundColor: const Color(0xFF21152F),
        title: const Text(
          'Founder Control Center',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          const _FounderControlHeader(),
          const SizedBox(height: 16),
          const Text(
            'Control Panel Modules',
            style: TextStyle(
              color: Color(0xFF21152F),
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 10),
          ..._modules.map(
            (module) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ControlPanelModuleCard(module: module),
            ),
          ),
        ],
      ),
    );
  }
}

class _FounderControlHeader extends StatelessWidget {
  const _FounderControlHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF21152F), Color(0xFF3E2465), Color(0xFF6D5DF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6D5DF6).withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 62,
            width: 62,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(23),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 34),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Founder Tools',
                  style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                Text(
                  'Each control panel is now built as a separate module for clean scaling.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontWeight: FontWeight.w700, height: 1.25),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlPanelModuleCard extends StatelessWidget {
  const _ControlPanelModuleCard({required this.module});

  final ControlPanelModule module;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: module.enabled ? 1 : 0.70,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          if (!module.enabled) {
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(
                SnackBar(
                  content: Text('${module.title} will be connected in a later module.'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: const Color(0xFF21152F),
                ),
              );
            return;
          }

          Navigator.of(context).push(
            MaterialPageRoute(builder: module.builder),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: module.color.withValues(alpha: 0.20)),
            boxShadow: [
              BoxShadow(
                color: module.color.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 54,
                width: 54,
                decoration: BoxDecoration(
                  color: module.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(19),
                ),
                child: Icon(module.icon, color: module.color, size: 28),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            module.title,
                            style: const TextStyle(color: Color(0xFF21152F), fontSize: 15.8, fontWeight: FontWeight.w900),
                          ),
                        ),
                        if (!module.enabled)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0ECF8),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Soon',
                              style: TextStyle(color: Color(0xFF6D5DF6), fontSize: 10.5, fontWeight: FontWeight.w900),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      module.subtitle,
                      style: const TextStyle(color: Color(0xFF6D6070), fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.25),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: module.enabled ? module.color : const Color(0xFFB9AFCB)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComingSoonModule extends StatelessWidget {
  const _ComingSoonModule({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F5FF),
        foregroundColor: const Color(0xFF21152F),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: const Center(
        child: Text(
          'This control panel module will be connected later.',
          style: TextStyle(color: Color(0xFF21152F), fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
