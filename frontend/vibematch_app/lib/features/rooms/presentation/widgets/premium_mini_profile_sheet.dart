import 'package:flutter/material.dart';

import '../../data/mini_profile_economy_service.dart';
import '../live_room_models.dart';
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
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.30;

    return SizedBox(
      height: sheetHeight,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFCFAF7),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                14,
                48,
                14,
                MediaQuery.paddingOf(context).bottom + 10,
              ),
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TopButtons(
                    showAdminMenu: _showAdminMenu,
                    user: user,
                    onSetAdminTap: onSetAdminTap,
                    onRemoveAdminTap: onRemoveAdminTap,
                    onReportTap: onReportTap,
                    onMentionTap: onMentionTap,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    user.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF18101F),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.35,
                    ),
                  ),
                  const SizedBox(height: 7),
                  _IdentityRow(user: user, onVipTap: onVipTap),
                  const SizedBox(height: 7),
                  _MetaRow(user: user),
                  const SizedBox(height: 9),
                  FutureBuilder<MiniProfileEconomySummary>(
                    future: MiniProfileEconomyService.instance.summaryForSeatUser(user),
                    builder: (context, snapshot) {
                      final economy = snapshot.data ?? MiniProfileEconomySummary.fromSeatUser(user);
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _StatsLine(
                            sentTotalCoins: economy.monthlyGiftCoinsSent,
                            receivedTotalCoins: economy.monthlyGiftCoinsReceived,
                            onSentTap: onSentRankingTap,
                            onReceivedTap: onReceivedRankingTap,
                          ),
                          const SizedBox(height: 9),
                          _MiniActionRow(
                            sendingLevel: economy.sentLevel,
                            receivingLevel: economy.receiveLevel,
                            lifetimeSendExp: economy.lifetimeSendExp,
                            lifetimeReceiveExp: economy.lifetimeReceiveExp,
                            onVipTap: onVipTap,
                            onSendingLevelTap: onSendingLevelTap,
                            onReceivingLevelTap: onReceivingLevelTap,
                            onFamilyTap: onFamilyTap,
                            onRelationshipTap: onRelationshipTap,
                            onMedalsTap: onMedalsTap,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _SendGiftButton(onTap: onGiftTap),
                  const SizedBox(height: 8),
                  _BottomActions(
                    isSelf: _isSelf,
                    canModerate: canModerate,
                    selfMuted: user.selfMuted,
                    adminMuted: user.adminMuted,
                    onLeaveAndLock: onLeaveAndLock,
                    onSelfMuteToggle: onSelfMuteToggle,
                    onAdminMuteToggle: onAdminMuteToggle,
                    onProfileTap: onAvatarTap,
                  ),
                ],
              ),
            ),
            Positioned(
              top: -36,
              child: _Avatar(user: user, onTap: onAvatarTap),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopButtons extends StatelessWidget {
  const _TopButtons({
    required this.showAdminMenu,
    required this.user,
    required this.onSetAdminTap,
    required this.onRemoveAdminTap,
    required this.onReportTap,
    required this.onMentionTap,
  });

  final bool showAdminMenu;
  final SeatUser user;
  final VoidCallback onSetAdminTap;
  final VoidCallback onRemoveAdminTap;
  final VoidCallback onReportTap;
  final VoidCallback onMentionTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Stack(
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
                : _RoundIcon(
                    icon: Icons.report_gmailerrorred_rounded,
                    color: RoomColors.coral,
                    onTap: onReportTap,
                  ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _RoundIcon(
              icon: Icons.alternate_email_rounded,
              color: RoomColors.aqua,
              onTap: onMentionTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user, required this.onTap});

  final SeatUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  RoomColors.gold,
                  user.avatarColors.first,
                  RoomColors.coral,
                  RoomColors.aqua,
                  RoomColors.gold,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: RoomColors.gold.withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
          ),
          Container(
            width: 64,
            height: 64,
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: _PremiumMiniProfileAvatarImage(user: user),
          ),
          Positioned(
            right: -1,
            bottom: 4,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [Color(0xFFFFC857), Color(0xFFFF5F7E)]),
                border: Border.all(color: Colors.white, width: 1.8),
              ),
              child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumMiniProfileAvatarImage extends StatelessWidget {
  const _PremiumMiniProfileAvatarImage({required this.user});

  final SeatUser user;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user.avatarUrl?.trim();
    final fallback = Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: user.avatarColors)),
      child: Text(
        avatarLetter(user.name),
        style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900),
      ),
    );
    if (avatarUrl == null || avatarUrl.isEmpty) return fallback;
    return ClipOval(
      child: Image.network(
        avatarUrl,
        width: 58,
        height: 58,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}

class _IdentityRow extends StatelessWidget {
  const _IdentityRow({required this.user, required this.onVipTap});

  final SeatUser user;
  final VoidCallback onVipTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 5,
      children: [
        VipBadge(level: user.vipLevel, size: VipBadgeSize.small, onTap: onVipTap),
        if (user.svipLevel > 0) _SvipPill(level: user.svipLevel, onTap: onVipTap),
        _FamilyBadge(label: user.familyName.trim().isEmpty ? 'No Family' : user.familyName),
      ],
    );
  }
}

