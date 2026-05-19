import 'package:flutter/material.dart';

import '../../data/live_room_audio_service.dart';
import '../live_room_models.dart';
import 'room_avatar_frames.dart';
import 'room_theme.dart';
import 'seat_speaking_wave.dart';

final ValueNotifier<int> roomSeatActionDismissSignal = ValueNotifier<int>(0);

void dismissRoomSeatActionPill() {
  roomSeatActionDismissSignal.value++;
}

class RoomSeatLayout extends StatelessWidget {
  const RoomSeatLayout({
    super.key,
    required this.seats,
    required this.layoutId,
    required this.selectedSeatIndex,
    required this.canManageSeats,
    required this.applyOnlyModeEnabled,
    required this.onSeatTap,
    required this.onUserTap,
    required this.onInvite,
    required this.onSwitch,
    required this.onMuteSeat,
    required this.onLock,
    required this.onUnlock,
    required this.onApply,
  });

  static const double seatWidth = 76;
  static const double seatHeight = 88;
  static const double rowHeight = 94;
  static const double avatarSize = 49;

  final List<RoomSeat> seats;
  final String layoutId;
  final int? selectedSeatIndex;
  final bool canManageSeats;
  final bool applyOnlyModeEnabled;
  final ValueChanged<int> onSeatTap;
  final ValueChanged<int> onUserTap;
  final ValueChanged<int> onInvite;
  final ValueChanged<int> onSwitch;
  final ValueChanged<int> onMuteSeat;
  final ValueChanged<int> onLock;
  final ValueChanged<int> onUnlock;
  final ValueChanged<int> onApply;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: LiveRoomAudioService.instance.activeSpeakerPeerIds,
      builder: (context, activeSpeakerPeerIds, child) {
        final spec = SeatLayoutSpec.parse(layoutId);
        final totalRows = (spec.hasHostSeats ? 1 : 0) + spec.rows;
        final layoutHeight = totalRows * rowHeight;
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return SizedBox(
              height: layoutHeight,
              width: width,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var index = 0; index < seats.length; index++)
                    Positioned(
                      left: _seatOffset(index, spec, width).dx - (seatWidth / 2),
                      top: _seatOffset(index, spec, width).dy,
                      width: seatWidth,
                      height: seatHeight,
                      child: _SeatTile(
                        seat: seats[index],
                        selected: selectedSeatIndex == index,
                        activeSpeakerPeerIds: activeSpeakerPeerIds,
                        onTap: () => _handleSeatTap(index),
                      ),
                    ),
                  if (canManageSeats &&
                      selectedSeatIndex != null &&
                      selectedSeatIndex! >= 0 &&
                      selectedSeatIndex! < seats.length)
                    _buildSeatActionPill(
                      context: context,
                      seatIndex: selectedSeatIndex!,
                      spec: spec,
                      width: width,
                      layoutHeight: layoutHeight,
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _handleSeatTap(int index) {
    final seat = seats[index];
    final user = seat.user;
    if (user == null) {
      if (applyOnlyModeEnabled && !canManageSeats && !seat.locked) {
        onApply(index);
        return;
      }
      onSeatTap(index);
    } else {
      if (canManageSeats) {
        onSeatTap(index);
        return;
      }
      onUserTap(index);
    }
  }

  Widget _buildSeatActionPill({
    required BuildContext context,
    required int seatIndex,
    required SeatLayoutSpec spec,
    required double width,
    required double layoutHeight,
  }) {
    final seat = seats[seatIndex];
    final offset = _seatOffset(seatIndex, spec, width);
    final pillWidth = width < 260 ? width - 8 : 252.0;
    const pillHeight = 42.0;
    final left = (offset.dx - pillWidth / 2)
        .clamp(4.0, width - pillWidth - 4.0)
        .toDouble();
    final below = offset.dy + 57;
    final top = below + pillHeight > layoutHeight
        ? (offset.dy - pillHeight - 4)
            .clamp(0.0, layoutHeight - pillHeight)
            .toDouble()
        : below;

    return Positioned(
      left: left,
      top: top,
      width: pillWidth,
      height: pillHeight,
      child: _SeatActionPill(
        seat: seat,
        onProfile: () => onUserTap(seatIndex),
        onInvite: () => onInvite(seatIndex),
        onSwitch: () => onSwitch(seatIndex),
        onMute: () => onMuteSeat(seatIndex),
        onLock: () => onLock(seatIndex),
        onUnlock: () => onUnlock(seatIndex),
      ),
    );
  }

  Offset _seatOffset(int index, SeatLayoutSpec spec, double width) {
    if (spec.hasHostSeats && index < spec.topSeatCount) {
      final cell = width / spec.topSeatCount;
      return Offset((cell * index) + (cell / 2), 0);
    }
    final start = spec.hasHostSeats ? spec.topSeatCount : 0;
    final gridIndex = index - start;
    final row = gridIndex ~/ spec.columns;
    final column = gridIndex % spec.columns;
    final cell = width / spec.columns;
    final topOffset = spec.hasHostSeats ? rowHeight : 0.0;
    return Offset((cell * column) + (cell / 2), topOffset + (row * rowHeight));
  }
}

class _SeatTile extends StatelessWidget {
  const _SeatTile({
    required this.seat,
    required this.selected,
    required this.activeSpeakerPeerIds,
    required this.onTap,
  });

  final RoomSeat seat;
  final bool selected;
  final Set<String> activeSpeakerPeerIds;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final user = seat.user;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SeatAvatar(
            seat: seat,
            selected: selected,
            activeSpeakerPeerIds: activeSpeakerPeerIds,
          ),
          const SizedBox(height: 3),
          SizedBox(
            height: 19,
            child: user == null
                ? _EmptySeatLabel(index: seat.index)
                : _UserSeatLabel(user: user, index: seat.index),
          ),
        ],
      ),
    );
  }
}

