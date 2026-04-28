import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'mini_profile_decoration.dart';
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
      maxHeightFactor: 0.66,
      topRadius: 26,
      backgroundColor: const Color(0xFFFDFBF7),
      showTopGlow: false,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              14,
              52,
              14,
              MediaQuery.paddingOf(context).bottom + 12,
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 32,
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
                          padding: const EdgeInsets.symmetric(horizontal: 46),
                          child: Text(
                            user.name,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: RoomColors.plum,
                              fontSize: 18,
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
                          size: 32,
                          iconSize: 17,
                          onTap: onMentionTap,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 7),
                _LevelRow(
                  user: user,
                  onVipTap: onVipTap,
                  onSendingLevelTap: onSendingLevelTap,
                  onReceivingLevelTap: onReceivingLevelTap,
                ),
                const SizedBox(height: 8),
                _MetaRow(user: user),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _VipStatCard(
                        vipLevel: user.vipLevel,
                        onTap: onVipTap,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MonthStatCard(
                        title: 'Sent',
                        value: compactNumber(user.sentExp),
                        onTap: onSentRankingTap,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MonthStatCard(
                        title: 'Received',
                        value: compactNumber(user.receivedExp),
                        onTap: onReceivedRankingTap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _FamilyInfoCard(user: user, onTap: onFamilyTap),
                const SizedBox(height: 7),
                _InfoCard(
                  icon: Icons.favorite_rounded,
                  title: 'Love & Bonds',
                  value: user.relationshipText.trim().isEmpty ? 'No active bonds yet' : user.relationshipText,
                  onTap: onRelationshipTap,
                ),
                const SizedBox(height: 7),
                _BadgesInfoCard(user: user, onTap: onMedalsTap),
                const SizedBox(height: 10),
                _ActionRow(
                  isSelf: _isSelf,
                  canModerate: canModerate,
                  selfMuted: user.selfMuted,
                  adminMuted: user.adminMuted,
                  onLeaveAndLock: onLeaveAndLock,
                  onSelfMuteToggle: onSelfMuteToggle,
                  onAdminMuteToggle: onAdminMuteToggle,
                  onGiftTap: onGiftTap,
                ),
              ],
            ),
          ),
          Positioned(
            top: -32,
            child: MiniProfileAvatarDecoration(
              user: user,
              onTap: onAvatarTap,
              size: 66,
              showHeartBadge: false,
              showOnlineRing: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({
    required this.user,
    required this.onVipTap,
    required this.onSendingLevelTap,
    required this.onReceivingLevelTap,
  });

  final SeatUser user;
  final VoidCallback onVipTap;
  final VoidCallback onSendingLevelTap;
  final VoidCallback onReceivingLevelTap;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      if (user.svipLevel > 0)
        _CleanLevelPill(
          label: 'SVIP ${user.svipLevel}',
          icon: Icons.diamond_rounded,
          width: 76,
          background: const Color(0xFF30220B),
          border: const Color(0xFFD7AA45),
          textColor: const Color(0xFFFFE2A1),
          shineColor: const Color(0xFFFFF1B8),
          active: true,
          onTap: onVipTap,
        ),
      _CleanLevelPill(
        label: 'Lv ${user.sendingLevel}',
        icon: Icons.north_east_rounded,
        width: 68,
        background: const Color(0xFF241E45),
        border: const Color(0xFF7364D9),
        textColor: const Color(0xFFEDEAFF),
        shineColor: const Color(0xFFC9C2FF),
        active: user.sendingLevel > 0,
        onTap: onSendingLevelTap,
      ),
      _CleanLevelPill(
        label: 'Lv ${user.receivingLevel}',
        icon: Icons.favorite_rounded,
        width: 68,
        background: const Color(0xFFFFDCEB),
        border: const Color(0xFFE26A98),
        textColor: const Color(0xFF661C3B),
        shineColor: const Color(0xFFFFF0F7),
        active: user.receivingLevel > 0,
        onTap: onReceivingLevelTap,
      ),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i != 0) const SizedBox(width: 6),
          items[i],
        ],
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.user});

  final SeatUser user;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 5,
      children: [
        if (user.roleLabel.isNotEmpty)
          _MetaPill(icon: Icons.shield_rounded, label: user.roleLabel),
        if (user.showLocation) _LocationPill(location: user.locationLabel!),
        _GenderAgePill(user: user),
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
      size: 32,
      iconSize: 17,
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
      offset: const Offset(0, 34),
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
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: RoomColors.plum.withValues(alpha: 0.07), shape: BoxShape.circle),
        child: const Icon(Icons.more_horiz_rounded, color: RoomColors.plum, size: 20),
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

