import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'mini_profile_decoration.dart';
import 'room_theme.dart';
import 'vip_badge.dart';

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
    required this.onRemoveAdminTap,
    required this.onReportTap,
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
  final VoidCallback onRemoveAdminTap;
  final VoidCallback onReportTap;
  final VoidCallback onLeaveAndLock;
  final VoidCallback onSelfMuteToggle;
  final VoidCallback onAdminMuteToggle;
  final VoidCallback onGiftTap;

  bool get _isSelf => user.id == currentUser.id;
  bool get _showAdminMenu => canModerate && !_isSelf;

  @override
  Widget build(BuildContext context) {
    return MiniProfileDecoration(
      maxHeightFactor: 0.80,
      backgroundColor: const Color(0xFFFCFAF7),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              14,
              58,
              14,
              MediaQuery.paddingOf(context).bottom + 12,
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 38,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _showAdminMenu
                            ? _MoreMenuButton(
                                user: user,
                                onSetAdminTap: onSetAdminTap,
                                onRemoveAdminTap: onRemoveAdminTap,
                                onReportTap: onReportTap,
                              )
                            : _ReportIconButton(onTap: onReportTap),
                      ),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 48),
                          child: Text(
                            user.name,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: RoomColors.plum,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: MiniProfileCornerButton(
                          icon: Icons.alternate_email_rounded,
                          color: RoomColors.aqua,
                          onTap: onMentionTap,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    VipBadge(level: user.vipLevel, size: VipBadgeSize.medium, onTap: onVipTap),
                    if (user.svipLevel > 0)
                      _GlassyLevelPill(
                        label: 'SVIP ${user.svipLevel}',
                        icon: Icons.diamond_rounded,
                        width: 78,
                        gradient: const [
                          Color(0xFFFFF3BA),
                          Color(0xFFFFD35A),
                          Color(0xFF9E6D00),
                        ],
                        textColor: const Color(0xFF3E2700),
                        onTap: onVipTap,
                      ),
                    _GlassyLevelPill(
                      label: 'Lv ${user.sendingLevel}',
                      icon: Icons.north_east_rounded,
                      width: 70,
                      gradient: const [
                        Color(0xFFEFEAFF),
                        Color(0xFF8C5CF6),
                        Color(0xFF12C7B7),
                      ],
                      textColor: Colors.white,
                      onTap: onSendingLevelTap,
                    ),
                    _GlassyLevelPill(
                      label: 'Lv ${user.receivingLevel}',
                      icon: Icons.favorite_rounded,
                      width: 70,
                      gradient: const [
                        Color(0xFFFFEAF3),
                        Color(0xFFFF6B9A),
                        Color(0xFFE84C72),
                      ],
                      textColor: Colors.white,
                      onTap: onReceivingLevelTap,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _MetaRow(user: user),
                if (user.showLocation) ...[
                  const SizedBox(height: 7),
                  _LocationPill(location: user.locationLabel!),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MonthStatCard(
                        title: 'Sent',
                        value: compactNumber(user.sentExp),
                        color: const Color(0xFFEDEBFF),
                        onTap: onSentRankingTap,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MonthStatCard(
                        title: 'Received',
                        value: compactNumber(user.receivedExp),
                        color: const Color(0xFFFFEEF6),
                        onTap: onReceivedRankingTap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                _FamilyInfoCard(user: user, onTap: onFamilyTap),
                const SizedBox(height: 8),
                _InfoCard(
                  title: 'Love & Bonds',
                  value: user.relationshipText.trim().isEmpty ? 'No active bonds yet' : user.relationshipText,
                  color: const Color(0xFFFFEAF4),
                  onTap: onRelationshipTap,
                ),
                const SizedBox(height: 8),
                _BadgesInfoCard(user: user, onTap: onMedalsTap),
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
          Positioned(
            top: -40,
            child: MiniProfileAvatarDecoration(user: user, onTap: onAvatarTap),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.user});

  final SeatUser user;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (user.roleLabel.isNotEmpty)
          Flexible(
            fit: FlexFit.tight,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _RolePill(label: user.roleLabel),
            ),
          )
        else
          const Spacer(),
        Flexible(
          fit: FlexFit.tight,
          child: Align(
            alignment: Alignment.centerRight,
            child: _GenderAgePill(user: user),
          ),
        ),
      ],
    );
  }
}

class _ReportIconButton extends StatelessWidget {
  const _ReportIconButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MiniProfileCornerButton(
      icon: Icons.report_gmailerrorred_rounded,
      color: RoomColors.coral,
      onTap: onTap,
    );
  }
}

class _MoreMenuButton extends StatelessWidget {
  const _MoreMenuButton({
    required this.user,
    required this.onSetAdminTap,
    required this.onRemoveAdminTap,
    required this.onReportTap,
  });

  final SeatUser user;
  final VoidCallback onSetAdminTap;
  final VoidCallback onRemoveAdminTap;
  final VoidCallback onReportTap;

