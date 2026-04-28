import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'room_theme.dart';

class RoomInfoSheet extends StatefulWidget {
  const RoomInfoSheet({
    super.key,
    required this.roomName,
    required this.roomId,
    required this.language,
    required this.privacyMode,
    required this.canManageAdmins,
    this.broadcastAnnouncement = 'Welcome to the room. Respect everyone and enjoy the vibe.',
  });

  final String roomName;
  final String roomId;
  final String language;
  final RoomPrivacyMode privacyMode;
  final bool canManageAdmins;
  final String broadcastAnnouncement;

  @override
  State<RoomInfoSheet> createState() => _RoomInfoSheetState();
}

class _RoomInfoSheetState extends State<RoomInfoSheet> {
  late final List<SeatUser> _admins;
  late final List<SeatUser> _availableUsers;

  @override
  void initState() {
    super.initState();
    _admins = mockRoomUsers.where((user) => user.isHost || user.isRoomAdmin).toList();
    _availableUsers = mockInviteUsers.where((user) => !_admins.any((admin) => admin.id == user.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
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
            title: 'Broadcast Announcement',
            child: Text(
              widget.broadcastAnnouncement,
              style: const TextStyle(color: Color(0xFF5D5068), fontSize: 12.2, fontWeight: FontWeight.w700, height: 1.28),
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
                  onTap: _addAdmin,
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
                  onEdit: () => RoomToast.show(context, 'Edit admin permissions for ${admin.name} will connect here'),
                  onRemove: () => setState(() => _admins.removeAt(index)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _addAdmin() {
    if (_availableUsers.isEmpty) {
      RoomToast.show(context, 'No available users to add as admin');
      return;
    }
    final user = _availableUsers.removeAt(0).copyWith(isRoomAdmin: true, roleLabel: 'Administrator');
    setState(() => _admins.add(user));
    RoomToast.show(context, '${user.name} added as admin locally');
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
  const _AdminTile({required this.user, required this.canManage, required this.onEdit, required this.onRemove});

  final SeatUser user;
  final bool canManage;
  final VoidCallback onEdit;
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
          if (canManage) ...[
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Edit admin',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_rounded, color: RoomColors.violet, size: 18),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Remove admin',
              onPressed: onRemove,
              icon: const Icon(Icons.remove_circle_rounded, color: RoomColors.coral, size: 19),
            ),
          ],
        ],
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
