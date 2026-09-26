import 'package:flutter/material.dart';

import '../../../core/ui/vm_motion.dart';
import '../../auth/data/auth_api_service.dart';
import '../../social/widgets/friends_invite_sheet.dart';
import '../models/vibe_models.dart';
import '../presentation/pages/create_vibe_page_modular.dart';
import '../presentation/pages/media_vibe_detail_pager.dart';
import '../presentation/pages/vibe_detail_backend_page.dart';
import '../presentation/pages/vibes_settings_page.dart';
import '../presentation/widgets/vibe_action_sheets.dart';
import '../presentation/widgets/vibe_media_playback_gate.dart';
import 'vibes_controller.dart';

class VibesNavigationController {
  const VibesNavigationController._();

  static String? currentUserPublicId() =>
      const AuthApiService().cachedUser?.publicUserId.toString();

  static bool isSelfVibe(VibeItem vibe) {
    final publicId = currentUserPublicId();
    return publicId != null && publicId == vibe.authorId;
  }

  static void showAction(BuildContext context, String message) {
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

  static void openSettings({
    required BuildContext context,
    required VibesController controller,
  }) {
    Navigator.push(
      context,
      VmMotion.pageRoute<void>(
        settings: const RouteSettings(name: 'vibes-settings'),
        page: VibesSettingsPage(
          whoCanMention: controller.whoCanMention,
          whoCanComment: controller.whoCanComment,
          onMentionChanged: controller.setWhoCanMention,
          onCommentChanged: controller.setWhoCanComment,
        ),
      ),
    );
  }

  static void openCreateVibe({
    required BuildContext context,
    required VibesController controller,
    required VibeMediaPlaybackGate playbackGate,
  }) {
    Navigator.of(context).push(
      VmMotion.pageRoute<void>(
        settings: const RouteSettings(name: 'create-vibe'),
        page: CreateVibePageModular(
          canUseMentionAllToday: controller.canUseMentionAllToday,
          playbackGate: playbackGate,
          onPublish: (newVibe) async {
            try {
              await controller.publishVibe(newVibe);
              if (context.mounted) showAction(context, 'Vibe published.');
            } catch (error) {
              if (context.mounted)
                showAction(
                  context,
                  error.toString().replaceFirst('Exception: ', ''),
                );
            }
          },
        ),
      ),
    );
  }

  static void openVibeDetail({
    required BuildContext context,
    required VibesController controller,
    required VibeItem vibe,
    required VibeMediaPlaybackGate playbackGate,
  }) {
    if (vibe.mediaType != VibeMediaType.text) {
      final mediaVibes = controller.visibleVibes
          .where((item) => item.mediaType != VibeMediaType.text)
          .toList(growable: false);
      final idIndex = mediaVibes.indexWhere(
        (item) => item.id.trim().isNotEmpty && item.id == vibe.id,
      );
      final fallbackIndex = mediaVibes.indexOf(vibe);
      Navigator.of(context).push(
        VmMotion.pageRoute<void>(
          settings: const RouteSettings(name: 'media-vibe-detail'),
          page: MediaVibeDetailPager(
            vibes: mediaVibes.isEmpty ? <VibeItem>[vibe] : mediaVibes,
            playbackGate: playbackGate,
            initialIndex: idIndex >= 0
                ? idIndex
                : (fallbackIndex >= 0 ? fallbackIndex : 0),
          ),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      VmMotion.pageRoute<void>(
        settings: const RouteSettings(name: 'vibe-detail'),
        page: VibeDetailBackendPage(
          vibe: vibe,
          onCommentAdded: () => controller.incrementCommentCount(vibe),
          onDeleteVibe: () => controller.deleteVibe(vibe),
        ),
      ),
    );
  }

  static void openShareSheet({
    required BuildContext context,
    required VibesController controller,
    required VibeItem vibe,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      sheetAnimationStyle: VmMotion.sheetAnimationStyle,
      builder: (_) => FriendsInviteSheet(
        title: 'Share ${vibe.authorName}\'s Vibe',
        actionLabel: 'Send',
        completedLabel: 'Sent',
        onInvite: (friend) async {
          try {
            final publicUserId = int.tryParse(friend.id);
            await controller.shareVibe(vibe, targetPublicUserId: publicUserId);
            if (context.mounted)
              showAction(context, 'Vibe sent to ${friend.displayName}');
          } catch (error) {
            if (context.mounted)
              showAction(
                context,
                error.toString().replaceFirst('Exception: ', ''),
              );
          }
        },
      ),
    );
  }

  static Future<void> openVibeActions({
    required BuildContext context,
    required VibesController controller,
    required VibeItem vibe,
  }) async {
    if (isSelfVibe(vibe)) {
      await _confirmAndDeleteVibe(
        context: context,
        controller: controller,
        vibe: vibe,
      );
      return;
    }

    final reason = await openReportReasonSheet(context: context, vibe: vibe);
    if (reason == null || reason.trim().isEmpty) return;
    try {
      await controller.reportVibe(vibe, reason: reason);
      if (context.mounted)
        showAction(context, 'Vibe submitted for official review.');
    } catch (error) {
      if (context.mounted)
        showAction(context, error.toString().replaceFirst('Exception: ', ''));
    }
  }

  static Future<void> _confirmAndDeleteVibe({
    required BuildContext context,
    required VibesController controller,
    required VibeItem vibe,
  }) async {
    final shouldDelete = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: VmMotion.sheetAnimationStyle,
      builder: (_) => const ConfirmDeleteVibeSheet(),
    );
    if (shouldDelete != true) return;
    try {
      await controller.deleteVibe(vibe);
      if (context.mounted) showAction(context, 'Vibe deleted.');
    } catch (error) {
      if (context.mounted)
        showAction(context, error.toString().replaceFirst('Exception: ', ''));
    }
  }

  static Future<String?> openReportReasonSheet({
    required BuildContext context,
    required VibeItem vibe,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: VmMotion.sheetAnimationStyle,
      builder: (_) => ReportReasonSheet(vibe: vibe),
    );
  }
}
