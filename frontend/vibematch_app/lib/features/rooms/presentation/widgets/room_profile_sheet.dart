import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'mini_profile_decoration.dart';
import 'room_profile_action_row.dart';
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
    required this.onLeaveSeatOnly,
    required this.onSelfMuteToggle,
    required this.onAdminMuteToggle,
    required this.onGiftTap,
    this.onKickOutTap,
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
  final VoidCallback onLeaveSeatOnly;
  final VoidCallback onSelfMuteToggle;
  final VoidCallback onAdminMuteToggle;
  final VoidCallback onGiftTap;
  final VoidCallback? onKickOutTap;

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
                _HeaderRow(
                  user: user,
                  showAdminMenu: _showAdminMenu,
                  onMentionTap: onMentionTap,
                  onReportTap: onReportTap,
                  onSetAdminTap: onSetAdminTap,
                  onRemoveAdminTap: onRemoveAdminTap,
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
                        tint: const Color(0xFFEFF7FF),
                        borderColor: const Color(0xFFC8DEF3),
                        titleColor: const Color(0xFF6B8198),
                        valueColor: const Color(0xFF326B9E),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MonthStatCard(
                        title: 'Received',
                        value: compactNumber(user.receivedExp),
                        onTap: onReceivedRankingTap,
                        tint: const Color(0xFFFFEEF5),
                        borderColor: const Color(0xFFF3D3DF),
                        titleColor: const Color(0xFF9A7483),
                        valueColor: const Color(0xFFC45A80),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _ActionRow(
                  isSelf: _isSelf,
                  canModerate: canModerate,
                  selfMuted: user.selfMuted,
                  adminMuted: user.adminMuted,
                  onLeaveAndLock: onLeaveAndLock,
                  onLeaveSeatOnly: onLeaveSeatOnly,
                  onSelfMuteToggle: onSelfMuteToggle,
                  onAdminMuteToggle: onAdminMuteToggle,
                  onGiftTap: onGiftTap,
                  onKickOutTap: onKickOutTap,
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

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.user,
    required this.showAdminMenu,
    required this.onMentionTap,
    required this.onReportTap,
    required this.onSetAdminTap,
    required this.onRemoveAdminTap,
  });

  final SeatUser user;
  final bool showAdminMenu;
  final VoidCallback onMentionTap;
  final VoidCallback onReportTap;
  final VoidCallback onSetAdminTap;
  final VoidCallback onRemoveAdminTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: showAdminMenu
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
        icon: Icons.emoji_events_rounded,
        width: 68,
        background: const Color(0xFFEFF3FF),
        border: const Color(0xFF91A9E8),
        textColor: const Color(0xFF465B9D),
        shineColor: Colors.white,
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
      spacing: 4,
      runSpacing: 4,
      children: [
        if (user.roleLabel.isNotEmpty)
          _MetaPill(icon: Icons.shield_rounded, label: user.roleLabel),
        if (user.familyName.trim().isNotEmpty) _FamilyTagPill(user: user),
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
            child: _MenuRow(
              icon: Icons.shield_moon_rounded,
              color: RoomColors.coral,
              label: 'Remove admin',
            ),
          )
        else if (!user.isRoomAdmin && !user.isHost)
          const PopupMenuItem<String>(
            value: 'set_admin',
            child: _MenuRow(
              icon: Icons.shield_rounded,
              color: RoomColors.aqua,
              label: 'Set as admin',
            ),
          ),
        const PopupMenuItem<String>(
          value: 'report',
          child: _MenuRow(
            icon: Icons.report_gmailerrorred_rounded,
            color: RoomColors.coral,
            label: 'Report',
          ),
        ),
      ],
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: RoomColors.plum.withValues(alpha: 0.07),
          shape: BoxShape.circle,
        ),
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
          border: Border.all(
            color: effectiveBorder.withValues(alpha: active ? 0.72 : 0.65),
            width: 0.8,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: effectiveBorder.withValues(alpha: 0.12),
                    blurRadius: 8,
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
                    color: Colors.white.withValues(alpha: active ? 0.28 : 0.22),
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
                        widget.color.withValues(alpha: 0.28),
                        Colors.white.withValues(alpha: 0.40),
                        widget.color.withValues(alpha: 0.18),
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
    return _MetaPill(
      icon: user.gender.icon,
      label: label,
      color: user.gender.color,
    );
  }
}