class _SvipPill extends StatelessWidget {
  const _SvipPill({required this.level, required this.onTap});

  final int level;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: onTap,
      child: Container(
        height: 27,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          gradient: const LinearGradient(colors: [RoomColors.violet, RoomColors.aqua]),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.diamond_rounded, color: Colors.white, size: 12),
            const SizedBox(width: 4),
            Text(
              'SVIP $level',
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _FamilyBadge extends StatelessWidget {
  const _FamilyBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 27,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        gradient: const LinearGradient(colors: [Color(0xFFB76E22), Color(0xFF12C7B7)]),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.waves_rounded, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 105),
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900),
            ),
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
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 5,
      children: [
        if (user.roleLabel.isNotEmpty)
          _Meta(icon: Icons.account_box_rounded, label: user.roleLabel, color: RoomColors.violet),
        _Meta(icon: user.gender.icon, label: user.age == null ? 'Age hidden' : '${user.age}', color: user.gender.color),
        if (user.showLocation) _Meta(icon: Icons.location_on_rounded, label: user.locationLabel!, color: RoomColors.aqua),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Color(0xFF756878), fontSize: 11.5, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _StatsLine extends StatelessWidget {
  const _StatsLine({required this.sentTotalCoins, required this.receivedTotalCoins, required this.onSentTap, required this.onReceivedTap});

  final int sentTotalCoins;
  final int receivedTotalCoins;
  final VoidCallback onSentTap;
  final VoidCallback onReceivedTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _FollowStat(value: compactNumber(sentTotalCoins), label: 'Sent', onTap: onSentTap),
        Container(width: 1, height: 16, margin: const EdgeInsets.symmetric(horizontal: 16), color: const Color(0xFFE2D8D0)),
        _FollowStat(value: compactNumber(receivedTotalCoins), label: 'Received', onTap: onReceivedTap),
      ],
    );
  }
}

class _FollowStat extends StatelessWidget {
  const _FollowStat({required this.value, required this.label, required this.onTap});

  final String value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$value $label', style: const TextStyle(color: Color(0xFF756878), fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(width: 3),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF9A8E9F), size: 14),
          ],
        ),
      ),
    );
  }
}

class _MiniActionRow extends StatelessWidget {
  const _MiniActionRow({
    required this.sendingLevel,
    required this.receivingLevel,
    required this.lifetimeSendExp,
    required this.lifetimeReceiveExp,
    required this.onVipTap,
    required this.onSendingLevelTap,
    required this.onReceivingLevelTap,
    required this.onFamilyTap,
    required this.onRelationshipTap,
    required this.onMedalsTap,
  });

