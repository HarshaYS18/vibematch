import 'package:flutter/material.dart';

import '../../../../core/ui/vm_motion.dart';
import '../../../media/data/media_upload_service.dart';
import '../modules/live_room_games_module.dart';
import '../modules/live_room_gift_module.dart';
import '../modules/live_room_message_composer_module.dart';
import 'room_seats.dart';
import 'room_theme.dart';

/// Bottom input/action dock for a single live-room route.
///
/// Every action is injected. Image sending is routed to the scoped room
/// message controller instead of a static active-room controller, keeping this
/// widget stateless and reusable.
class RoomInputDock extends StatelessWidget {
  const RoomInputDock({
    super.key,
    required this.controller,
    this.focusNode,
    required this.micMuted,
    required this.showMicButton,
    required this.inboxUnreadCount,
    required this.onInboxTap,
    required this.onEmojiTap,
    required this.onSendTap,
    required this.onImageMessage,
    required this.onMicTap,
    required this.onGamesTap,
    required this.onGiftTap,
    this.imagesEnabled = true,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool micMuted;
  final bool showMicButton;
  final int inboxUnreadCount;
  final VoidCallback onInboxTap;
  final VoidCallback onEmojiTap;
  final VoidCallback onSendTap;
  /// Completes only after the canonical room image-chat command succeeds.
  final Future<void> Function({
    required String imageUrl,
    required String contentType,
  }) onImageMessage;
  final VoidCallback onMicTap;
  final VoidCallback onGamesTap;
  final VoidCallback onGiftTap;
  final bool imagesEnabled;

  void _runAndHideSeatActions(VoidCallback action) {
    dismissRoomSeatActionPill();
    action();
  }

  Future<void> _pickAndSendImage(BuildContext context) async {
    if (!imagesEnabled) {
      RoomToast.show(context, 'Image messages are disabled in this room');
      return;
    }
    dismissRoomSeatActionPill();
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      RoomToast.show(context, 'Uploading image...');
      final upload = await const MediaUploadService().pickAndUploadChatImage();
      await onImageMessage(
        imageUrl: upload.url,
        contentType: upload.contentType,
      );
      if (context.mounted) RoomToast.show(context, 'Image sent');
    } on MediaUploadCancelledException {
      return;
    } catch (error) {
      if (context.mounted) {
        RoomToast.show(
          context,
          error.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  void _openMessageComposer(BuildContext context) {
    dismissRoomSeatActionPill();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: VmMotion.sheetAnimationStyle,
      builder: (_) => VmFadeSlide(
        child: LiveRoomMessageComposerModule(
          controller: controller,
          focusNode: focusNode,
          imagesEnabled: imagesEnabled,
          onSendText: onSendTap,
          onImageTap: () => _pickAndSendImage(context),
          onSendFloatingText: onSendTap,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tiny = constraints.maxWidth < 340;
          final compact = constraints.maxWidth < 380;
          final buttonSize = tiny
              ? 32.0
              : compact
              ? 34.0
              : 36.0;
          final iconSize = tiny
              ? 15.5
              : compact
              ? 16.5
              : 17.0;
          final gap = tiny ? 4.0 : 6.0;
          final horizontalPadding = tiny ? 8.0 : 10.0;
          return Container(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              5,
              horizontalPadding,
              7,
            ),
            decoration: const BoxDecoration(color: Colors.transparent),
            child: Row(
              children: [
                _DockButton(
                  icon: Icons.emoji_emotions_rounded,
                  onTap: () => _runAndHideSeatActions(onEmojiTap),
                  active: true,
                  size: buttonSize,
                  iconSize: iconSize,
                ),
                SizedBox(width: gap),
                _DockButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  onTap: () => _openMessageComposer(context),
                  size: buttonSize,
                  iconSize: iconSize,
                ),
                if (showMicButton) ...[
                  SizedBox(width: gap),
                  _DockButton(
                    icon: micMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    onTap: () => _runAndHideSeatActions(onMicTap),
                    active: !micMuted,
                    muted: micMuted,
                    size: buttonSize,
                    iconSize: iconSize,
                  ),
                ],
                const Spacer(),
                _DockButton(
                  icon: Icons.mail_outline_rounded,
                  onTap: () => _runAndHideSeatActions(onInboxTap),
                  badgeCount: inboxUnreadCount,
                  size: buttonSize,
                  iconSize: iconSize,
                ),
                SizedBox(width: gap),
                SizedBox(
                  width: buttonSize,
                  height: buttonSize,
                  child: LiveRoomGamesModule(
                    onOpenGames: () => _runAndHideSeatActions(onGamesTap),
                    compact: true,
                  ),
                ),
                SizedBox(width: gap),
                SizedBox(
                  width: buttonSize,
                  height: buttonSize,
                  child: LiveRoomGiftModule(
                    onOpenGiftPanel: () => _runAndHideSeatActions(onGiftTap),
                    comboActive: false,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.icon,
    required this.onTap,
    this.active = false,
    this.muted = false,
    this.badgeCount = 0,
    this.size = 34,
    this.iconSize = 16.5,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final bool muted;
  final int badgeCount;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final iconColor = muted
        ? RoomColors.coral
        : active
        ? RoomColors.aqua
        : Colors.white;
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
              ),
              child: Icon(icon, color: iconColor, size: iconSize),
            ),
            if (badgeCount > 0)
              Positioned(
                right: -1,
                top: -2,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 14,
                    minHeight: 14,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: RoomColors.coral,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: RoomColors.deep, width: 1),
                  ),
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 7.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
