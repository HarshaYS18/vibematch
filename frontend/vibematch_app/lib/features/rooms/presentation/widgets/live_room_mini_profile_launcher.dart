import 'package:flutter/material.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/ui/vm_motion.dart';
import '../../../experience/presentation/experience_detail_page.dart';
import '../../../inbox/data/inbox_api_service.dart';
import '../../../inbox/presentation/inbox_page_modular.dart';
import '../../../rankings/data/global_rankings_api_service.dart';
import '../../../rankings/presentation/global_rankings_sheet.dart';
import '../../../social/data/social_api_service.dart';
import '../../data/live_room_media_signaling_service.dart';
import '../../data/room_moderation_repository.dart';
import '../controllers/live_room_profile_navigator.dart';
import '../live_room_models.dart';
import 'live_room_mini_profile_sheet.dart';
import 'mini_profile_report_sheet.dart';
import 'mini_profile_social_actions_row.dart';
import 'room_kickout_duration_sheet.dart';

class LiveRoomMiniProfileLauncher {
  const LiveRoomMiniProfileLauncher._();

  static void open({
    required BuildContext context,
    required SeatUser user,
    required int seatIndex,
    required SeatUser currentUser,
    required bool canModerate,
    required List<SeatUser> allRoomUsers,
    required RoomPrivacyMode privacyMode,
    required String roomName,
    String? roomId,
    required ValueChanged<SeatUser> onMentionTap,
    required ValueChanged<String> onSetAdminTap,
    ValueChanged<String>? onRemoveAdminTap,
    ValueChanged<SeatUser>? onReportTap,
    ValueChanged<RoomKickoutDuration>? onKickOutDurationSelected,
    required ValueChanged<int> onLeaveAndLock,
    required ValueChanged<int> onLeaveSeatOnly,
    required ValueChanged<String> onSelfMuteToggle,
    required ValueChanged<String> onAdminMuteToggle,
    required ValueChanged<String> onGiftTap,
  }) {
    final effectiveCurrentUser = LiveRoomMediaSignalingService.instance
        .effectiveCurrentUser(currentUser);
    final viewerPower = _roomPower(effectiveCurrentUser);
    final targetPower = _roomPower(user);
    final canModerateTarget =
        user.id != effectiveCurrentUser.id &&
        targetPower < 100 &&
        ((viewerPower >= 100 && targetPower < 100) ||
            (viewerPower >= 90 && targetPower < 90));
    final canShowKickOut = canModerateTarget;
    final initialRelation = _relationFromUserIds(
      currentUserId: effectiveCurrentUser.id,
      targetUserId: user.id,
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: VmMotion.sheetAnimationStyle,
      builder: (_) => VmFadeSlide(
        child: LiveRoomMiniProfileSheet(
          user: user,
          currentUser: effectiveCurrentUser,
          canModerate: canModerateTarget,
          initialRelation: initialRelation,
          onAvatarTap: () {
            Navigator.pop(context);
            LiveRoomProfileNavigator.openExistingPublicProfile(
              context: context,
              user: user,
              privacyMode: privacyMode,
              roomName: roomName,
            );
          },
          onVipTap: () => LiveRoomProfileNavigator.openVipCentrePage(
            context: context,
            user: user,
          ),
          onSvipTap: () => LiveRoomProfileNavigator.openSvipCentrePage(
            context: context,
            user: user,
          ),
          onSendingLevelTap: () => _openExperienceDetailPage(
            context: context,
            user: user,
            kind: ExperienceDetailKind.sent,
            title: 'Sent Lv',
          ),
          onReceivingLevelTap: () => _openExperienceDetailPage(
            context: context,
            user: user,
            kind: ExperienceDetailKind.received,
            title: 'Received Lv',
          ),
          onSentRankingTap: () => _openGlobalRankingsSheet(
            context: context,
            type: GlobalRankingType.sent,
          ),
          onReceivedRankingTap: () => _openGlobalRankingsSheet(
            context: context,
            type: GlobalRankingType.received,
          ),
          onFamilyTap: () => LiveRoomProfileNavigator.openFamilyPage(
            context: context,
            user: user,
          ),
          onRelationshipTap: () =>
              LiveRoomProfileNavigator.openLoveAndBondCentre(
                context: context,
                user: user,
              ),
          onMedalsTap: () => LiveRoomProfileNavigator.openMedalsPage(
            context: context,
            user: user,
          ),
          onMentionTap: () => onMentionTap(user),
          onSetAdminTap: () => onSetAdminTap(user.id),
          onRemoveAdminTap: () {
            if (onRemoveAdminTap != null) {
              onRemoveAdminTap(user.id);
            } else {
              Navigator.pop(context);
            }
          },
          onReportTap: () {
            if (onReportTap != null) {
              onReportTap(user);
            } else {
              _openReportSheet(context: context, user: user);
            }
          },
          onLeaveAndLock: () => onLeaveAndLock(seatIndex),
          onLeaveSeatOnly: () => onLeaveSeatOnly(seatIndex),
          onSelfMuteToggle: () => onSelfMuteToggle(user.id),
          onAdminMuteToggle: () => onAdminMuteToggle(user.id),
          onGiftTap: () => onGiftTap(user.id),
          onSocialRelationTap: () =>
              _toggleFollowFromMiniProfile(context: context, user: user),
          onMessageTap: () => _openMessageInfo(context: context, user: user),
          onKickOutTap: canShowKickOut && onKickOutDurationSelected != null
              ? () => _openKickOutDurationSheet(
                  context: context,
                  user: user,
                  onDurationSelected: onKickOutDurationSelected,
                )
              : null,
        ),
      ),
    );
  }

