import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'room_theme.dart';

final ValueNotifier<String> roomBroadcastAnnouncementNotifier =
    ValueNotifier<String>('Welcome to the room. Respect everyone and enjoy the vibe.');

class RoomInfoSheet extends StatefulWidget {
  const RoomInfoSheet({
    super.key,
    required this.roomName,
    required this.roomId,
    required this.language,
    required this.privacyMode,
    required this.canManageAdmins,
    required this.admins,
    required this.availableAdminUsers,
    required this.onAddAdmin,
    required this.onRemoveAdmin,
    this.broadcastAnnouncement = 'Welcome to the room. Respect everyone and enjoy the vibe.',
  });

  final String roomName;
  final String roomId;
  final String language;
  final RoomPrivacyMode privacyMode;
  final bool canManageAdmins;
  final List<SeatUser> admins;
  final List<SeatUser> availableAdminUsers;
  final ValueChanged<SeatUser> onAddAdmin;
  final ValueChanged<SeatUser> onRemoveAdmin;
  final String broadcastAnnouncement;

  @override
  State<RoomInfoSheet> createState() => _RoomInfoSheetState();
}

class _RoomInfoSheetState extends State<RoomInfoSheet> {
  late List<SeatUser> _admins;
  late List<SeatUser> _availableAdminUsers;

  @override
  void initState() {
    super.initState();
    _syncFromWidget();
  }