class _SeatActionPill extends StatelessWidget {
  const _SeatActionPill({
    required this.seat,
    required this.onProfile,
    required this.onInvite,
    required this.onSwitch,
    required this.onMute,
    required this.onLock,
    required this.onUnlock,
  });

  final RoomSeat seat;
  final VoidCallback onProfile;
  final VoidCallback onInvite;
  final VoidCallback onSwitch;
  final VoidCallback onMute;
  final VoidCallback onLock;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final user = seat.user;
    final actions = <_SeatActionData>[];

    if (user == null) {
      if (seat.locked) {
        actions.add(_SeatActionData(icon: Icons.lock_open_rounded, label: 'Unlock', onTap: onUnlock));
        actions.add(_SeatActionData(icon: Icons.person_add_alt_1_rounded, label: 'Invite', onTap: onInvite));
      } else {
        actions.add(_SeatActionData(icon: Icons.swap_horiz_rounded, label: 'Switch', onTap: onSwitch));
        actions.add(_SeatActionData(icon: Icons.person_add_alt_1_rounded, label: 'Invite', onTap: onInvite));
        actions.add(_SeatActionData(icon: Icons.mic_off_rounded, label: 'Mute', onTap: onMute));
        actions.add(_SeatActionData(icon: Icons.lock_rounded, label: 'Lock', onTap: onLock));
      }
    } else {
      actions.add(_SeatActionData(icon: Icons.person_rounded, label: 'Profile', onTap: onProfile));
      actions.add(_SeatActionData(
        icon: user.adminMuted ? Icons.mic_rounded : Icons.mic_off_rounded,
        label: user.adminMuted ? 'Unmute' : 'Mute',
        onTap: onMute,
      ));
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xF31C1228),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final action in actions)
              Expanded(
                child: InkWell(
                  onTap: action.onTap,
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(action.icon, color: Colors.white, size: 14),
                        const SizedBox(height: 1),
                        Text(
                          action.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.86),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ],
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

class _SeatActionData {
  const _SeatActionData({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _SeatAvatar extends StatelessWidget {
  const _SeatAvatar({
    required this.seat,
    required this.selected,
    required this.activeSpeakerPeerIds,
  });

  final RoomSeat seat;
  final bool selected;
  final Set<String> activeSpeakerPeerIds;

  @override
  Widget build(BuildContext context) {
    final user = seat.user;
    final avatarUrl = user?.avatarUrl?.trim();
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
    final speaking = _isUserSpeaking(user);
    final equippedFrame = user == null
        ? null
        : equippedStoreAvatarFrame(
            userId: user.id,
            assetPath: user.equippedAvatarFrameAssetPath,
            imageUrl: user.equippedAvatarFrameImageUrl,
          );

    final avatarFrame = RoomAvatarFrameHost(
      frame: user == null ? null : (equippedFrame ?? defaultStaticAvatarFrame),
      size: RoomSeatLayout.avatarSize,
      framePadding: equippedFrame == null ? 6 : 16,
      child: Container(
        width: RoomSeatLayout.avatarSize,
        height: RoomSeatLayout.avatarSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: user == null
              ? Colors.white.withValues(alpha: seat.locked ? 0.08 : 0.12)
              : null,
          gradient: user == null || hasAvatar
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: user.avatarColors,
                ),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.84)
                : Colors.white.withValues(alpha: 0.16),
            width: selected ? 1.15 : 0.95,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: user == null
            ? Center(
                child: Icon(
                  seat.locked ? Icons.lock_rounded : Icons.add_rounded,
                  color: Colors.white70,
                  size: seat.locked ? 17 : 21,
                ),
              )
            : hasAvatar
                ? Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (context, error, stackTrace) =>
                        _SeatAvatarFallback(user: user),
                  )
                : _SeatAvatarFallback(user: user),
      ),
    );

    return SizedBox(
      width: RoomSeatLayout.avatarSize + 15,
      height: RoomSeatLayout.avatarSize + 15,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (selected)
            Container(
              width: RoomSeatLayout.avatarSize + 6,
              height: RoomSeatLayout.avatarSize + 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.9),
                  width: 1.15,
                ),
              ),
            ),
          SeatSpeakingWave(
            size: RoomSeatLayout.avatarSize,
            active: speaking,
            child: avatarFrame,
          ),
          if (user?.selfMuted ?? false)
            const _SeatMuteBadge(color: RoomColors.selfMute),
          if (user?.adminMuted ?? false)
            _SeatMuteBadge(
              color: RoomColors.coral,
              glow: RoomColors.coral.withValues(alpha: 0.30),
            ),
        ],
      ),
    );
  }

  bool _isUserSpeaking(SeatUser? user) {
    if (user == null || user.selfMuted || user.adminMuted) return false;
    final roomId = LiveRoomAudioService.instance.roomId;
    final peerId = roomId == null ? '' : '${roomId}_${user.id}'.replaceAll(' ', '_');
    return user.isSpeaking || activeSpeakerPeerIds.contains(peerId);
  }
}