  static MiniProfileSocialRelation _relationFromUserIds({
    required String currentUserId,
    required String targetUserId,
  }) {
    if (currentUserId == targetUserId)
      return MiniProfileSocialRelation.following;
    return MiniProfileSocialRelation.follow;
  }

  static Future<MiniProfileSocialRelation> _toggleFollowFromMiniProfile({
    required BuildContext context,
    required SeatUser user,
  }) async {
    final publicUserId = publicUserIdFromRoomUserId(user.id);
    if (publicUserId == null) {
      _showMiniToast(
        context,
        'This user does not have a valid public user ID yet.',
      );
      return MiniProfileSocialRelation.follow;
    }

    try {
      final service = const SocialApiService();
      final current = await service.getFollowStatusByPublicUserId(publicUserId);
      final next = current.isFollowing
          ? await service.unfollowByPublicUserId(publicUserId)
          : await service.followByPublicUserId(publicUserId);
      final relation = _relationFromFollowStatus(next);
      _showMiniToast(
        context,
        next.isFriends
            ? 'You are friends now.'
            : next.isFollowing
            ? 'You are now following ${user.name}.'
            : 'Unfollowed ${user.name}.',
      );
      return relation;
    } catch (error) {
      _showMiniToast(context, error.toString().replaceFirst('Exception: ', ''));
      return MiniProfileSocialRelation.follow;
    }
  }

  static MiniProfileSocialRelation _relationFromFollowStatus(
    FollowStatus status,
  ) {
    if (status.isFriends) return MiniProfileSocialRelation.friends;
    if (status.isFollowing) return MiniProfileSocialRelation.following;
    if (status.isFollowedBy) return MiniProfileSocialRelation.followBack;
    return MiniProfileSocialRelation.follow;
  }

  static void _showMiniToast(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF251538),
        ),
      );
  }

  static int _roomPower(SeatUser user) {
    final id = user.id.toLowerCase();
    final role = user.roleLabel.toLowerCase();
    final isOwner =
        user.isHost ||
        id == 'user_6922022' ||
        id == 'founder_owner' ||
        role.contains('founder owner') ||
        role.contains('super owner') ||
        role.contains('owner') ||
        role.contains('channel host') ||
        role == 'host';
    if (isOwner) return 100;

    final isChannelAdmin =
        user.isRoomAdmin ||
        role.contains('channel admin') ||
        role.contains('room admin') ||
        role.contains('administrator');
    if (isChannelAdmin) return 90;

    return 0;
  }

  static void _openExperienceDetailPage({
    required BuildContext context,
    required SeatUser user,
    required ExperienceDetailKind kind,
    required String title,
  }) {
    Navigator.pop(context);
    final publicUserId = publicUserIdFromRoomUserId(user.id);
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (!context.mounted) return;
      Navigator.pushNamed(
        context,
        VmRoutes.experienceDetail,
        arguments: ExperienceDetailRouteArgs(
          kind: kind,
          publicUserId: publicUserId,
          title: title,
        ),
      );
    });
  }

  static void _openGlobalRankingsSheet({
    required BuildContext context,
    required GlobalRankingType type,
  }) {
    Navigator.pop(context);
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (!context.mounted) return;
      GlobalRankingsSheet.show(context, initialType: type);
    });
  }

  static void _openKickOutDurationSheet({
    required BuildContext context,
    required SeatUser user,
    required ValueChanged<RoomKickoutDuration> onDurationSelected,
  }) {
    Navigator.pop(context);

    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (!context.mounted) return;

      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        sheetAnimationStyle: VmMotion.sheetAnimationStyle,
        builder: (_) => VmFadeSlide(
          child: RoomKickoutDurationSheet(
            user: user,
            onDurationSelected: onDurationSelected,
          ),
        ),
      );
    });
  }

  static void _openReportSheet({
    required BuildContext context,
    required SeatUser user,
  }) {
    Navigator.pop(context);

    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (!context.mounted) return;

      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        sheetAnimationStyle: VmMotion.sheetAnimationStyle,
        builder: (_) => VmFadeSlide(child: MiniProfileReportSheet(user: user)),
      );
    });
  }

  static Future<void> _openMessageInfo({
    required BuildContext context,
    required SeatUser user,
  }) async {
    Navigator.pop(context);

    final publicUserId = publicUserIdFromRoomUserId(user.id);
    if (publicUserId == null) {
      Future<void>.delayed(const Duration(milliseconds: 80), () {
        if (!context.mounted) return;
        LiveRoomProfileNavigator.openModulePage(
          context: context,
          title: 'Message ${user.name}',
          subtitle: 'This user does not have a valid public user ID yet.',
          icon: Icons.chat_bubble_rounded,
        );
      });
      return;
    }

    try {
      final followStatus = await const SocialApiService()
          .getFollowStatusByPublicUserId(publicUserId);
      await InboxApiService().createDirectConversation(
        targetUserId: followStatus.targetUser.id,
      );
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!context.mounted) return;
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        sheetAnimationStyle: VmMotion.sheetAnimationStyle,
        builder: (_) =>
            const VmFadeSlide(child: InboxPage(openPagesInOverlay: true)),
      );
    } catch (error) {
      Future<void>.delayed(const Duration(milliseconds: 80), () {
        if (!context.mounted) return;
        LiveRoomProfileNavigator.openModulePage(
          context: context,
          title: 'Message ${user.name}',
          subtitle: error.toString().replaceFirst('Exception: ', ''),
          icon: Icons.chat_bubble_rounded,
        );
      });
    }
  }
}
