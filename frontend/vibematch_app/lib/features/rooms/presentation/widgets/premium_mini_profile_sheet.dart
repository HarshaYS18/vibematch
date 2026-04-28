import 'package:flutter/material.dart';

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
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.84),
      decoration: const BoxDecoration(
        color: Color(0xFFFCFAF7),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 68, 16, MediaQuery.paddingOf(context).bottom + 14),
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                _TopButtons(
                  showAdminMenu: _showAdminMenu,
                  user: user,
                  onSetAdminTap: onSetAdminTap,
                  onRemoveAdminTap: onRemoveAdminTap,
                  onReportTap: onReportTap,
                  onMentionTap: onMentionTap,
                ),
                const SizedBox(height: 2),
                Text(
                  user.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF18101F),
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.35,
                  ),
                ),
                const SizedBox(height: 9),
                _IdentityRow(user: user, onVipTap: onVipTap),
                const SizedBox(height: 10),
                _MetaRow(user: user),
                const SizedBox(height: 14),
                _StatsLine(
                  sent: user.sentExp,
                  received: user.receivedExp,
                  onSentTap: onSentRankingTap,
                  onReceivedTap: onReceivedRankingTap,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _LevelCard(
                        icon: Icons.workspace_premium_rounded,
                        title: 'VIP level',
                        value: 'VIP ${user.vipLevel}',
                        color: const Color(0xFFFFF3E2),
                        accent: RoomColors.gold,
                        onTap: onVipTap,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _LevelCard(
                        icon: Icons.emoji_events_rounded,
                        title: 'Sent',
                        value: '${user.sendingLevel}',
                        color: const Color(0xFFE6FBF5),
                        accent: RoomColors.aqua,
                        onTap: onSendingLevelTap,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _LevelCard(
                        icon: Icons.auto_awesome_rounded,
                        title: 'Received',
                        value: '${user.receivingLevel}',
                        color: const Color(0xFFF1F1F2),
                        accent: const Color(0xFF9C95A0),
                        onTap: onReceivingLevelTap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _FamilyCard(user: user, onTap: onFamilyTap),
                const SizedBox(height: 12),
                _RelationshipCard(user: user, onTap: onRelationshipTap),
                const SizedBox(height: 10),
                _ListRow(
                  icon: Icons.card_giftcard_rounded,
                  title: 'Gift Wall',
                  subtitle: 'Premium gifts received',
                  trailing: const Text('🏆 🎁 🗿', style: TextStyle(fontSize: 18)),
                  onTap: onGiftTap,
                ),
                const SizedBox(height: 8),
                _ListRow(
                  icon: Icons.workspace_premium_rounded,
                  title: 'Badges',
                  subtitle: user.medals.isEmpty ? 'No badges yet' : user.medals.join('  '),
                  trailing: Text(user.medals.isEmpty ? '💎 🌟 🔥' : user.medals.take(3).join(' '), style: const TextStyle(fontSize: 18)),
                  onTap: onMedalsTap,
                ),
                const SizedBox(height: 14),
                _SendGiftButton(onTap: onGiftTap),
                const SizedBox(height: 14),
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
          Positioned(top: -48, child: _Avatar(user: user, onTap: onAvatarTap)),
          Positioned(top: 10, right: 14, child: _WalletStack(user: user)),
        ],
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
      height: 34,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: showAdminMenu
                ? _MoreMenuButton(user: user, onSetAdminTap: onSetAdminTap, onRemoveAdminTap: onRemoveAdminTap, onReportTap: onReportTap)
                : _RoundIcon(icon: Icons.report_gmailerrorred_rounded, color: RoomColors.coral, onTap: onReportTap),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _RoundIcon(icon: Icons.alternate_email_rounded, color: RoomColors.aqua, onTap: onMentionTap),
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
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(colors: [RoomColors.gold, user.avatarColors.first, RoomColors.coral, RoomColors.aqua, RoomColors.gold]),
              boxShadow: [BoxShadow(color: RoomColors.gold.withValues(alpha: 0.34), blurRadius: 24, offset: const Offset(0, 10))],
            ),
          ),
          Container(
            width: 88,
            height: 88,
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: user.avatarColors)),
              child: Text(avatarLetter(user.name), style: const TextStyle(color: Colors.white, fontSize: 31, fontWeight: FontWeight.w900)),
            ),
          ),
          Positioned(
            right: -2,
            bottom: 6,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [Color(0xFFFFC857), Color(0xFFFF5F7E)]),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletStack extends StatelessWidget {
  const _WalletStack({required this.user});

  final SeatUser user;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _WalletPill(icon: Icons.monetization_on_rounded, value: compactNumber(user.sentExp)),
        const SizedBox(height: 8),
        _WalletPill(icon: Icons.diamond_rounded, value: compactNumber(user.receivedExp)),
      ],
    );
  }
}

