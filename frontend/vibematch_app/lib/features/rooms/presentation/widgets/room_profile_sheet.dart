import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'room_theme.dart';

class UserMiniProfileSheet extends StatelessWidget {
  const UserMiniProfileSheet({
    super.key,
    required this.user,
    required this.currentUser,
    required this.canModerate,
    required this.onAvatarTap,
    required this.onVipTap,
    required this.onSendingLevelTap,
    required this.onReceivingLevelTap,
    required this.onSentRankingTap,
    required this.onReceivedRankingTap,
    required this.onFamilyTap,
    required this.onRelationshipTap,
    required this.onMedalsTap,
    required this.onMentionTap,
    required this.onSetAdminTap,
    required this.onLeaveAndLock,
    required this.onSelfMuteToggle,
    required this.onAdminMuteToggle,
    required this.onGiftTap,
  });

  final SeatUser user;
  final SeatUser currentUser;
  final bool canModerate;
  final VoidCallback onAvatarTap;
  final VoidCallback onVipTap;
  final VoidCallback onSendingLevelTap;
  final VoidCallback onReceivingLevelTap;
  final VoidCallback onSentRankingTap;
  final VoidCallback onReceivedRankingTap;
  final VoidCallback onFamilyTap;
  final VoidCallback onRelationshipTap;
  final VoidCallback onMedalsTap;
  final VoidCallback onMentionTap;
  final VoidCallback onSetAdminTap;
  final VoidCallback onLeaveAndLock;
  final VoidCallback onSelfMuteToggle;
  final VoidCallback onAdminMuteToggle;
  final VoidCallback onGiftTap;

  bool get _isSelf => user.id == currentUser.id;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.76),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(14, 58, 14, MediaQuery.paddingOf(context).bottom + 12),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(width: 70),
                    Expanded(
                      child: Text(
                        user.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: RoomColors.plum, fontSize: 19, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _CircleToolButton(icon: Icons.alternate_email_rounded, color: RoomColors.aqua, onTap: onMentionTap),
                    const SizedBox(width: 6),
                    _MoreMenuButton(canModerate: canModerate, isSelf: _isSelf, onSetAdminTap: onSetAdminTap),
                  ],
                ),
                const SizedBox(height: 7),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _TextPill(label: 'VIP ${user.vipLevel}', color: RoomColors.gold, onTap: onVipTap),
                    _TextPill(label: 'Lv ${user.sendingLevel}', color: RoomColors.violet, onTap: onSendingLevelTap),
                    _TextPill(label: 'Lv ${user.receivingLevel}', color: RoomColors.coral, onTap: onReceivingLevelTap),
                    _TextPill(
                      label: user.familyName.trim().isEmpty ? 'No Family' : user.familyName,
                      color: RoomColors.aqua,
                      onTap: onFamilyTap,
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                if (user.roleLabel.isNotEmpty)
                  Text(user.roleLabel, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _MonthStatCard(title: 'Sent', value: compactNumber(user.sentExp), color: const Color(0xFFEDEBFF), onTap: onSentRankingTap)),
                    const SizedBox(width: 8),
                    Expanded(child: _MonthStatCard(title: 'Received', value: compactNumber(user.receivedExp), color: const Color(0xFFFFEEF6), onTap: onReceivedRankingTap)),
                  ],
                ),
                const SizedBox(height: 9),
                _InfoCard(
                  title: 'Family',
                  value: user.familyName.trim().isEmpty ? 'Join or create a family' : user.familyName,
                  color: const Color(0xFFFFF8EA),
                  onTap: onFamilyTap,
                ),
                const SizedBox(height: 8),
                _InfoCard(title: 'Love & Bonds', value: user.relationshipText, color: const Color(0xFFFFEAF4), onTap: onRelationshipTap),
                const SizedBox(height: 8),
                _InfoCard(title: 'Medals', value: user.medals.isEmpty ? 'No medals yet' : user.medals.join('  '), color: const Color(0xFFF0EEFF), onTap: onMedalsTap),
                const SizedBox(height: 12),
                _ActionRow(
                  isSelf: _isSelf,
                  canModerate: canModerate,
                  selfMuted: user.selfMuted,
                  adminMuted: user.adminMuted,
                  onLeaveAndLock: onLeaveAndLock,
                  onSelfMuteToggle: onSelfMuteToggle,
                  onAdminMuteToggle: onAdminMuteToggle,
                  onGiftTap: onGiftTap,
                  onProfileTap: onAvatarTap,
                ),
              ],
            ),
          ),
          Positioned(top: -38, child: _ProfileAvatar(user: user, onTap: onAvatarTap)),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.user, required this.onTap});

  final SeatUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 82,
        height: 82,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 14, offset: const Offset(0, 7))],
        ),
        child: Container(
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: user.avatarColors)),
          alignment: Alignment.center,
          child: Text(avatarLetter(user.name), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }
}

