import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'room_theme.dart';

class VibeSyncRoomState {
  const VibeSyncRoomState({
    required this.active,
    required this.mode,
    required this.pulseCount,
    required this.chemistryScore,
    required this.statusText,
  });

  final bool active;
  final VibeSyncMode mode;
  final int pulseCount;
  final int chemistryScore;
  final String statusText;

  VibeSyncRoomState copyWith({
    bool? active,
    VibeSyncMode? mode,
    int? pulseCount,
    int? chemistryScore,
    String? statusText,
  }) {
    return VibeSyncRoomState(
      active: active ?? this.active,
      mode: mode ?? this.mode,
      pulseCount: pulseCount ?? this.pulseCount,
      chemistryScore: chemistryScore ?? this.chemistryScore,
      statusText: statusText ?? this.statusText,
    );
  }

  static const inactive = VibeSyncRoomState(
    active: false,
    mode: VibeSyncMode.pulseMatch,
    pulseCount: 0,
    chemistryScore: 0,
    statusText: 'VibeSync is off',
  );
}

enum VibeSyncMode { pulseMatch, micChemistry }

extension VibeSyncModeX on VibeSyncMode {
  String get label {
    switch (this) {
      case VibeSyncMode.pulseMatch:
        return 'Pulse Match';
      case VibeSyncMode.micChemistry:
        return 'Mic Chemistry';
    }
  }

  IconData get icon {
    switch (this) {
      case VibeSyncMode.pulseMatch:
        return Icons.favorite_rounded;
      case VibeSyncMode.micChemistry:
        return Icons.graphic_eq_rounded;
    }
  }
}

class VibeSyncControlSheet extends StatelessWidget {
  const VibeSyncControlSheet({
    super.key,
    required this.state,
    required this.canManage,
    required this.onStartPulse,
    required this.onStartChemistry,
    required this.onEnd,
  });

  final VibeSyncRoomState state;
  final bool canManage;
  final VoidCallback onStartPulse;
  final VoidCallback onStartChemistry;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(14, 10, 14, MediaQuery.paddingOf(context).bottom + 14),
      decoration: const BoxDecoration(
        color: Color(0xFF120D1F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(width: 44),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(17),
                  gradient: const LinearGradient(colors: [Color(0xFFE84C72), Color(0xFF7A5CFF)]),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE84C72).withValues(alpha: 0.30),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'VibeSync 2.0',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      state.active ? '${state.mode.label} active' : 'Start a live chemistry mode for this room',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.62), fontSize: 11.5, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              RoundRoomButton(
                icon: Icons.close_rounded,
                onTap: () => Navigator.pop(context),
                color: Colors.white,
                background: Colors.white.withValues(alpha: 0.10),
                size: 34,
                iconSize: 18,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _VibeSyncModeCard(
            icon: Icons.favorite_rounded,
            title: 'Pulse Match',
            subtitle: 'Users tap Pulse when they feel the vibe. Close taps create a heart match animation.',
            enabled: canManage,
            active: state.active && state.mode == VibeSyncMode.pulseMatch,
            onTap: onStartPulse,
          ),
          const SizedBox(height: 10),
          _VibeSyncModeCard(
            icon: Icons.graphic_eq_rounded,
            title: 'Mic Chemistry',
            subtitle: 'Two users go live on mic and the room reacts to calculate a chemistry score.',
            enabled: canManage,
            active: state.active && state.mode == VibeSyncMode.micChemistry,
            onTap: onStartChemistry,
          ),
          if (state.active) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: canManage ? onEnd : null,
              child: Container(
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: RoomColors.coral.withValues(alpha: canManage ? 0.92 : 0.28),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'End VibeSync',
                  style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
          if (!canManage) ...[
            const SizedBox(height: 10),
            Text(
              'Only room owner/admins can start or end VibeSync. You can join when it is active.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 10.5, fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }
}

class VibeSyncRoomOverlay extends StatelessWidget {
  const VibeSyncRoomOverlay({
    super.key,
    required this.state,
    required this.users,
    required this.onPulseTap,
    required this.onReactionTap,
  });

  final VibeSyncRoomState state;
  final List<SeatUser> users;
  final VoidCallback onPulseTap;
  final VoidCallback onReactionTap;

  @override
  Widget build(BuildContext context) {
    if (!state.active) return const SizedBox.shrink();

    return IgnorePointer(
      ignoring: false,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.22),
                    radius: 1.05,
                    colors: [
                      const Color(0xFFE84C72).withValues(alpha: 0.16),
                      const Color(0xFF7A5CFF).withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: MediaQuery.paddingOf(context).top + 86,
            child: _VibeSyncStatusPill(state: state),
          ),
          if (state.mode == VibeSyncMode.pulseMatch)
            Positioned(
              right: 18,
              bottom: MediaQuery.paddingOf(context).bottom + 96,
              child: _PulseButton(
                pulseCount: state.pulseCount,
                onTap: onPulseTap,
              ),
            )
          else
            Positioned(
              left: 18,
              right: 18,
              bottom: MediaQuery.paddingOf(context).bottom + 96,
              child: _MicChemistryStage(
                users: users,
                score: state.chemistryScore,
                onReact: onReactionTap,
              ),
            ),
        ],
      ),
    );
  }
}

class _VibeSyncStatusPill extends StatelessWidget {
  const _VibeSyncStatusPill({required this.state});