  @override
  Widget build(BuildContext context) {
    final canRemoveAdmin = user.isRoomAdmin && !user.isHost;

    return PopupMenuButton<String>(
      tooltip: 'More',
      offset: const Offset(0, 38),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      onSelected: (value) {
        if (value == 'set_admin') onSetAdminTap();
        if (value == 'remove_admin') onRemoveAdminTap();
        if (value == 'report') onReportTap();
      },
      itemBuilder: (context) => [
        if (canRemoveAdmin)
          const PopupMenuItem<String>(
            value: 'remove_admin',
            child: _MenuRow(icon: Icons.shield_moon_rounded, color: RoomColors.coral, label: 'Remove admin'),
          )
        else if (!user.isRoomAdmin && !user.isHost)
          const PopupMenuItem<String>(
            value: 'set_admin',
            child: _MenuRow(icon: Icons.shield_rounded, color: RoomColors.aqua, label: 'Set as admin'),
          ),
        const PopupMenuItem<String>(
          value: 'report',
          child: _MenuRow(icon: Icons.report_gmailerrorred_rounded, color: RoomColors.coral, label: 'Report'),
        ),
      ],
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: RoomColors.plum.withValues(alpha: 0.08), shape: BoxShape.circle),
        child: const Icon(Icons.more_horiz_rounded, color: RoomColors.plum, size: 22),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.color, required this.label});

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 9),
        Text(label, style: const TextStyle(color: RoomColors.plum, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _GlassyLevelPill extends StatelessWidget {
  const _GlassyLevelPill({
    required this.label,
    required this.icon,
    required this.width,
    required this.gradient,
    required this.textColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final double width;
  final List<Color> gradient;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: width,
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.42), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: gradient.last.withValues(alpha: 0.22),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 9,
                right: 9,
                top: 3,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.46),
                        Colors.white.withValues(alpha: 0.12),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: textColor, size: 12),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: textColor == Colors.white ? 0.24 : 0.08),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenderAgePill extends StatelessWidget {
  const _GenderAgePill({required this.user});

  final SeatUser user;

  @override
  Widget build(BuildContext context) {
    final label = user.age == null ? 'Age hidden' : '${user.age}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: user.gender.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: user.gender.color.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(user.gender.icon, color: user.gender.color, size: 13),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: user.gender.color, fontSize: 10.5, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _LocationPill extends StatelessWidget {
  const _LocationPill({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: RoomColors.aqua.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: RoomColors.aqua.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on_rounded, color: RoomColors.aqua, size: 13),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              location,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: RoomColors.plum, fontSize: 10.5, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: RoomColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: RoomColors.gold.withValues(alpha: 0.20)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: RoomColors.plum, fontSize: 10.5, fontWeight: FontWeight.w900),
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
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(value, textAlign: TextAlign.center, style: const TextStyle(color: RoomColors.plum, fontSize: 16, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _FamilyInfoCard extends StatelessWidget {
  const _FamilyInfoCard({required this.user, required this.onTap});

  final SeatUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final familyName = user.familyName.trim().isEmpty ? 'Join or create a family' : user.familyName;

    return MiniProfileSectionCard(
      backgroundColor: const Color(0xFFFFF8EA),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              gradient: LinearGradient(colors: user.avatarColors),
              boxShadow: [
                BoxShadow(
                  color: RoomColors.gold.withValues(alpha: 0.16),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(Icons.groups_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Family', style: TextStyle(color: RoomColors.plum, fontSize: 13, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(
                  familyName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF96899F), size: 20),
        ],
      ),
    );
  }
}

class _BadgesInfoCard extends StatelessWidget {
  const _BadgesInfoCard({required this.user, required this.onTap});

  final SeatUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final badges = user.medals.isEmpty ? 'No badges yet' : user.medals.join('  ');

    return MiniProfileSectionCard(
      backgroundColor: const Color(0xFFF0EEFF),
      onTap: onTap,
      child: Row(
        children: [
          const Expanded(
            child: Text('Badges', style: TextStyle(color: RoomColors.plum, fontSize: 13, fontWeight: FontWeight.w900)),
          ),
          Flexible(
            child: Text(
              badges,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 13, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 5),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF96899F), size: 20),
        ],
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
    return MiniProfileSectionCard(
      backgroundColor: color,
      onTap: onTap,
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: RoomColors.plum, fontSize: 13, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w800)),
        ])),
        const Icon(Icons.chevron_right_rounded, color: Color(0xFF96899F), size: 20),
      ]),
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
      _IconActionChip(icon: Icons.person_rounded, tooltip: 'Profile', onTap: onProfileTap),
      _IconActionChip(icon: Icons.card_giftcard_rounded, tooltip: 'Gift', onTap: onGiftTap),
      if (isSelf)
        _IconActionChip(
          icon: selfMuted ? Icons.mic_rounded : Icons.mic_off_rounded,
          tooltip: selfMuted ? 'Turn on mic' : 'Turn off mic',
          onTap: onSelfMuteToggle,
        ),
      if (canModerate && !isSelf)
        _IconActionChip(
          icon: adminMuted ? Icons.mic_rounded : Icons.admin_panel_settings_rounded,
          tooltip: adminMuted ? 'Unmute' : 'Admin mute',
          onTap: onAdminMuteToggle,
        ),
      if (isSelf || canModerate)
        _IconActionChip(icon: Icons.lock_rounded, tooltip: 'Leave and lock', onTap: onLeaveAndLock),
    ];
    return Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: actions);
  }
}

class _IconActionChip extends StatelessWidget {
  const _IconActionChip({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: RoomColors.plum.withValues(alpha: 0.07),
            shape: BoxShape.circle,
            border: Border.all(color: RoomColors.softLine),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: RoomColors.plum, size: 19),
        ),
      ),
    );
  }
}
