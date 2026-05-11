import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../media/data/media_upload_service.dart';
import '../controllers/live_room_message_controller.dart';
import '../live_room_models.dart';
import '../modules/live_room_games_module.dart';
import '../modules/live_room_gift_module.dart';
import '../modules/live_room_message_composer_module.dart';
import 'chat_vip_badge.dart';
import 'room_seats.dart';
import 'room_text_bubbles.dart';
import 'room_theme.dart';

final ValueNotifier<int> roomChatClearSignal = ValueNotifier<int>(0);

void clearRoomChatHistory() {
  roomChatClearSignal.value++;
}

class RoomChatFeed extends StatefulWidget {
  const RoomChatFeed({
    super.key,
    required this.messages,
    required this.canManageSeatApplications,
    required this.onApproveSeatApplication,
    required this.onRejectSeatApplication,
    this.onSenderTap,
    this.onMentionTap,
  });

  final List<ChatEntry> messages;
  final bool canManageSeatApplications;
  final ValueChanged<ChatEntry> onApproveSeatApplication;
  final ValueChanged<ChatEntry> onRejectSeatApplication;
  final ValueChanged<ChatEntry>? onSenderTap;
  final ValueChanged<String>? onMentionTap;

  @override
  State<RoomChatFeed> createState() => _RoomChatFeedState();
}