class _CircleToolButton extends StatelessWidget {
  const _CircleToolButton({required this.icon, required this.color, required this.onTap});

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 34, height: 34, child: Icon(icon, color: color, size: 18)),
      ),
    );
  }
}

class _MoreMenuButton extends StatelessWidget {
  const _MoreMenuButton({required this.canModerate, required this.isSelf, required this.onSetAdminTap});

  final bool canModerate;
  final bool isSelf;
  final VoidCallback onSetAdminTap;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'More',
      onSelected: (value) {
        if (value == 'set_admin') onSetAdminTap();
      },
      itemBuilder: (context) => [
        if (canModerate && !isSelf)
          const PopupMenuItem<String>(
            value: 'set_admin',
            child: Row(
              children: [
                Icon(Icons.shield_rounded, size: 18, color: RoomColors.aqua),
                SizedBox(width: 8),
                Text('Set as admin'),
              ],
            ),
          ),
      ],
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(color: RoomColors.plum.withValues(alpha: 0.08), shape: BoxShape.circle),
        child: const Icon(Icons.more_horiz_rounded, color: RoomColors.plum, size: 20),
      ),
    );
  }
}

class _TextPill extends StatelessWidget {
  const _TextPill({required this.label, required this.color, required this.onTap});

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.20)),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _MonthStatCard extends StatelessWidget {
  const _MonthStatCard({required this.title, required this.value, required this.color, required this.onTap});

  final String title;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(color: RoomColors.plum, fontSize: 15, fontWeight: FontWeight.w900)),
        ]),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.value, required this.color, required this.onTap});

  final String title;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16), border: Border.all(color: RoomColors.softLine)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: RoomColors.plum, fontSize: 13, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w800)),
          ])),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF96899F), size: 20),
        ]),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.isSelf,
    required this.canModerate,
    required this.selfMuted,
    required this.adminMuted,
    required this.onLeaveAndLock,
    required this.onSelfMuteToggle,
    required this.onAdminMuteToggle,
    required this.onGiftTap,
    required this.onProfileTap,
  });

  final bool isSelf;
  final bool canModerate;
  final bool selfMuted;
  final bool adminMuted;
  final VoidCallback onLeaveAndLock;
  final VoidCallback onSelfMuteToggle;
  final VoidCallback onAdminMuteToggle;
  final VoidCallback onGiftTap;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      _ActionChip(icon: Icons.person_rounded, label: 'Profile', onTap: onProfileTap),
      _ActionChip(icon: Icons.card_giftcard_rounded, label: 'Gift', onTap: onGiftTap),
      if (isSelf) _ActionChip(icon: selfMuted ? Icons.mic_rounded : Icons.mic_off_rounded, label: selfMuted ? 'Turn on' : 'Turn off', onTap: onSelfMuteToggle),
      if (canModerate && !isSelf) _ActionChip(icon: adminMuted ? Icons.mic_rounded : Icons.admin_panel_settings_rounded, label: adminMuted ? 'Unmute' : 'Admin mute', onTap: onAdminMuteToggle),
      if (isSelf || canModerate) _ActionChip(icon: Icons.lock_rounded, label: 'Leave & Lock', onTap: onLeaveAndLock),
    ];
    return Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: actions);
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(color: RoomColors.plum.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(999), border: Border.all(color: RoomColors.softLine)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: RoomColors.plum, size: 15),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: RoomColors.plum, fontSize: 11, fontWeight: FontWeight.w900)),
        ]),
      ),
    );
  }
}