class _CleanLevelPill extends StatelessWidget {
  const _CleanLevelPill({
    required this.label,
    required this.icon,
    required this.width,
    required this.background,
    required this.border,
    required this.textColor,
    required this.onTap,
    required this.shineColor,
    this.active = true,
  });

  final String label;
  final IconData icon;
  final double width;
  final Color background;
  final Color border;
  final Color textColor;
  final VoidCallback onTap;
  final Color shineColor;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final effectiveBackground = active ? background : const Color(0xFFE6E1E8);
    final effectiveBorder = active ? border : const Color(0xFFC7BEC9);
    final effectiveTextColor = active ? textColor : const Color(0xFF8D8392);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: width,
        height: 26,
        decoration: BoxDecoration(
          color: effectiveBackground,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: effectiveBorder.withValues(alpha: active ? 0.72 : 0.65), width: 0.8),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: effectiveBorder.withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 8,
                right: 8,
                top: 3,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: Colors.white.withValues(alpha: active ? 0.18 : 0.22),
                  ),
                ),
              ),
              if (active) _PillShine(color: shineColor),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: effectiveTextColor, size: 11.5),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: effectiveTextColor,
                        fontSize: 10.2,
                        fontWeight: FontWeight.w900,
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

class _PillShine extends StatefulWidget {
  const _PillShine({required this.color});

  final Color color;

  @override
  State<_PillShine> createState() => _PillShineState();
}

class _PillShineState extends State<_PillShine> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1850),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final x = -0.65 + (_controller.value * 1.65);
        return Positioned.fill(
          child: Transform.translate(
            offset: Offset(x * 82, 0),
            child: Transform.rotate(
              angle: -0.42,
              child: Center(
                child: Container(
                  width: 13,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.color.withValues(alpha: 0.0),
                        widget.color.withValues(alpha: 0.36),
                        Colors.white.withValues(alpha: 0.52),
                        widget.color.withValues(alpha: 0.22),
                        widget.color.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GenderAgePill extends StatelessWidget {
  const _GenderAgePill({required this.user});

  final SeatUser user;

  @override
  Widget build(BuildContext context) {
    final label = user.age == null ? 'Age hidden' : '${user.age}';
    return _MetaPill(icon: user.gender.icon, label: label, color: user.gender.color);
  }
}

class _LocationPill extends StatelessWidget {
  const _LocationPill({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 150),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: RoomColors.aqua.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: RoomColors.aqua.withValues(alpha: 0.14)),
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
                style: const TextStyle(color: RoomColors.plum, fontSize: 10.5, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label, this.color = RoomColors.plum});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 130),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 12.5),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VipStatCard extends StatelessWidget {
  const _VipStatCard({required this.vipLevel, required this.onTap});

  final int vipLevel;
  final VoidCallback onTap;

  static const String _assetBase = 'assets/images/vip_badges';

  String get _assetPath {
    if (vipLevel >= 41) return '$_assetBase/vip_purple.png';
    if (vipLevel >= 30) return '$_assetBase/vip_green.png';
    if (vipLevel >= 21) return '$_assetBase/vip_blue.png';
    if (vipLevel >= 11) return '$_assetBase/vip_red.png';
    if (vipLevel >= 6) return '$_assetBase/vip_black_gold.png';
    return '$_assetBase/vip_silver.png';
  }

  Color get _accentColor {
    if (vipLevel >= 41) return const Color(0xFF9C3BCE);
    if (vipLevel >= 30) return const Color(0xFF0F9A5A);
    if (vipLevel >= 21) return const Color(0xFF0C78CF);
    if (vipLevel >= 11) return const Color(0xFFD33B47);
    if (vipLevel >= 6) return const Color(0xFFC99A3B);
    return const Color(0xFF89909A);
  }

  Color get _tintColor {
    if (vipLevel >= 41) return const Color(0xFFF6E9FF);
    if (vipLevel >= 30) return const Color(0xFFE8FFF3);
    if (vipLevel >= 21) return const Color(0xFFEAF6FF);
    if (vipLevel >= 11) return const Color(0xFFFFECEF);
    if (vipLevel >= 6) return const Color(0xFFFFF7E3);
    return const Color(0xFFF2F4F7);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: _tintColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _accentColor.withValues(alpha: 0.20)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'VIP Level',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFF7B7282),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    _assetPath,
                    width: 31,
                    height: 31,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.shield_rounded,
                        color: _accentColor,
                        size: 28,
                      );
                    },
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'VIP $vipLevel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _accentColor,
                      fontSize: 14.2,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthStatCard extends StatelessWidget {
  const _MonthStatCard({required this.title, required this.value, required this.onTap});

  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: RoomColors.softLine),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF7B7282), fontSize: 10.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(value, textAlign: TextAlign.center, style: const TextStyle(color: RoomColors.plum, fontSize: 15, fontWeight: FontWeight.w900)),
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

    return _CleanInfoCard(
      iconWidget: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(colors: user.avatarColors),
        ),
        child: const Icon(Icons.groups_rounded, color: Colors.white, size: 18),
      ),
      title: 'Family',
      value: familyName,
      onTap: onTap,
    );
  }
}