class _RoomChatFeedState extends State<RoomChatFeed> {
  late final ScrollController _scrollController;
  Timer? _expiryTimer;
  int _lastMessageCount = 0;
  int _clearedMessageCount = 0;
  final ValueNotifier<int> _expiryTicker = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _lastMessageCount = widget.messages.length;
    roomChatClearSignal.addListener(_handleClearChat);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(jump: true));
    _startExpiryTicker();
  }

  void _startExpiryTicker() {
    _expiryTimer?.cancel();
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _expiryTicker.value++;
    });
  }

  @override
  void didUpdateWidget(covariant RoomChatFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length < _clearedMessageCount) {
      _clearedMessageCount = widget.messages.length;
    }
    if (widget.messages.length != _lastMessageCount) {
      _lastMessageCount = widget.messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  @override
  void dispose() {
    roomChatClearSignal.removeListener(_handleClearChat);
    _expiryTimer?.cancel();
    _expiryTicker.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleClearChat() {
    if (!mounted) return;
    setState(() => _clearedMessageCount = widget.messages.length);
  }

  void _scrollToBottom({bool jump = false}) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (jump) {
      _scrollController.jumpTo(target);
    } else {
      _scrollController.animateTo(target, duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final newMessageCount = (widget.messages.length - _clearedMessageCount).clamp(0, widget.messages.length);
    if (newMessageCount == 0) return const SizedBox.expand();
    final visibleMessages = widget.messages.take(newMessageCount).toList(growable: false).reversed.toList(growable: false);

    return ValueListenableBuilder<int>(
      valueListenable: _expiryTicker,
      builder: (context, _, child) {
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(top: 8, bottom: 10),
          physics: const BouncingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          itemCount: visibleMessages.length,
          itemBuilder: (context, index) {
            final message = visibleMessages[index];
            return RoomTextBubbleHost(
              bubble: null,
              child: _CompactChatLine(
                message: message,
                canManageSeatApplications: widget.canManageSeatApplications,
                onSenderTap: widget.onSenderTap == null ? null : () => widget.onSenderTap!(message),
                onMentionTap: widget.onMentionTap,
                onApproveSeatApplication: () => widget.onApproveSeatApplication(message),
                onRejectSeatApplication: () => widget.onRejectSeatApplication(message),
              ),
            );
          },
        );
      },
    );
  }
}

class _CompactChatLine extends StatelessWidget {
  const _CompactChatLine({required this.message, required this.canManageSeatApplications, required this.onApproveSeatApplication, required this.onRejectSeatApplication, this.onSenderTap, this.onMentionTap});

  final ChatEntry message;
  final bool canManageSeatApplications;
  final VoidCallback onApproveSeatApplication;
  final VoidCallback onRejectSeatApplication;
  final VoidCallback? onSenderTap;
  final ValueChanged<String>? onMentionTap;

  @override
  Widget build(BuildContext context) {
    final showActions = message.isSeatApplication && canManageSeatApplications && !message.applicationResolved;
    final isSystem = message.senderId == 'system';

    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: _TransparentUserMessageFlexBox(
          messageText: message.message,
          enableMessageActions: false,
          child: Text(message.message, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: RoomColors.gold, fontSize: 14.5, fontWeight: FontWeight.w900, height: 1.15)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            fit: FlexFit.loose,
            child: _TransparentUserMessageFlexBox(
              messageText: message.isImageMessage ? (message.imageUrl ?? message.message) : message.message,
              enableMessageActions: !message.isGift,
              onTap: onSenderTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onSenderTap,
                    child: CircleAvatar(radius: 13.5, backgroundColor: message.isSeatApplication ? RoomColors.aqua : RoomColors.violet, child: Text(avatarLetter(message.senderName), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900))),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    fit: FlexFit.loose,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RichText(
                          maxLines: message.isImageMessage ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(children: [
                            WidgetSpan(alignment: PlaceholderAlignment.middle, child: ChatVipBadge(level: message.vipLevel, showWhenZero: true)),
                            const TextSpan(text: '  '),
                            TextSpan(text: message.senderName, recognizer: TapGestureRecognizer()..onTap = onSenderTap, style: const TextStyle(color: Colors.white, fontSize: 14.8, fontWeight: FontWeight.w900, height: 1.15)),
                            const TextSpan(text: '\n '),
                            ..._messageSpans(message, onMentionTap),
                          ]),
                        ),
                        if (message.isImageMessage) ...[const SizedBox(height: 6), _ChatImagePreview(imageUrl: message.imageUrl!)],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showActions) ...[
            const SizedBox(width: 8),
            _SeatApplicationActionButton(label: 'Reject', background: RoomColors.coral.withValues(alpha: 0.92), foreground: Colors.white, onTap: onRejectSeatApplication),
            const SizedBox(width: 6),
            _SeatApplicationActionButton(label: 'Agree', background: RoomColors.aqua, foreground: RoomColors.deep, onTap: onApproveSeatApplication),
          ],
        ],
      ),
    );
  }

  List<TextSpan> _messageSpans(ChatEntry message, ValueChanged<String>? onMentionTap) {
    final text = message.message;
    final mentionRegex = RegExp(r'@[\w\u00C0-\uFFFF]+');
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final match in mentionRegex.allMatches(text)) {
      if (match.start > cursor) spans.add(_normalSpan(text.substring(cursor, match.start), message));
      final mentionText = text.substring(match.start, match.end);
      final mentionName = mentionText.substring(1);
      spans.add(TextSpan(text: mentionText, recognizer: TapGestureRecognizer()..onTap = onMentionTap == null ? null : () => onMentionTap(mentionName), style: const TextStyle(color: RoomColors.aqua, fontSize: 14.2, fontWeight: FontWeight.w900, height: 1.15)));
      cursor = match.end;
    }
    if (cursor < text.length) spans.add(_normalSpan(text.substring(cursor), message));
    return spans;
  }

  TextSpan _normalSpan(String text, ChatEntry message) {
    return TextSpan(text: text, style: TextStyle(color: message.isGift ? RoomColors.gold : message.isSeatApplication ? RoomColors.aqua : Colors.white.withValues(alpha: 0.90), fontSize: 14.2, height: 1.15, fontWeight: message.isGift || message.isSeatApplication ? FontWeight.w900 : FontWeight.w800));
  }
}

class _ChatImagePreview extends StatelessWidget {
  const _ChatImagePreview({required this.imageUrl});
  final String imageUrl;
  @override
  Widget build(BuildContext context) => ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(imageUrl, width: 148, height: 108, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(width: 148, height: 84, alignment: Alignment.center, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withValues(alpha: 0.24))), child: const Icon(Icons.broken_image_rounded, color: Colors.white70, size: 22))));
}

class _SeatApplicationActionButton extends StatelessWidget {
  const _SeatApplicationActionButton({required this.label, required this.background, required this.foreground, required this.onTap});
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: Container(height: 28, padding: const EdgeInsets.symmetric(horizontal: 9), alignment: Alignment.center, decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)), child: Text(label, style: TextStyle(color: foreground, fontSize: 11, fontWeight: FontWeight.w900))));
}