  final VibeSyncRoomState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.20),
            const Color(0xFFE84C72).withValues(alpha: 0.30),
            const Color(0xFF7A5CFF).withValues(alpha: 0.24),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(color: const Color(0xFFE84C72).withValues(alpha: 0.20), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Icon(state.mode.icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              state.statusText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12.2, fontWeight: FontWeight.w900),
            ),
          ),
          Text(
            state.mode.label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 10.4, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _PulseButton extends StatelessWidget {
  const _PulseButton({required this.pulseCount, required this.onTap});

  final int pulseCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.94, end: 1),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutBack,
        builder: (context, value, child) => Transform.scale(scale: value, child: child),
        child: Container(
          width: 94,
          height: 94,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [Color(0xFFE84C72), Color(0xFFFFC857)]),
            boxShadow: [
              BoxShadow(color: const Color(0xFFE84C72).withValues(alpha: 0.44), blurRadius: 28, offset: const Offset(0, 10)),
              BoxShadow(color: Colors.white.withValues(alpha: 0.20), blurRadius: 18, spreadRadius: 1.0),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.favorite_rounded, color: Colors.white, size: 28),
              const SizedBox(height: 3),
              const Text('PULSE', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
              Text('x$pulseCount', style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 10, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MicChemistryStage extends StatelessWidget {
  const _MicChemistryStage({required this.users, required this.score, required this.onReact});

  final List<SeatUser> users;
  final int score;
  final VoidCallback onReact;

  @override
  Widget build(BuildContext context) {
    final first = users.isNotEmpty ? users.first : null;
    final second = users.length > 1 ? users[1] : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.18),
            const Color(0xFF7A5CFF).withValues(alpha: 0.25),
            const Color(0xFFE84C72).withValues(alpha: 0.20),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          _ChemistryAvatar(user: first, label: 'A'),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Mic Chemistry', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: score / 100,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.16),
                    valueColor: const AlwaysStoppedAnimation<Color>(RoomColors.gold),
                  ),
                ),
                const SizedBox(height: 5),
                Text('$score% chemistry', style: TextStyle(color: Colors.white.withValues(alpha: 0.76), fontSize: 10.5, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _ChemistryAvatar(user: second, label: 'B'),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onReact,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [RoomColors.gold, RoomColors.coral])),
              child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChemistryAvatar extends StatelessWidget {
  const _ChemistryAvatar({required this.user, required this.label});

  final SeatUser? user;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = user?.avatarColors ?? const [RoomColors.violet, RoomColors.aqua];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: colors)),
          child: Text(avatarLetter(user?.name ?? label), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(height: 3),
        SizedBox(
          width: 48,
          child: Text(user?.name ?? 'User $label', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 9.2, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

class _VibeSyncModeCard extends StatelessWidget {
  const _VibeSyncModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: active ? 0.16 : 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? RoomColors.gold : Colors.white.withValues(alpha: 0.10)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: const LinearGradient(colors: [Color(0xFFE84C72), Color(0xFF7A5CFF)]),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.62), fontSize: 10.5, fontWeight: FontWeight.w700, height: 1.18)),
                ],
              ),
            ),
            if (active) const Icon(Icons.check_circle_rounded, color: RoomColors.gold, size: 20),
          ],
        ),
      ),
    );
  }
}