class _WalletPill extends StatelessWidget {
  const _WalletPill({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(color: const Color(0xFFFFF4D7), borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFFF1DB9D))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: RoomColors.gold, size: 15),
          const SizedBox(width: 4),
          Text(value, style: const TextStyle(color: RoomColors.plum, fontSize: 11.5, fontWeight: FontWeight.w900)),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFFB69549), size: 15),
        ],
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
      spacing: 7,
      runSpacing: 7,
      children: [
        VipBadge(level: user.vipLevel, size: VipBadgeSize.small, onTap: onVipTap),
        if (user.svipLevel > 0) _SvipPill(level: user.svipLevel, onTap: onVipTap),
        _FamilyBadge(label: user.familyName.trim().isEmpty ? 'No Family' : user.familyName),
        _MiniLv(value: user.sendingLevel),
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
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(7), gradient: const LinearGradient(colors: [RoomColors.violet, RoomColors.aqua])),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.diamond_rounded, color: Colors.white, size: 13),
          const SizedBox(width: 4),
          Text('SVIP $level', style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900)),
        ]),
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
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(7), gradient: const LinearGradient(colors: [Color(0xFFB76E22), Color(0xFF12C7B7)])),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.waves_rounded, color: Colors.white, size: 13),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 110),
          child: Text(label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
        ),
      ]),
    );
  }
}

class _MiniLv extends StatelessWidget {
  const _MiniLv({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(color: RoomColors.coral, borderRadius: BorderRadius.circular(7)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 13),
        const SizedBox(width: 3),
        Text('$value', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
      ]),
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
      runSpacing: 7,
      children: [
        if (user.roleLabel.isNotEmpty) _Meta(icon: Icons.account_box_rounded, label: user.roleLabel, color: RoomColors.violet),
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
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 15),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: Color(0xFF756878), fontSize: 12, fontWeight: FontWeight.w800)),
    ]);
  }
}

class _StatsLine extends StatelessWidget {
  const _StatsLine({required this.sent, required this.received, required this.onSentTap, required this.onReceivedTap});

  final int sent;
  final int received;
  final VoidCallback onSentTap;
  final VoidCallback onReceivedTap;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _FollowStat(value: compactNumber(received), label: 'Followers', onTap: onReceivedTap),
      Container(width: 1, height: 18, margin: const EdgeInsets.symmetric(horizontal: 18), color: const Color(0xFFE2D8D0)),
      _FollowStat(value: compactNumber(sent), label: 'Followed', onTap: onSentTap),
    ]);
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
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('$value $label', style: const TextStyle(color: Color(0xFF756878), fontSize: 12.5, fontWeight: FontWeight.w800)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF9A8E9F), size: 15),
        ]),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.icon, required this.title, required this.value, required this.color, required this.accent, required this.onTap});

  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: onTap,
      child: Container(
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(13)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: accent, size: 18),
          const SizedBox(height: 4),
          Text(title, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF8B7F8E), fontSize: 10.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(value, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: RoomColors.plum, fontSize: 13, fontWeight: FontWeight.w900)),
        ]),
      ),
    );
  }
}

class _FamilyCard extends StatelessWidget {
  const _FamilyCard({required this.user, required this.onTap});

  final SeatUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final family = user.familyName.trim().isEmpty ? 'No Family' : user.familyName;
    return InkWell(
      borderRadius: BorderRadius.circular(17),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(color: const Color(0xFFFFFBF3), borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFFE9C879), width: 1.5)),
        child: Row(children: [
          Container(width: 48, height: 48, alignment: Alignment.center, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: LinearGradient(colors: user.avatarColors)), child: const Text('A', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(family.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: RoomColors.plum, fontSize: 12, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Row(children: [
              _SmallChip(icon: Icons.people_rounded, label: '30/200', color: RoomColors.gold),
              const SizedBox(width: 6),
              _SmallChip(icon: Icons.shield_rounded, label: user.id.hashCode.abs().toString().padLeft(8, '0').substring(0, 8), color: const Color(0xFFB8B1BD)),
            ]),
          ])),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFFC5A051), size: 22),
        ]),
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        height: 20,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(5)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: color, size: 12), const SizedBox(width: 3), Text(label, style: const TextStyle(color: Color(0xFF6D606F), fontSize: 10, fontWeight: FontWeight.w900))]),
      );
}