enum _ChatMessageAction { copy, report }

class _TransparentUserMessageFlexBox extends StatelessWidget {
  const _TransparentUserMessageFlexBox({required this.child, required this.messageText, this.onTap, this.enableMessageActions = true});
  final Widget child;
  final String messageText;
  final VoidCallback? onTap;
  final bool enableMessageActions;
  Future<void> _showMessageActionPill(BuildContext context, Offset globalPosition) async {
    if (!enableMessageActions) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    final overlaySize = overlay?.size ?? MediaQuery.sizeOf(context);
    final left = (globalPosition.dx + 16).clamp(8.0, overlaySize.width - 172);
    final top = (globalPosition.dy - 18).clamp(8.0, overlaySize.height - 72);
    final selected = await showMenu<_ChatMessageAction>(context: context, color: Colors.white.withValues(alpha: 0.40), elevation: 14, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999), side: BorderSide(color: Colors.white.withValues(alpha: 0.30), width: 0.8)), position: RelativeRect.fromLTRB(left, top, overlaySize.width - left, overlaySize.height - top), items: const [PopupMenuItem<_ChatMessageAction>(value: _ChatMessageAction.copy, height: 36, padding: EdgeInsets.symmetric(horizontal: 14), child: _MessageActionPillItem(icon: Icons.copy_rounded, label: 'Copy', color: RoomColors.aqua)), PopupMenuItem<_ChatMessageAction>(value: _ChatMessageAction.report, height: 36, padding: EdgeInsets.symmetric(horizontal: 14), child: _MessageActionPillItem(icon: Icons.report_gmailerrorred_rounded, label: 'Report', color: RoomColors.coral))]);
    FocusManager.instance.primaryFocus?.unfocus();
    if (!context.mounted || selected == null) return;
    if (selected == _ChatMessageAction.copy) {
      await Clipboard.setData(ClipboardData(text: messageText));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Message copied'), behavior: SnackBarBehavior.floating, duration: const Duration(milliseconds: 1100), backgroundColor: const Color(0xFF171024).withValues(alpha: 0.96)));
      return;
    }
    RoomToast.show(context, 'Report message will connect here');
  }

  @override
  Widget build(BuildContext context) => GestureDetector(behavior: HitTestBehavior.translucent, onTap: onTap, onLongPressStart: enableMessageActions ? (details) { FocusManager.instance.primaryFocus?.unfocus(); _showMessageActionPill(context, details.globalPosition); } : null, child: Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.105), borderRadius: BorderRadius.circular(7), border: Border.all(color: Colors.white.withValues(alpha: 0.34), width: 0.9), boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.045), blurRadius: 10, spreadRadius: 0.5), BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 8, offset: const Offset(0, 2))]), child: child));
}

class _MessageActionPillItem extends StatelessWidget {
  const _MessageActionPillItem({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: color, size: 17), const SizedBox(width: 7), Text(label, style: const TextStyle(color: RoomColors.plum, fontSize: 12.4, fontWeight: FontWeight.w900))]);
}

class RoomInputDock extends StatelessWidget {
  const RoomInputDock({super.key, required this.controller, this.focusNode, required this.micMuted, required this.showMicButton, required this.inboxUnreadCount, required this.onInboxTap, required this.onEmojiTap, required this.onSendTap, required this.onMicTap, required this.onGamesTap, required this.onGiftTap, this.imagesEnabled = true});

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool micMuted;
  final bool showMicButton;
  final int inboxUnreadCount;
  final VoidCallback onInboxTap;
  final VoidCallback onEmojiTap;
  final VoidCallback onSendTap;
  final VoidCallback onMicTap;
  final VoidCallback onGamesTap;
  final VoidCallback onGiftTap;
  final bool imagesEnabled;

  void _runAndHideSeatActions(VoidCallback action) { dismissRoomSeatActionPill(); action(); }