class _FamilyTagPill extends StatelessWidget {
  const _FamilyTagPill({required this.user});

  final SeatUser user;

  String get _familyName {
    final clean = user.familyName.trim();
    if (clean.isEmpty) return 'Family';
    return clean;
  }

  String get _level {
    final raw = user.familyLevel.trim().toLowerCase();
    if (raw.contains('platinum')) return 'platinum';
    if (raw.contains('gold')) return 'gold';
    if (raw.contains('silver')) return 'silver';
    return 'bronze';
  }

  _FamilyTagStyle get _style {
    switch (_level) {
      case 'platinum':
        return const _FamilyTagStyle(
          assetPath: 'assets/images/family_badges/platinum.png',
          top: Color(0xFF768292),
          bottom: Color(0xFF485260),
          border: Color(0xFFE8EEF6),
          text: Color(0xFFFDFEFF),
          shine: Color(0xFFFFFFFF),
          glow: Color(0xFFDDE6F3),
          shineAlpha: 0.56,
          glowAlpha: 0.26,
          durationMs: 1050,
        );
      case 'gold':
        return const _FamilyTagStyle(
          assetPath: 'assets/images/family_badges/gold.png',
          top: Color(0xFFE0B12F),
          bottom: Color(0xFF8D6508),
          border: Color(0xFFFFE28A),
          text: Color(0xFFFFF8DB),
          shine: Color(0xFFFFF2B0),
          glow: Color(0xFFFFD96A),
          shineAlpha: 0.40,
          glowAlpha: 0.18,
          durationMs: 1380,
        );
      case 'silver':
        return const _FamilyTagStyle(
          assetPath: 'assets/images/family_badges/silver.png',
          top: Color(0xFFD4D9DF),
          bottom: Color(0xFF87919C),
          border: Color(0xFFF0F4F8),
          text: Color(0xFFFBFDFF),
          shine: Color(0xFFFFFFFF),
          glow: Color(0xFFD6DDE5),
          shineAlpha: 0.28,
          glowAlpha: 0.12,
          durationMs: 1720,
        );
      default:
        return const _FamilyTagStyle(
          assetPath: 'assets/images/family_badges/bronze.png',
          top: Color(0xFFC08A5A),
          bottom: Color(0xFF7A4E2D),
          border: Color(0xFFDCA477),
          text: Color(0xFFFFE8D5),
          shine: Color(0xFFFFD8BA),
          glow: Color(0xFFC68E61),
          shineAlpha: 0.16,
          glowAlpha: 0.08,
          durationMs: 2100,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _style;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 150),
      child: IntrinsicWidth(
        child: SizedBox(
          height: 22,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 13,
                top: 1,
                bottom: 1,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 74, maxWidth: 137),
                                  decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [style.top, style.bottom],
                  ),
                  border: Border.all(
                    color: style.border.withValues(alpha: 0.82),
                    width: 0.85,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: style.glow.withValues(alpha: style.glowAlpha),
                      blurRadius: _level == 'platinum' ? 12 : 7,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 16,
                        right: 8,
                        top: 2,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: Colors.white.withValues(
                              alpha: _level == 'platinum' ? 0.22 : 0.12,
                            ),
                          ),
                        ),
                      ),
                      _FamilyTagShine(style: style),
                      Padding(
                        padding: const EdgeInsets.only(left: 20, right: 10),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          widthFactor: 1,
                          child: Text(
                            _familyName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: style.text,
                              fontSize: 9.0,
                              fontWeight: FontWeight.w900,
                              height: 1,
                              letterSpacing: -0.08,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: -3,
              child: Image.asset(
                style.assetPath,
                width: 28,
                height: 28,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: style.top,
                      border: Border.all(color: style.border, width: 0.8),
                    ),
                    child: Text(
                      _familyName.characters.first.toUpperCase(),
                      style: TextStyle(
                        color: style.text,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  );
                },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FamilyTagStyle {
  const _FamilyTagStyle({
    required this.assetPath,
    required this.top,
    required this.bottom,
    required this.border,
    required this.text,
    required this.shine,
    required this.glow,
    required this.shineAlpha,
    required this.glowAlpha,
    required this.durationMs,
  });

  final String assetPath;
  final Color top;
  final Color bottom;
  final Color border;
  final Color text;
  final Color shine;
  final Color glow;
  final double shineAlpha;
  final double glowAlpha;
  final int durationMs;
}

class _FamilyTagShine extends StatefulWidget {
  const _FamilyTagShine({required this.style});

  final _FamilyTagStyle style;

  @override
  State<_FamilyTagShine> createState() => _FamilyTagShineState();
}

class _FamilyTagShineState extends State<_FamilyTagShine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.style.durationMs),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant _FamilyTagShine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.style.durationMs != widget.style.durationMs) {
      _controller.duration = Duration(milliseconds: widget.style.durationMs);
      _controller
        ..reset()
        ..repeat();
    }
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
        final x = -0.85 + (_controller.value * 2.0);
        return Positioned.fill(
          child: IgnorePointer(
            child: Transform.translate(
              offset: Offset(x * 105, 0),
              child: Transform.rotate(
                angle: -0.45,
                child: Center(
                  child: Container(
                    width: 14,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          widget.style.shine.withValues(alpha: 0.0),
                          widget.style.shine.withValues(
                            alpha: widget.style.shineAlpha * 0.45,
                          ),
                          widget.style.shine.withValues(
                            alpha: widget.style.shineAlpha,
                          ),
                          widget.style.shine.withValues(
                            alpha: widget.style.shineAlpha * 0.45,
                          ),
                          widget.style.shine.withValues(alpha: 0.0),
                        ],
                      ),
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

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
    this.color = RoomColors.plum,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 104),
      child: Container(
        height: 21,
        padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 0),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 10.5),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 9.0,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
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
    if (vipLevel >= 41) return const Color(0xFFF5EBFF);
    if (vipLevel >= 30) return const Color(0xFFE8F8EF);
    if (vipLevel >= 21) return const Color(0xFFEAF4FF);
    if (vipLevel >= 11) return const Color(0xFFFFECEF);
    if (vipLevel >= 6) return const Color(0xFFFFF7E8);
    return const Color(0xFFF2F4F7);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _tintColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _accentColor.withValues(alpha: 0.22)),
          boxShadow: [
            BoxShadow(
              color: _accentColor.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              const _MiniStatCardShine(),
              Column(
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
                  Center(
                    child: Transform.translate(
                      offset: const Offset(2, 0),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              _assetPath,
                              width: 34,
                              height: 34,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.shield_rounded,
                                  color: _accentColor,
                                  size: 31,
                                );
                              },
                            ),
                            const SizedBox(width: 1.5),
                            Text(
                              'VIP $vipLevel',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _accentColor,
                                fontSize: 13.8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.25,
                              ),
                            ),
                          ],
                        ),
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

class _MonthStatCard extends StatelessWidget {
  const _MonthStatCard({
    required this.title,
    required this.value,
    required this.onTap,
    required this.tint,
    required this.borderColor,
    required this.titleColor,
    required this.valueColor,
  });

