import 'dart:async';

import 'package:flutter/material.dart';

import '../../../profile/data/profile_api_service.dart';
import '../../../social/data/social_api_service.dart';
import '../live_room_models.dart';
import 'mini_profile_social_actions_row.dart';
import 'room_profile_sheet.dart';

class LiveRoomMiniProfileSheet extends StatefulWidget {
  const LiveRoomMiniProfileSheet({
    super.key,
    required this.user,
    required this.currentUser,
    required this.canModerate,
    required this.initialRelation,
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
  final MiniProfileSocialRelation initialRelation;

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
  final Future<MiniProfileSocialRelation> Function() onSocialRelationTap;
  final VoidCallback onMessageTap;
  final VoidCallback? onKickOutTap;

  @override
  State<LiveRoomMiniProfileSheet> createState() => _LiveRoomMiniProfileSheetState();
}

class _LiveRoomMiniProfileSheetState extends State<LiveRoomMiniProfileSheet> {
  late MiniProfileSocialRelation _relation = widget.initialRelation;
  bool _relationBusy = false;
  StreamSubscription<ProfileRelationshipRealtimeEvent>? _relationshipRealtimeSub;

  int? get _targetPublicUserId => publicUserIdFromRoomUserId(widget.user.id);
  int? get _viewerPublicUserId => publicUserIdFromRoomUserId(widget.currentUser.id);

  @override
  void initState() {
    super.initState();
    _relationshipRealtimeSub = ProfileRelationshipRealtimeService.instance.events.listen(_onRelationshipRealtimeEvent);
    unawaited(_refreshRelationFromBackend(showBusy: true));
  }

  @override
  void dispose() {
    _relationshipRealtimeSub?.cancel();
    super.dispose();
  }

  void _onRelationshipRealtimeEvent(ProfileRelationshipRealtimeEvent event) {
    final targetPublicUserId = _targetPublicUserId;
    final viewerPublicUserId = _viewerPublicUserId;
    if (targetPublicUserId == null || viewerPublicUserId == null) return;
    if (!event.touchesProfile(targetPublicUserId) && !event.touchesProfile(viewerPublicUserId)) return;
    unawaited(_refreshRelationFromBackend());
  }

  Future<void> _refreshRelationFromBackend({bool showBusy = false}) async {
    final publicUserId = _targetPublicUserId;
    if (publicUserId == null || publicUserId <= 0) return;
    if (showBusy && mounted) setState(() => _relationBusy = true);
    try {
      final status = await const SocialApiService().getFollowStatusByPublicUserId(publicUserId);
      if (!mounted) return;
      setState(() => _relation = _relationFromFollowStatus(status));
    } catch (_) {
      // Keep the current local relation if backend is temporarily unavailable.
    } finally {
      if (showBusy && mounted) setState(() => _relationBusy = false);
    }
  }

  Future<void> _handleRelationTap() async {
    if (_relationBusy) return;
    setState(() => _relationBusy = true);
    try {
      final next = await widget.onSocialRelationTap();
      if (!mounted) return;
      setState(() => _relation = next);
      unawaited(_refreshRelationFromBackend());
    } finally {
      if (mounted) setState(() => _relationBusy = false);
    }
  }

  MiniProfileSocialRelation _relationFromFollowStatus(FollowStatus status) {
    if (status.isFriends) return MiniProfileSocialRelation.friends;
    if (status.isFollowing) return MiniProfileSocialRelation.following;
    if (status.isFollowedBy) return MiniProfileSocialRelation.followBack;
    return MiniProfileSocialRelation.follow;
  }

  @override
  Widget build(BuildContext context) {
    return UserMiniProfileSheet(
      user: widget.user,
      currentUser: widget.currentUser,
      canModerate: widget.canModerate,
      relation: _relation,
      relationBusy: _relationBusy,
      onAvatarTap: widget.onAvatarTap,
      onVipTap: widget.onVipTap,
      onSvipTap: widget.onSvipTap,
      onSendingLevelTap: widget.onSendingLevelTap,
      onReceivingLevelTap: widget.onReceivingLevelTap,
      onSentRankingTap: widget.onSentRankingTap,
      onReceivedRankingTap: widget.onReceivedRankingTap,
      onFamilyTap: widget.onFamilyTap,
      onRelationshipTap: widget.onRelationshipTap,
      onMedalsTap: widget.onMedalsTap,
      onMentionTap: widget.onMentionTap,
      onSetAdminTap: widget.onSetAdminTap,
      onRemoveAdminTap: widget.onRemoveAdminTap,
      onReportTap: widget.onReportTap,
      onLeaveAndLock: widget.onLeaveAndLock,
      onLeaveSeatOnly: widget.onLeaveSeatOnly,
      onSelfMuteToggle: widget.onSelfMuteToggle,
      onAdminMuteToggle: widget.onAdminMuteToggle,
      onGiftTap: widget.onGiftTap,
      onSocialRelationTap: _handleRelationTap,
      onMessageTap: widget.onMessageTap,
      onKickOutTap: widget.onKickOutTap,
    );
  }
}