  Future<void> _pickAndSendImage(BuildContext context) async {
    if (!imagesEnabled) { RoomToast.show(context, 'Image messages are disabled in this room'); return; }
    dismissRoomSeatActionPill();
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      RoomToast.show(context, 'Uploading image...');
      final upload = await const MediaUploadService().pickAndUploadChatImage();
      LiveRoomMessageController.sendActiveRoomImageMessage(imageUrl: upload.url, contentType: upload.contentType);
      if (context.mounted) RoomToast.show(context, 'Image sent');
    } on MediaUploadCancelledException {
      return;
    } catch (error) {
      if (!context.mounted) return;
      RoomToast.show(context, error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _openMessageComposer(BuildContext context) {
    dismissRoomSeatActionPill();
    showModalBottomSheet<void>(context: context, isScrollControlled: true, useSafeArea: false, backgroundColor: Colors.transparent, builder: (_) => LiveRoomMessageComposerModule(controller: controller, focusNode: focusNode, imagesEnabled: imagesEnabled, onSendText: onSendTap, onImageTap: () => _pickAndSendImage(context), onSendFloatingText: onSendTap));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tiny = constraints.maxWidth < 340;
          final compact = constraints.maxWidth < 380;
          final buttonSize = tiny ? 36.0 : compact ? 38.0 : 40.0;
          final iconSize = tiny ? 18.0 : compact ? 19.0 : 20.0;
          final gap = tiny ? 6.0 : 8.0;
          final horizontalPadding = tiny ? 10.0 : 12.0;
          return Container(
            padding: EdgeInsets.fromLTRB(horizontalPadding, 7, horizontalPadding, 8),
            decoration: const BoxDecoration(color: Colors.transparent),
            child: Row(children: [
              _DockButton(icon: Icons.emoji_emotions_rounded, onTap: () => _runAndHideSeatActions(onEmojiTap), active: true, size: buttonSize, iconSize: iconSize),
              SizedBox(width: gap),
              _DockButton(icon: Icons.chat_bubble_outline_rounded, onTap: () => _openMessageComposer(context), size: buttonSize, iconSize: iconSize),
              if (showMicButton) ...[
                SizedBox(width: gap),
                _DockButton(icon: micMuted ? Icons.mic_off_rounded : Icons.mic_rounded, onTap: () => _runAndHideSeatActions(onMicTap), active: !micMuted, muted: micMuted, size: buttonSize, iconSize: iconSize),
              ],
              const Spacer(),
              _DockButton(icon: Icons.mail_outline_rounded, onTap: () => _runAndHideSeatActions(onInboxTap), badgeCount: inboxUnreadCount, size: buttonSize, iconSize: iconSize),
              SizedBox(width: gap),
              SizedBox(width: buttonSize, height: buttonSize, child: LiveRoomGamesModule(onOpenGames: () => _runAndHideSeatActions(onGamesTap), compact: true)),
              SizedBox(width: gap),
              SizedBox(width: buttonSize, height: buttonSize, child: LiveRoomGiftModule(onOpenGiftPanel: () => _runAndHideSeatActions(onGiftTap), comboActive: false)),
            ]),
          );
        },
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({required this.icon, required this.onTap, this.active = false, this.muted = false, this.gift = false, this.badgeCount = 0, this.size = 36, this.iconSize = 19});
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final bool muted;
  final bool gift;
  final int badgeCount;
  final double size;
  final double iconSize;
  @override
  Widget build(BuildContext context) {
    final iconColor = muted ? RoomColors.coral : active ? RoomColors.aqua : Colors.white;
    return Material(color: Colors.transparent, shape: const CircleBorder(), child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: Stack(clipBehavior: Clip.none, children: [Container(width: size, height: size, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.transparent), child: Icon(icon, color: iconColor, size: iconSize)), if (badgeCount > 0) Positioned(right: -2, top: -3, child: Container(constraints: const BoxConstraints(minWidth: 16, minHeight: 16), padding: const EdgeInsets.symmetric(horizontal: 4), alignment: Alignment.center, decoration: BoxDecoration(color: RoomColors.coral, borderRadius: BorderRadius.circular(999), border: Border.all(color: RoomColors.deep, width: 1)), child: Text(badgeCount > 99 ? '99+' : '$badgeCount', style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900))))])));
  }
}