  final String title;
  final String value;
  final VoidCallback onTap;
  final Color tint;
  final Color borderColor;
  final Color titleColor;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: titleColor,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: valueColor,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStatCardShine extends StatelessWidget {
  const _MiniStatCardShine();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.28),
                  Colors.white.withValues(alpha: 0.10),
                  Colors.white.withValues(alpha: 0.00),
                ],
              ),
            ),
          ),
        ),
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
    required this.onLeaveSeatOnly,
    required this.onSelfMuteToggle,
    required this.onAdminMuteToggle,
    required this.onGiftTap,
    this.onKickOutTap,
  });

  final bool isSelf;
  final bool canModerate;
  final bool selfMuted;
  final bool adminMuted;
  final VoidCallback onLeaveAndLock;
  final VoidCallback onLeaveSeatOnly;
  final VoidCallback onSelfMuteToggle;
  final VoidCallback onAdminMuteToggle;
  final VoidCallback onGiftTap;
  final VoidCallback? onKickOutTap;

  @override
  Widget build(BuildContext context) {
    return RoomProfileActionRow(
      isSelf: isSelf,
      canModerate: canModerate,
      selfMuted: selfMuted,
      adminMuted: adminMuted,
      onLeaveAndLock: onLeaveAndLock,
      onLeaveSeatOnly: onLeaveSeatOnly,
      onSelfMuteToggle: onSelfMuteToggle,
      onAdminMuteToggle: onAdminMuteToggle,
      onKickOutTap: onKickOutTap,
    );
  }
}