class _BadgesInfoCard extends StatelessWidget {
  const _BadgesInfoCard({required this.user, required this.onTap});

  final SeatUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final badges = user.medals.isEmpty ? '—' : user.medals.join('   ');

    return _CleanInfoCard(
      iconWidget: const Icon(Icons.military_tech_rounded, color: RoomColors.gold, size: 20),
      title: 'Badges',
      valueWidget: Align(
        alignment: Alignment.centerRight,
        child: Text(
          badges,
          textAlign: TextAlign.right,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFF675C70), fontSize: 13, fontWeight: FontWeight.w900),
        ),
      ),
      onTap: onTap,
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.title, required this.value, required this.onTap});

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _CleanInfoCard(
      iconWidget: Icon(icon, color: RoomColors.coral, size: 19),
      title: title,
      value: value,
      onTap: onTap,
    );
  }
}

class _CleanInfoCard extends StatelessWidget {
  const _CleanInfoCard({
    required this.iconWidget,
    required this.title,
    this.value,
    this.valueWidget,
    required this.onTap,
  });

  final Widget iconWidget;
  final String title;
  final String? value;
  final Widget? valueWidget;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MiniProfileSectionCard(
      backgroundColor: Colors.white,
      borderColor: RoomColors.softLine,
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(width: 36, child: Center(child: iconWidget)),
          const SizedBox(width: 9),
          Expanded(
            flex: valueWidget == null ? 1 : 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: RoomColors.plum, fontSize: 12.5, fontWeight: FontWeight.w900)),
                if (value != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF736878), fontSize: 11.2, fontWeight: FontWeight.w700),
                  ),
                ],
              ],
            ),
          ),
          if (valueWidget != null) ...[
            const Spacer(),
            SizedBox(width: 92, child: valueWidget!),
          ],
          const SizedBox(width: 5),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFFB3A9B9), size: 19),
        ],
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
  });

  final bool isSelf;
  final bool canModerate;
  final bool selfMuted;
  final bool adminMuted;
  final VoidCallback onLeaveAndLock;
  final VoidCallback onSelfMuteToggle;
  final VoidCallback onAdminMuteToggle;
  final VoidCallback onGiftTap;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
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
    return Wrap(spacing: 12, runSpacing: 10, alignment: WrapAlignment.center, children: actions);
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
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: RoomColors.softLine),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 9,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: RoomColors.plum, size: 18),
        ),
      ),
    );
  }
}
