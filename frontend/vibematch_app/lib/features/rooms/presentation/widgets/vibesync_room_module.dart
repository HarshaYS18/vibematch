import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'room_theme.dart';

class VibeSyncRoomState {
  const VibeSyncRoomState({
    required this.active,
    required this.announced,
    this.firstUser,
    this.secondUser,
    required this.statusText,
  });

  final bool active;
  final bool announced;
  final SeatUser? firstUser;
  final SeatUser? secondUser;
  final String statusText;

  bool get hasBothUsers => firstUser != null && secondUser != null;

  VibeSyncRoomState copyWith({
    bool? active,
    bool? announced,
    SeatUser? firstUser,
    SeatUser? secondUser,
    bool clearFirstUser = false,
    bool clearSecondUser = false,
    String? statusText,
  }) {
    return VibeSyncRoomState(
      active: active ?? this.active,
      announced: announced ?? this.announced,
      firstUser: clearFirstUser ? null : (firstUser ?? this.firstUser),
      secondUser: clearSecondUser ? null : (secondUser ?? this.secondUser),
      statusText: statusText ?? this.statusText,
    );
  }

  static const inactive = VibeSyncRoomState(
    active: false,
    announced: false,
    statusText: 'VibeSync is off',
  );
}

class VibeSyncControlSheet extends StatelessWidget {
  const VibeSyncControlSheet({
    super.key,
    required this.state,
    required this.users,
    required this.canManage,
    required this.onPickFirst,
    required this.onPickSecond,
    required this.onAnnounce,
    required this.onEnd,
  });

