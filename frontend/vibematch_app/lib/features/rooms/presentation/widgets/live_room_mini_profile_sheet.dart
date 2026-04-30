import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'room_profile_sheet.dart';

class LiveRoomMiniProfileSheet extends StatelessWidget {
  const LiveRoomMiniProfileSheet({
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

  @override
  Widget build(BuildContext context) {
    return UserMiniProfileSheet(
      user: user,
      currentUser: currentUser,
      canModerate: canModerate,
      onAvatarTap: onAvatarTap,
      onVipTap: onVipTap,
      onSendingLevelTap: onSendingLevelTap,
      onReceivingLevelTap: onReceivingLevelTap,
      onSentRankingTap: onSentRankingTap,
      onReceivedRankingTap: onReceivedRankingTap,
      onFamilyTap: onFamilyTap,
      onRelationshipTap: onRelationshipTap,
      onMedalsTap: onMedalsTap,
      onMentionTap: onMentionTap,
      onSetAdminTap: onSetAdminTap,
      onRemoveAdminTap: onRemoveAdminTap,
      onReportTap: onReportTap,
      onLeaveAndLock: onLeaveAndLock,
      onLeaveSeatOnly: onLeaveSeatOnly,
      onSelfMuteToggle: onSelfMuteToggle,
      onAdminMuteToggle: onAdminMuteToggle,
      onGiftTap: onGiftTap,
      onKickOutTap: onKickOutTap,
    );
  }
}