class _RelationshipCard extends StatelessWidget {
  const _RelationshipCard({required this.user, required this.onTap});
  final SeatUser user;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 15),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: const LinearGradient(colors: [Color(0xFFFFF1F8), Color(0xFFFFD9ED)])),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [Expanded(child: Text('Relationship', style: TextStyle(color: Color(0xFF3D3442), fontSize: 19, fontWeight: FontWeight.w800))), Text('2/100', style: TextStyle(color: Color(0xFF8E8292), fontSize: 13, fontWeight: FontWeight.w800)), SizedBox(width: 4), Icon(Icons.chevron_right_rounded, color: Color(0xFF8E8292), size: 22)]),
            const SizedBox(height: 14),
            Row(children: [_BondAvatar(colors: user.avatarColors, label: avatarLetter(user.name)), const SizedBox(width: 18), const _BondAvatar(colors: [Color(0xFF7A5CFF), Color(0xFF12C7B7)], label: 'L')]),
          ]),
        ),
      );
}

class _BondAvatar extends StatelessWidget {
  const _BondAvatar({required this.colors, required this.label});
  final List<Color> colors;
  final String label;
  @override
  Widget build(BuildContext context) => Container(width: 54, height: 54, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: colors)), child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)));
}

class _ListRow extends StatelessWidget {
  const _ListRow({required this.icon, required this.title, required this.subtitle, required this.trailing, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFEAE4DE))),
          child: Row(children: [
            Icon(icon, color: RoomColors.gold, size: 22),
            const SizedBox(width: 9),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF17101E), fontSize: 15.5, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF8C808E), fontSize: 11.5, fontWeight: FontWeight.w700))])),
            trailing,
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF9C929F), size: 22),
          ]),
        ),
      );
}

class _SendGiftButton extends StatelessWidget {
  const _SendGiftButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Container(
        height: 58,
        width: double.infinity,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), gradient: const LinearGradient(colors: [Color(0xFFFFC107), Color(0xFFFF4F39)]), boxShadow: [BoxShadow(color: const Color(0xFFFF6A30).withValues(alpha: 0.24), blurRadius: 18, offset: const Offset(0, 8))]),
        child: Material(color: Colors.transparent, borderRadius: BorderRadius.circular(999), child: InkWell(borderRadius: BorderRadius.circular(999), onTap: onTap, child: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 21), SizedBox(width: 8), Text('SEND GIFT', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.2))])))),
      );
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({required this.isSelf, required this.canModerate, required this.selfMuted, required this.adminMuted, required this.onLeaveAndLock, required this.onSelfMuteToggle, required this.onAdminMuteToggle, required this.onProfileTap});
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
    final actions = <Widget>[_BottomAction(icon: Icons.output_rounded, label: 'Leave', onTap: onLeaveAndLock), _BottomAction(icon: Icons.person_rounded, label: 'Profile', onTap: onProfileTap)];
    if (isSelf) actions.add(_BottomAction(icon: selfMuted ? Icons.mic_rounded : Icons.mic_off_rounded, label: selfMuted ? 'Turn On' : 'Turn Off', onTap: onSelfMuteToggle));
    if (canModerate && !isSelf) actions.add(_BottomAction(icon: adminMuted ? Icons.mic_rounded : Icons.mic_off_rounded, label: adminMuted ? 'Unmute' : 'Mute', onTap: onAdminMuteToggle));
    return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: actions);
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: const Color(0xFF342B38), size: 24), const SizedBox(height: 4), Text(label, style: const TextStyle(color: Color(0xFF8B808E), fontSize: 11.5, fontWeight: FontWeight.w700))])));
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.color, required this.onTap});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(color: color.withValues(alpha: 0.11), shape: const CircleBorder(), child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: SizedBox(width: 34, height: 34, child: Icon(icon, color: color, size: 18))));
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
      offset: const Offset(0, 38),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      onSelected: (value) {
        if (value == 'set_admin') onSetAdminTap();
        if (value == 'remove_admin') onRemoveAdminTap();
        if (value == 'report') onReportTap();
      },
      itemBuilder: (context) => [
        if (canRemoveAdmin) const PopupMenuItem<String>(value: 'remove_admin', child: _MenuRow(icon: Icons.shield_moon_rounded, color: RoomColors.coral, label: 'Remove admin')) else if (!user.isRoomAdmin && !user.isHost) const PopupMenuItem<String>(value: 'set_admin', child: _MenuRow(icon: Icons.shield_rounded, color: RoomColors.aqua, label: 'Set as admin')),
        const PopupMenuItem<String>(value: 'report', child: _MenuRow(icon: Icons.report_gmailerrorred_rounded, color: RoomColors.coral, label: 'Report')),
      ],
      child: Container(width: 34, height: 34, decoration: BoxDecoration(color: RoomColors.plum.withValues(alpha: 0.08), shape: BoxShape.circle), child: const Icon(Icons.more_horiz_rounded, color: RoomColors.plum, size: 22)),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.color, required this.label});
  final IconData icon;
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(children: [Icon(icon, size: 18, color: color), const SizedBox(width: 9), Text(label, style: const TextStyle(color: RoomColors.plum, fontWeight: FontWeight.w800))]);
}