  @override
  void didUpdateWidget(covariant RoomInfoSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.admins != widget.admins ||
        oldWidget.availableAdminUsers != widget.availableAdminUsers) {
      _syncFromWidget();
    }
  }

  void _syncFromWidget() {
    _admins = List<SeatUser>.from(widget.admins);
    _availableAdminUsers = List<SeatUser>.from(widget.availableAdminUsers);
  }

  void _addAdmin(SeatUser user) {
    final updatedUser = user.copyWith(
      isRoomAdmin: true,
      roleLabel: 'Administrator',
    );

    setState(() {
      _availableAdminUsers.removeWhere((item) => item.id == user.id);
      if (!_admins.any((item) => item.id == user.id)) {
        _admins.add(updatedUser);
      }
    });

    widget.onAddAdmin(user);
  }

  void _removeAdmin(SeatUser user) {
    if (user.isHost) return;

    final updatedUser = user.copyWith(
      isRoomAdmin: false,
      roleLabel: 'Member',
    );

    setState(() {
      _admins.removeWhere((item) => item.id == user.id);
      if (!_availableAdminUsers.any((item) => item.id == user.id)) {
        _availableAdminUsers.add(updatedUser);
      }
    });

    widget.onRemoveAdmin(user);
  }

  @override
  Widget build(BuildContext context) {
    if (roomBroadcastAnnouncementNotifier.value.trim().isEmpty) {
      roomBroadcastAnnouncementNotifier.value = widget.broadcastAnnouncement;
    }

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.72),
      padding: EdgeInsets.fromLTRB(14, 10, 14, MediaQuery.paddingOf(context).bottom + 14),
      decoration: const BoxDecoration(
        color: Colors.white,
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
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(colors: [RoomColors.violet, RoomColors.aqua]),
                  boxShadow: [BoxShadow(color: RoomColors.violet.withValues(alpha: 0.22), blurRadius: 16, offset: const Offset(0, 8))],
                ),
                child: Icon(widget.privacyMode.icon, color: Colors.white, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.roomName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: RoomColors.plum, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.roomId} • ${widget.language} • ${widget.privacyMode.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF82758E), fontSize: 11.5, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              RoundRoomButton(
                icon: Icons.close_rounded,
                onTap: () => Navigator.pop(context),
                color: RoomColors.plum,
                background: RoomColors.pearl,
                size: 34,
                iconSize: 18,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoCard(
            icon: Icons.info_rounded,
            title: 'Room Details',
            child: Column(
              children: [
                _InfoRow(label: 'Room name', value: widget.roomName),
                _InfoRow(label: 'Room ID', value: widget.roomId),
                _InfoRow(label: 'Language', value: widget.language),
                _InfoRow(label: 'Mode', value: widget.privacyMode.label),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _InfoCard(
            icon: Icons.campaign_rounded,
            title: 'Broad Announcement',
            child: ValueListenableBuilder<String>(
              valueListenable: roomBroadcastAnnouncementNotifier,
              builder: (context, announcement, _) {
                final cleanAnnouncement = announcement.trim().isEmpty
                    ? widget.broadcastAnnouncement
                    : announcement.trim();

                return Text(
                  cleanAnnouncement,
                  style: const TextStyle(color: Color(0xFF5D5068), fontSize: 12.2, fontWeight: FontWeight.w700, height: 1.28),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Admins in Room',
                  style: TextStyle(color: RoomColors.plum, fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ),
              if (widget.canManageAdmins)
                _SmallActionPill(
                  icon: Icons.person_add_alt_1_rounded,
                  label: 'Add Admin',
                  onTap: () => _openAddAdminSheet(context),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              itemCount: _admins.length,
              separatorBuilder: (context, index) => const SizedBox(height: 7),
              itemBuilder: (context, index) {
                final admin = _admins[index];
                return _AdminTile(
                  user: admin,
                  canManage: widget.canManageAdmins && !admin.isHost,
                  onRemove: () => _removeAdmin(admin),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openAddAdminSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: EdgeInsets.fromLTRB(
          14,
          10,
          14,
          MediaQuery.paddingOf(sheetContext).bottom + 14,
        ),
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
            const Text(
              'Add Room Admin',
              style: TextStyle(color: RoomColors.plum, fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            const Text(
              'Choose a room member to promote as room admin.',
              style: TextStyle(color: Color(0xFF82758E), fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (_availableAdminUsers.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: RoomColors.pearl,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: RoomColors.softLine),
                ),
                child: const Text(
                  'No eligible users available right now.',
                  style: TextStyle(color: Color(0xFF82758E), fontSize: 12, fontWeight: FontWeight.w800),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _availableAdminUsers.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 7),
                  itemBuilder: (context, index) {
                    final user = _availableAdminUsers[index];
                    return _AddAdminTile(
                      user: user,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _addAdmin(user);
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.title, required this.child});

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: RoomColors.pearl, borderRadius: BorderRadius.circular(20), border: Border.all(color: RoomColors.softLine)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: RoomColors.aqua, size: 16),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(color: RoomColors.plum, fontSize: 13, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 9),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(color: Color(0xFF82758E), fontSize: 11.5, fontWeight: FontWeight.w800)),
          ),
          Expanded(
            child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: RoomColors.plum, fontSize: 12.2, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  const _AdminTile({required this.user, required this.canManage, required this.onRemove});

  final SeatUser user;
  final bool canManage;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(color: const Color(0xFFFCFAF6), borderRadius: BorderRadius.circular(18), border: Border.all(color: RoomColors.softLine)),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: RoomColors.plum, fontSize: 13, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(user.isHost ? 'Owner / Host' : 'Room Admin', style: const TextStyle(color: Color(0xFF82758E), fontSize: 10.5, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          if (canManage)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Remove admin',
              onPressed: onRemove,
              icon: const Icon(Icons.remove_circle_rounded, color: RoomColors.coral, size: 20),
            ),
        ],
      ),
    );
  }
}

class _AddAdminTile extends StatelessWidget {
  const _AddAdminTile({required this.user, required this.onTap});

  final SeatUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(color: const Color(0xFFFCFAF6), borderRadius: BorderRadius.circular(18), border: Border.all(color: RoomColors.softLine)),
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
            Expanded(
              child: Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: RoomColors.plum, fontSize: 13, fontWeight: FontWeight.w900)),
            ),
            const Icon(Icons.add_moderator_rounded, color: RoomColors.aqua, size: 21),
          ],
        ),
      ),
    );
  }
}

class _SmallActionPill extends StatelessWidget {
  const _SmallActionPill({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RoomColors.plum,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 14),
              const SizedBox(width: 5),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
    );
  }
}