  final VibeSyncRoomState state;
  final List<SeatUser> users;
  final bool canManage;
  final ValueChanged<SeatUser> onPickFirst;
  final ValueChanged<SeatUser> onPickSecond;
  final VoidCallback onAnnounce;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.72),
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
                      'VibeSync',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pick two users, announce, then show match overlay',
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
          const SizedBox(height: 14),
          _SelectedMatchPreview(state: state),
          const SizedBox(height: 12),
          if (canManage) ...[
            Row(
              children: [
                Expanded(
                  child: _PrimaryActionButton(
                    label: state.firstUser == null ? 'Pick first' : 'Change first',
                    icon: Icons.looks_one_rounded,
                    onTap: users.isEmpty ? null : () => _openPicker(context, firstSlot: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PrimaryActionButton(
                    label: state.secondUser == null ? 'Pick second' : 'Change second',
                    icon: Icons.looks_two_rounded,
                    onTap: users.isEmpty ? null : () => _openPicker(context, firstSlot: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _AnnounceButton(
              enabled: state.hasBothUsers,
              announced: state.announced,
              onTap: state.hasBothUsers ? onAnnounce : null,
            ),
            if (state.active) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: onEnd,
                child: Container(
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: RoomColors.coral.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Text(
                    'Clear Match Overlay',
                    style: TextStyle(color: Colors.white, fontSize: 12.2, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ] else
            Text(
              'Only room owner/admins can pick and announce VibeSync matches.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.58), fontSize: 11, fontWeight: FontWeight.w700),
            ),
        ],
      ),
    );
  }

  void _openPicker(BuildContext context, {required bool firstSlot}) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.fromLTRB(14, 10, 14, MediaQuery.paddingOf(context).bottom + 14),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(width: 42),
            const SizedBox(height: 12),
            Text(
              firstSlot ? 'Pick first user' : 'Pick second user',
              style: const TextStyle(color: RoomColors.plum, fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: users.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final user = users[index];
                  return _PickUserTile(
                    user: user,
                    selected: firstSlot ? state.firstUser?.id == user.id : state.secondUser?.id == user.id,
                    onTap: () {
                      Navigator.pop(context);
                      if (firstSlot) {
                        onPickFirst(user);
                      } else {
                        onPickSecond(user);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VibeSyncRoomOverlay extends StatelessWidget {
  const VibeSyncRoomOverlay({
    super.key,
    required this.state,
    required this.onDismiss,
  });

  final VibeSyncRoomState state;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    if (!state.active || !state.hasBothUsers) return const SizedBox.shrink();

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.15),
                    radius: 0.9,
                    colors: [
                      const Color(0xFFE84C72).withValues(alpha: 0.24),
                      const Color(0xFF7A5CFF).withValues(alpha: 0.14),
                      Colors.black.withValues(alpha: 0.10),
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: _MatchOverlayCard(state: state, onDismiss: onDismiss),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchOverlayCard extends StatelessWidget {
  const _MatchOverlayCard({required this.state, required this.onDismiss});

  final VibeSyncRoomState state;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final first = state.firstUser!;
    final second = state.secondUser!;

    return Container(
      width: MediaQuery.sizeOf(context).width * 0.84,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.26),
            const Color(0xFFE84C72).withValues(alpha: 0.34),
            const Color(0xFF7A5CFF).withValues(alpha: 0.30),
            Colors.white.withValues(alpha: 0.13),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.36), width: 1.2),
        boxShadow: [
          BoxShadow(color: const Color(0xFFE84C72).withValues(alpha: 0.34), blurRadius: 34, offset: const Offset(0, 16)),
          BoxShadow(color: Colors.white.withValues(alpha: 0.18), blurRadius: 22, spreadRadius: 1.2),
        ],
      ),
      child: Stack(
        children: [
          Positioned(right: -2, top: -4, child: _TinyClose(onTap: onDismiss)),
          const Positioned(left: 18, top: 4, child: _Sparkle(size: 16)),
          const Positioned(right: 52, top: 20, child: _Sparkle(size: 12)),
          const Positioned(left: 64, bottom: 20, child: _Sparkle(size: 10)),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Vibe Match Announced',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.white54, blurRadius: 12)]),
              ),
              const SizedBox(height: 4),
              Text(
                state.statusText,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 11.2, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _MatchUserAvatar(user: first),
                  Container(
                    width: 56,
                    height: 56,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [RoomColors.gold, RoomColors.coral]),
                      boxShadow: [BoxShadow(color: RoomColors.coral.withValues(alpha: 0.42), blurRadius: 22)],
                    ),
                    child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 30),
                  ),
                  _MatchUserAvatar(user: second),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '${first.name}  ×  ${second.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              const Text(
                'Match overlay only • backend/WebSocket later',
                style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SelectedMatchPreview extends StatelessWidget {
  const _SelectedMatchPreview({required this.state});

  final VibeSyncRoomState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          _SmallPickedUser(user: state.firstUser, fallback: '1'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Icon(Icons.favorite_rounded, color: RoomColors.coral, size: 24),
          ),
          _SmallPickedUser(user: state.secondUser, fallback: '2'),
        ],
      ),
    );
  }
}

class _SmallPickedUser extends StatelessWidget {
  const _SmallPickedUser({required this.user, required this.fallback});

  final SeatUser? user;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final colors = user?.avatarColors ?? const [Color(0xFF2A2138), Color(0xFF443653)];
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: colors)),
            child: Text(avatarLetter(user?.name ?? fallback), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              user?.name ?? 'Pick user $fallback',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white.withValues(alpha: user == null ? 0.52 : 0.92), fontSize: 12, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: enabled ? 0.12 : 0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: enabled ? RoomColors.gold : Colors.white38, size: 17),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: enabled ? Colors.white : Colors.white38, fontSize: 12, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _AnnounceButton extends StatelessWidget {
  const _AnnounceButton({required this.enabled, required this.announced, required this.onTap});

  final bool enabled;
  final bool announced;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          gradient: enabled ? const LinearGradient(colors: [RoomColors.gold, RoomColors.coral]) : null,
          color: enabled ? null : Colors.white.withValues(alpha: 0.08),
        ),
        child: Text(
          announced ? 'Announce Again' : 'Announce Match',
          style: TextStyle(color: enabled ? Colors.white : Colors.white38, fontSize: 13, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _PickUserTile extends StatelessWidget {
  const _PickUserTile({required this.user, required this.selected, required this.onTap});

  final SeatUser user;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: selected ? RoomColors.gold.withValues(alpha: 0.14) : const Color(0xFFFCFAF6),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? RoomColors.gold : RoomColors.softLine),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: user.avatarColors)),
              child: Text(avatarLetter(user.name), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 9),
            Expanded(child: Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: RoomColors.plum, fontSize: 13, fontWeight: FontWeight.w900))),
            if (selected) const Icon(Icons.check_circle_rounded, color: RoomColors.gold, size: 20),
          ],
        ),
      ),
    );
  }
}

class _MatchUserAvatar extends StatelessWidget {
  const _MatchUserAvatar({required this.user});

  final SeatUser user;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 66,
          height: 66,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: user.avatarColors),
            border: Border.all(color: Colors.white.withValues(alpha: 0.42), width: 2),
            boxShadow: [BoxShadow(color: user.avatarColors.first.withValues(alpha: 0.34), blurRadius: 18)],
          ),
          child: Text(avatarLetter(user.name), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 72,
          child: Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }
}

class _TinyClose extends StatelessWidget {
  const _TinyClose({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.22)),
        child: const Icon(Icons.close_rounded, color: Colors.white, size: 17),
      ),
    );
  }
}

class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.auto_awesome_rounded, color: Colors.white, size: size, shadows: const [Shadow(color: Colors.white, blurRadius: 10)]);
  }
}