  final int sendingLevel;
  final int receivingLevel;
  final int lifetimeSendExp;
  final int lifetimeReceiveExp;
  final VoidCallback onVipTap;
  final VoidCallback onSendingLevelTap;
  final VoidCallback onReceivingLevelTap;
  final VoidCallback onFamilyTap;
  final VoidCallback onRelationshipTap;
  final VoidCallback onMedalsTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _ActionPill(icon: Icons.workspace_premium_rounded, label: 'VIP', color: RoomColors.gold, onTap: onVipTap),
          _ActionPill(
            icon: Icons.north_east_rounded,
            label: 'Sent Lv $sendingLevel · ${compactNumber(lifetimeSendExp)}',
            color: RoomColors.violet,
            onTap: onSendingLevelTap,
          ),
          _ActionPill(
            icon: Icons.favorite_rounded,
            label: 'Receive Lv $receivingLevel · ${compactNumber(lifetimeReceiveExp)}',
            color: RoomColors.coral,
            onTap: onReceivingLevelTap,
          ),
          _ActionPill(icon: Icons.groups_rounded, label: 'Family', color: RoomColors.aqua, onTap: onFamilyTap),
          _ActionPill(icon: Icons.favorite_border_rounded, label: 'Bonds', color: RoomColors.coral, onTap: onRelationshipTap),
          _ActionPill(icon: Icons.workspace_premium_rounded, label: 'Badges', color: RoomColors.gold, onTap: onMedalsTap),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.icon, required this.label, required this.color, required this.onTap});

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: 31,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: color, fontSize: 10.8, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendGiftButton extends StatelessWidget {
  const _SendGiftButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(colors: [Color(0xFFFFC107), Color(0xFFFF4F39)]),
        boxShadow: [
          BoxShadow(color: const Color(0xFFFF6A30).withValues(alpha: 0.18), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: const Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 18),
                SizedBox(width: 7),
                Text(
                  'SEND GIFT',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.isSelf,
    required this.canModerate,
    required this.selfMuted,
    required this.adminMuted,
    required this.onLeaveAndLock,
    required this.onSelfMuteToggle,
    required this.onAdminMuteToggle,
    required this.onProfileTap,
  });

  final bool isSelf;
  final bool canModerate;
  final bool selfMuted;
  final bool adminMuted;
  final VoidCallback onLeaveAndLock;
  final VoidCallback onSelfMuteToggle;
  final VoidCallback onAdminMuteToggle;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      _BottomAction(icon: Icons.output_rounded, label: 'Leave', onTap: onLeaveAndLock),
      _BottomAction(icon: Icons.person_rounded, label: 'Profile', onTap: onProfileTap),
    ];
    if (isSelf) {
      actions.add(_BottomAction(icon: selfMuted ? Icons.mic_rounded : Icons.mic_off_rounded, label: selfMuted ? 'Turn On' : 'Turn Off', onTap: onSelfMuteToggle));
    }
    if (canModerate && !isSelf) {
      actions.add(_BottomAction(icon: adminMuted ? Icons.mic_rounded : Icons.mic_off_rounded, label: adminMuted ? 'Unmute' : 'Mute', onTap: onAdminMuteToggle));
    }
    return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: actions);
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF342B38), size: 20),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Color(0xFF8B808E), fontSize: 10.5, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.color, required this.onTap});

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.11),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 28, height: 28, child: Icon(icon, color: color, size: 16)),
      ),
    );
  }
}

class _MoreMenuButton extends StatelessWidget {
  const _MoreMenuButton({required this.user, required this.onSetAdminTap, required this.onRemoveAdminTap, required this.onReportTap});

  final SeatUser user;
  final VoidCallback onSetAdminTap;
  final VoidCallback onRemoveAdminTap;
  final VoidCallback onReportTap;

  @override
  Widget build(BuildContext context) {
    final canRemoveAdmin = user.isRoomAdmin && !user.isHost;

    return PopupMenuButton<String>(
      tooltip: 'More',
      offset: const Offset(0, 32),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      onSelected: (value) {
        if (value == 'set_admin') {
          onSetAdminTap();
        }
        if (value == 'remove_admin') {
          onRemoveAdminTap();
        }
        if (value == 'report') {
          onReportTap();
        }
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
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: RoomColors.plum.withValues(alpha: 0.08), shape: BoxShape.circle),
        child: const Icon(Icons.more_horiz_rounded, color: RoomColors.plum, size: 19),
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
