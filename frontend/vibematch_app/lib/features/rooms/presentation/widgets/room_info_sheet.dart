import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../live_room_models.dart';
import 'room_theme.dart';

final ValueNotifier<String> roomBroadcastAnnouncementNotifier =
    ValueNotifier<String>(
      'Welcome to the room. Respect everyone and enjoy the vibe.',
    );

enum _RoomInfoTab { roomInfo, admins, members }

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
    this.broadcastAnnouncement =
        'Welcome to the room. Respect everyone and enjoy the vibe.',
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
  late final PageController _pageController;
  late List<SeatUser> _localAdmins;
  late List<SeatUser> _localAvailableAdminUsers;
  _RoomInfoTab _selectedTab = _RoomInfoTab.roomInfo;

  List<SeatUser> get _admins => _dedupeUsers(
    _localAdmins.where((user) => user.isHost || user.isRoomAdmin),
  );
  List<SeatUser> get _availableAdminUsers => _dedupeUsers(
    _localAvailableAdminUsers.where(
      (user) => !user.isHost && !user.isRoomAdmin,
    ),
  );
  List<SeatUser> get _members => _dedupeUsers(
    _localAvailableAdminUsers.where(_isApprovedRoomMember),
  );

  bool _isApprovedRoomMember(SeatUser user) {
    if (user.isHost || user.isRoomAdmin) return false;
    final normalizedRole = user.roleLabel
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ');
    return normalizedRole == 'room member';
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedTab.index);
    _syncLocalUsersFromWidget();
  }

  @override
  void didUpdateWidget(covariant RoomInfoSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.admins != widget.admins ||
        oldWidget.availableAdminUsers != widget.availableAdminUsers) {
      _syncLocalUsersFromWidget();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _syncLocalUsersFromWidget() {
    final combined = _dedupeUsers(<SeatUser>[
      ...widget.admins,
      ...widget.availableAdminUsers,
    ]);
    _localAdmins = combined
        .where((user) => user.isHost || user.isRoomAdmin)
        .toList(growable: true);
    _localAvailableAdminUsers = combined
        .where((user) => !user.isHost && !user.isRoomAdmin)
        .toList(growable: true);
  }

  List<SeatUser> _dedupeUsers(Iterable<SeatUser> source) {
    final users = <SeatUser>[];
    final ids = <String>{};
    for (final user in source) {
      if (user.id.trim().isEmpty) continue;
      if (ids.add(user.id)) users.add(user);
    }
    users.sort((a, b) {
      if (a.isHost != b.isHost) return a.isHost ? -1 : 1;
      if (a.isRoomAdmin != b.isRoomAdmin) return a.isRoomAdmin ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return users;
  }

  void _goToTab(_RoomInfoTab tab) {
    setState(() => _selectedTab = tab);
    _pageController.animateToPage(
      tab.index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _copyRoomId() {
    Clipboard.setData(ClipboardData(text: widget.roomId));
    RoomToast.show(context, 'Room ID copied');
  }

  void _addAdmin(SeatUser user) {
    final promoted = user.copyWith(isRoomAdmin: true, roleLabel: 'Admin');
    setState(() {
      _localAvailableAdminUsers.removeWhere((item) => item.id == user.id);
      _localAdmins.removeWhere((item) => item.id == user.id);
      _localAdmins.add(promoted);
    });
    widget.onAddAdmin(promoted);
    RoomToast.show(context, '${user.name} is now Admin');
  }

  void _removeAdmin(SeatUser user) {
    if (user.isHost) return;
    final demoted = user.copyWith(isRoomAdmin: false, roleLabel: 'Visitor');
    setState(() {
      _localAdmins.removeWhere((item) => item.id == user.id);
      _localAvailableAdminUsers.removeWhere((item) => item.id == user.id);
      _localAvailableAdminUsers.add(demoted);
    });
    widget.onRemoveAdmin(demoted);
    RoomToast.show(context, '${user.name} is no longer Admin');
  }

  void _removeMember(SeatUser user) {
    if (user.isHost) {
      RoomToast.show(context, 'Room owner cannot be removed');
      return;
    }
    RoomToast.show(
      context,
      'Room member removal will use backend room membership permissions.',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (roomBroadcastAnnouncementNotifier.value.trim().isEmpty) {
      roomBroadcastAnnouncementNotifier.value = widget.broadcastAnnouncement;
    }

    final sheetHeight = MediaQuery.sizeOf(context).height * 0.37;
    final admins = _admins;
    final availableAdminUsers = _availableAdminUsers;
    final members = _members;

    return Container(
      height: sheetHeight,
      padding: EdgeInsets.fromLTRB(
        14,
        10,
        14,
        MediaQuery.paddingOf(context).bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        children: [
          const SheetHandle(width: 42),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _RoomInfoTabs(
                  selected: _selectedTab,
                  onChanged: _goToTab,
                ),
              ),
              const SizedBox(width: 8),
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
          const SizedBox(height: 10),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) =>
                  setState(() => _selectedTab = _RoomInfoTab.values[index]),
              children: [
                _RoomInfoPage(
                  roomName: widget.roomName,
                  roomId: widget.roomId,
                  language: widget.language,
                  privacyMode: widget.privacyMode,
                  onCopyRoomId: _copyRoomId,
                  fallbackAnnouncement: widget.broadcastAnnouncement,
                ),
                _AdminsPage(
                  admins: admins,
                  canManageAdmins: widget.canManageAdmins,
                  onOpenAddAdminSheet: () =>
                      _openAddAdminSheet(availableAdminUsers),
                  onRemoveAdmin: _removeAdmin,
                ),
                _MembersPage(
                  members: members,
                  canManageMembers: widget.canManageAdmins,
                  onRemoveMember: _removeMember,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openAddAdminSheet(List<SeatUser> availableAdminUsers) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.62,
        ),
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
              'Add Admin',
              style: TextStyle(
                color: RoomColors.plum,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Choose a real room user to promote as Admin.',
              style: TextStyle(
                color: Color(0xFF82758E),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (availableAdminUsers.isEmpty)
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
                  style: TextStyle(
                    color: Color(0xFF82758E),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: availableAdminUsers.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 7),
                  itemBuilder: (context, index) {
                    final user = availableAdminUsers[index];
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

class _RoomInfoTabs extends StatelessWidget {
  const _RoomInfoTabs({required this.selected, required this.onChanged});
  final _RoomInfoTab selected;
  final ValueChanged<_RoomInfoTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: RoomColors.pearl,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: RoomColors.softLine),
      ),
      child: Row(
        children: [
          _TabPill(
            label: 'Room info',
            tab: _RoomInfoTab.roomInfo,
            selected: selected,
            onChanged: onChanged,
          ),
          _TabPill(
            label: 'Admins',
            tab: _RoomInfoTab.admins,
            selected: selected,
            onChanged: onChanged,
          ),
          _TabPill(
            label: 'Room Members',
            tab: _RoomInfoTab.members,
            selected: selected,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.tab,
    required this.selected,
    required this.onChanged,
  });
  final String label;
  final _RoomInfoTab tab;
  final _RoomInfoTab selected;
  final ValueChanged<_RoomInfoTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final active = selected == tab;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => onChanged(tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? RoomColors.plum : const Color(0xFF82758E),
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _RoomInfoPage extends StatelessWidget {
  const _RoomInfoPage({
    required this.roomName,
    required this.roomId,
    required this.language,
    required this.privacyMode,
    required this.onCopyRoomId,
    required this.fallbackAnnouncement,
  });
  final String roomName;
  final String roomId;
  final String language;
  final RoomPrivacyMode privacyMode;
  final VoidCallback onCopyRoomId;
  final String fallbackAnnouncement;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        _InfoCard(
          icon: Icons.info_rounded,
          title: 'Room Details',
          child: Column(
            children: [
              _InfoRow(label: 'Room name', value: roomName),
              _InfoRowWithCopy(
                label: 'Room ID',
                value: roomId,
                onCopy: onCopyRoomId,
              ),
              _InfoRow(label: 'Language', value: language),
              _InfoRow(label: 'Mode', value: privacyMode.label),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _InfoCard(
          icon: Icons.campaign_rounded,
          title: 'Broad Announcement',
          child: ValueListenableBuilder<String>(
            valueListenable: roomBroadcastAnnouncementNotifier,
            builder: (context, announcement, child) {
              final cleanAnnouncement = announcement.trim().isEmpty
                  ? fallbackAnnouncement
                  : announcement.trim();
              return Text(
                cleanAnnouncement,
                style: const TextStyle(
                  color: Color(0xFF5D5068),
                  fontSize: 12.2,
                  fontWeight: FontWeight.w700,
                  height: 1.28,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AdminsPage extends StatelessWidget {
  const _AdminsPage({
    required this.admins,
    required this.canManageAdmins,
    required this.onOpenAddAdminSheet,
    required this.onRemoveAdmin,
  });
  final List<SeatUser> admins;
  final bool canManageAdmins;
  final VoidCallback onOpenAddAdminSheet;
  final ValueChanged<SeatUser> onRemoveAdmin;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (canManageAdmins) ...[
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Admins',
                  style: TextStyle(
                    color: RoomColors.plum,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _SmallActionPill(
                icon: Icons.person_add_alt_1_rounded,
                label: 'Add Admin',
                onTap: onOpenAddAdminSheet,
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Expanded(
          child: admins.isEmpty
              ? const _EmptyRoomInfoState(message: 'No admins found.')
              : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: admins.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 7),
                  itemBuilder: (context, index) {
                    final admin = admins[index];
                    return _AdminTile(
                      user: admin,
                      canManage: canManageAdmins && !admin.isHost,
                      onRemove: () => onRemoveAdmin(admin),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _MembersPage extends StatelessWidget {
  const _MembersPage({
    required this.members,
    required this.canManageMembers,
    required this.onRemoveMember,
  });
  final List<SeatUser> members;
  final bool canManageMembers;
  final ValueChanged<SeatUser> onRemoveMember;
  @override
  Widget build(BuildContext context) {
    if (members.isEmpty)
      return const _EmptyRoomInfoState(
        message: 'No approved room members yet.',
      );
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: members.length,
      separatorBuilder: (context, index) => const SizedBox(height: 7),
      itemBuilder: (context, index) {
        final member = members[index];
        return _MemberTile(
          user: member,
          canManage: canManageMembers,
          onRemove: () => onRemoveMember(member),
        );
      },
    );
  }
}

class _EmptyRoomInfoState extends StatelessWidget {
  const _EmptyRoomInfoState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: RoomColors.pearl,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: RoomColors.softLine),
    ),
    child: Text(
      message,
      style: const TextStyle(
        color: Color(0xFF82758E),
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.child,
  });
  final IconData icon;
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: RoomColors.pearl,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: RoomColors.softLine),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: RoomColors.aqua, size: 16),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                color: RoomColors.plum,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        child,
      ],
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF82758E),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: RoomColors.plum,
              fontSize: 12.2,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );
}

class _InfoRowWithCopy extends StatelessWidget {
  const _InfoRowWithCopy({
    required this.label,
    required this.value,
    required this.onCopy,
  });
  final String label;
  final String value;
  final VoidCallback onCopy;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF82758E),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RoomColors.plum,
                    fontSize: 12.2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onCopy,
                child: Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: RoomColors.softLine),
                  ),
                  child: const Icon(
                    Icons.copy_rounded,
                    size: 13,
                    color: RoomColors.plum,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _AdminTile extends StatelessWidget {
  const _AdminTile({
    required this.user,
    required this.canManage,
    required this.onRemove,
  });
  final SeatUser user;
  final bool canManage;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) => _UserTile(
    user: user,
    subtitle: user.isHost ? 'Channel Host' : 'Admin',
    trailing: canManage
        ? IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Remove admin',
            onPressed: onRemove,
            icon: const Icon(
              Icons.remove_circle_rounded,
              color: RoomColors.coral,
              size: 20,
            ),
          )
        : null,
  );
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.user,
    required this.canManage,
    required this.onRemove,
  });
  final SeatUser user;
  final bool canManage;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) => _UserTile(
    user: user,
    subtitle: 'Room Member',
    trailing: canManage
        ? IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Remove room member',
            onPressed: onRemove,
            icon: const Icon(
              Icons.remove_circle_rounded,
              color: RoomColors.coral,
              size: 20,
            ),
          )
        : null,
  );
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.subtitle, this.trailing});
  final SeatUser user;
  final String subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final avatarUrl = user.avatarUrl?.trim();
    final avatar = Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: user.avatarColors),
      ),
      child: Text(
        avatarLetter(user.name),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFAF6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: RoomColors.softLine),
      ),
      child: Row(
        children: [
          avatarUrl == null || avatarUrl.isEmpty
              ? avatar
              : ClipOval(
                  child: Image.network(
                    avatarUrl,
                    width: 38,
                    height: 38,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => avatar,
                  ),
                ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RoomColors.plum,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF82758E),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
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
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(18),
    onTap: onTap,
    child: _UserTile(
      user: user,
      subtitle: 'Eligible room user',
      trailing: const Icon(
        Icons.add_moderator_rounded,
        color: RoomColors.aqua,
        size: 21,
      ),
    ),
  );
}

class _SmallActionPill extends StatelessWidget {
  const _SmallActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
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
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