class _SeatMuteBadge extends StatelessWidget {
  const _SeatMuteBadge({required this.color, this.glow});
  final Color color;
  final Color? glow;

  @override
  Widget build(BuildContext context) => Positioned(
        right: 1,
        bottom: 4,
        child: Container(
          width: 17,
          height: 17,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: RoomColors.deep, width: 1.0),
            boxShadow: glow == null
                ? null
                : [
                    BoxShadow(
                      color: glow!,
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: const Icon(Icons.mic_off_rounded, color: Colors.white, size: 8.8),
        ),
      );
}

class _SeatAvatarFallback extends StatelessWidget {
  const _SeatAvatarFallback({required this.user});
  final SeatUser user;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: user.avatarColors,
          ),
        ),
        child: Center(
          child: Text(
            avatarLetter(user.name),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
}

class _EmptySeatLabel extends StatelessWidget {
  const _EmptySeatLabel({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          'NO.${index + 1}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.56),
            fontSize: 9.4,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      );
}

class _UserSeatLabel extends StatelessWidget {
  const _UserSeatLabel({required this.user, required this.index});
  final SeatUser user;
  final int index;

  @override
  Widget build(BuildContext context) {
    final chipColor = user.gender == RoomUserGender.female
        ? RoomColors.coral
        : RoomColors.aqua;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 13,
          height: 13,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: chipColor, shape: BoxShape.circle),
          child: Text(
            '${index + 1}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 6.8,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            user.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.3,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}
