import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'mini_profile_decoration.dart';
import 'mini_profile_header_row.dart';
import 'mini_profile_level_row.dart';
import 'mini_profile_meta_row.dart';
import 'mini_profile_social_actions_row.dart';
import 'mini_profile_stats_row.dart';
import 'room_profile_action_row.dart';

class UserMiniProfileSheet extends StatelessWidget {
  const UserMiniProfileSheet({
    super.key,
    required this.user,
    required this.currentUser,
    required this.canModerate,
    required this.onAvatarTap,
    required this.onVipTap,
    required this.onSvipTap,
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
    required this.onSocialRelationTap,
    required this.onMessageTap,
    this.onKickOutTap,
  });

  final SeatUser user;
  final SeatUser currentUser;
  final bool canModerate;
  final VoidCallback onAvatarTap;
  final VoidCallback onVipTap;
  final VoidCallback onSvipTap;
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
  final VoidCallback onSocialRelationTap;
  final VoidCallback onMessageTap;
  final VoidCallback? onKickOutTap;

  bool get _isSelf => user.id == currentUser.id;
  bool get _showAdminMenu => canModerate && !_isSelf && _currentUserPower >= 100 && _targetPower < 100;
  int get _currentUserPower => _roomPower(currentUser);
  int get _targetPower => _roomPower(user);

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
                MiniProfileHeaderRow(
                  user: user,
                  isSelf: _isSelf,
                  showAdminMenu: _showAdminMenu,
                  onMentionTap: onMentionTap,
                  onReportTap: onReportTap,
                  onSetAdminTap: onSetAdminTap,
                  onRemoveAdminTap: onRemoveAdminTap,
                ),
                const SizedBox(height: 7),
                MiniProfileLevelRow(
                  user: user,
                  onVipTap: onVipTap,
                  onSvipTap: onSvipTap,
                  onSendingLevelTap: onSendingLevelTap,
                  onReceivingLevelTap: onReceivingLevelTap,
                ),
                const SizedBox(height: 8),
                MiniProfileMetaRow(user: user, onFamilyTap: onFamilyTap),
                const SizedBox(height: 10),
                MiniProfileStatsRow(
                  user: user,
                  onVipTap: onVipTap,
                  onSentRankingTap: onSentRankingTap,
                  onReceivedRankingTap: onReceivedRankingTap,
                ),
                if (!_isSelf) ...[
                  const SizedBox(height: 9),
                  MiniProfileSocialActionsRow(
                    relation: miniProfileMockRelationForUser(user),
                    onRelationTap: onSocialRelationTap,
                    onMessageTap: onMessageTap,
                  ),
                ],
                const SizedBox(height: 10),
                RoomProfileActionRow(
                  user: user,
                  currentUser: currentUser,
                  selfMuted: user.selfMuted,
                  adminMuted: user.adminMuted,
                  onLeaveAndLock: onLeaveAndLock,
                  onLeaveSeatOnly: onLeaveSeatOnly,
                  onSelfMuteToggle: onSelfMuteToggle,
                  onAdminMuteToggle: onAdminMuteToggle,
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

  static int _roomPower(SeatUser user) {
    final role = user.roleLabel.toLowerCase();
    final isOwner = user.isHost ||
        user.id == 'user_6922022' ||
        user.id == 'founder_owner' ||
        role.contains('owner') ||
        role.contains('channel host') ||
        role == 'host';
    if (isOwner) return 100;

    final isAdmin = user.isRoomAdmin || role.contains('admin') || role.contains('administrator');
    if (isAdmin) return 90;

    return 0;
  }
}
