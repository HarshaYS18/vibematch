import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'room_seats.dart';
import 'room_text_bubbles.dart';
import 'room_theme.dart';

class RoomChatFeed extends StatefulWidget {
  const RoomChatFeed({
    super.key,
    required this.messages,
    required this.canManageSeatApplications,
    required this.onApproveSeatApplication,
    this.onSenderTap,
  });

  final List<ChatEntry> messages;
  final bool canManageSeatApplications;
  final ValueChanged<ChatEntry> onApproveSeatApplication;
  final ValueChanged<ChatEntry>? onSenderTap;

  @override
  State<RoomChatFeed> createState() => _RoomChatFeedState();
}

class _RoomChatFeedState extends State<RoomChatFeed> {
  late final ScrollController _scrollController;
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _lastMessageCount = widget.messages.length;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(jump: true));
  }

  @override
  void didUpdateWidget(covariant RoomChatFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length != _lastMessageCount) {
      _lastMessageCount = widget.messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool jump = false}) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (jump) {
      _scrollController.jumpTo(target);
      return;
    }
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.messages.isEmpty) return const SizedBox.expand();
    final visibleMessages = widget.messages.reversed.toList(growable: false);

    return ListView.builder(
      controller: _scrollController,
      reverse: false,
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
            onApproveSeatApplication: () => widget.onApproveSeatApplication(message),
          ),
        );
      },
    );
  }
}

class _CompactChatLine extends StatelessWidget {
  const _CompactChatLine({
    required this.message,
    required this.canManageSeatApplications,
    required this.onApproveSeatApplication,
    this.onSenderTap,
  });

  final ChatEntry message;
  final bool canManageSeatApplications;
  final VoidCallback onApproveSeatApplication;
  final VoidCallback? onSenderTap;

  @override
  Widget build(BuildContext context) {
    final showAgree = message.isSeatApplication && canManageSeatApplications && !message.applicationApproved;
    final isSystem = message.senderId == 'system';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (!isSystem) ...[
            GestureDetector(
              onTap: onSenderTap,
              child: CircleAvatar(
                radius: 13.5,
                backgroundColor: message.isGift
                    ? RoomColors.gold
                    : message.isSeatApplication
                        ? RoomColors.aqua
                        : RoomColors.violet,
                child: Text(
                  avatarLetter(message.senderName),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: RichText(
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                children: [
                  if (isSystem)
                    TextSpan(text: message.message, style: const TextStyle(color: RoomColors.gold, fontSize: 14.5, fontWeight: FontWeight.w900, height: 1.15))
                  else ...[
                    TextSpan(
                      text: message.senderName,
                      recognizer: TapGestureRecognizer()..onTap = onSenderTap,
                      style: const TextStyle(color: Colors.white, fontSize: 14.8, fontWeight: FontWeight.w900, height: 1.15),
                    ),
                    TextSpan(text: '  VIP ${message.vipLevel}: ', style: TextStyle(color: RoomColors.gold.withValues(alpha: 0.96), fontSize: 13.2, fontWeight: FontWeight.w900, height: 1.15)),
                    ..._messageSpans(message),
                  ],
                ],
              ),
            ),
          ),
          if (showAgree) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onApproveSeatApplication,
              child: Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: RoomColors.aqua, borderRadius: BorderRadius.circular(999), boxShadow: [BoxShadow(color: RoomColors.aqua.withValues(alpha: 0.24), blurRadius: 10, offset: const Offset(0, 4))]),
                child: const Text('Agree', style: TextStyle(color: RoomColors.deep, fontSize: 11, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<TextSpan> _messageSpans(ChatEntry message) {
    final text = message.message;
    final mentionRegex = RegExp(r'@\w+');
    final spans = <TextSpan>[];
    var cursor = 0;

    for (final match in mentionRegex.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(_normalSpan(text.substring(cursor, match.start), message));
      }
      spans.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: const TextStyle(color: RoomColors.aqua, fontSize: 14.2, fontWeight: FontWeight.w900, height: 1.15),
      ));
      cursor = match.end;
    }

    if (cursor < text.length) spans.add(_normalSpan(text.substring(cursor), message));
    return spans;
  }

  TextSpan _normalSpan(String text, ChatEntry message) {
    return TextSpan(
      text: text,
      style: TextStyle(
        color: message.isGift
            ? RoomColors.gold
            : message.isSeatApplication
                ? RoomColors.aqua
                : Colors.white.withValues(alpha: 0.90),
        fontSize: 14.2,
        height: 1.15,
        fontWeight: message.isGift || message.isSeatApplication ? FontWeight.w900 : FontWeight.w800,
      ),
    );
  }
}

class RoomInputDock extends StatelessWidget {
  const RoomInputDock({
    super.key,
    required this.controller,
    this.focusNode,
    required this.micMuted,
    required this.inboxUnreadCount,
    required this.onInboxTap,
    required this.onEmojiTap,
    required this.onSendTap,
    required this.onMicTap,
    required this.onGamesTap,
    required this.onGiftTap,
    this.imagesEnabled = true,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool micMuted;
  final int inboxUnreadCount;
  final VoidCallback onInboxTap;
  final VoidCallback onEmojiTap;
  final VoidCallback onSendTap;
  final VoidCallback onMicTap;
  final VoidCallback onGamesTap;
  final VoidCallback onGiftTap;
  final bool imagesEnabled;

  void _runAndHideSeatActions(VoidCallback action) {
    dismissRoomSeatActionPill();
    action();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
        decoration: BoxDecoration(
          color: RoomColors.deep.withValues(alpha: 0.94),
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
        ),
        child: Row(
          children: [
            _DockButton(icon: Icons.mail_outline_rounded, onTap: () => _runAndHideSeatActions(onInboxTap), badgeCount: inboxUnreadCount),
            const SizedBox(width: 5),
            Expanded(
              child: Container(
                height: 38,
                padding: const EdgeInsets.only(left: 10),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.30), borderRadius: BorderRadius.circular(19), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5),
                        decoration: InputDecoration(
                          hintText: 'Message...',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.36), fontWeight: FontWeight.w800),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onTap: dismissRoomSeatActionPill,
                        onSubmitted: (_) => _runAndHideSeatActions(onSendTap),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      onPressed: imagesEnabled ? () => _runAndHideSeatActions(() => RoomToast.show(context, 'Image message picker will connect here')) : null,
                      icon: Icon(Icons.image_rounded, color: Colors.white.withValues(alpha: imagesEnabled ? 0.78 : 0.22), size: 20),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      onPressed: () => _runAndHideSeatActions(onEmojiTap),
                      icon: const Icon(Icons.emoji_emotions_rounded, color: RoomColors.gold, size: 20),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      onPressed: () => _runAndHideSeatActions(onSendTap),
                      icon: const Icon(Icons.send_rounded, color: RoomColors.aqua, size: 21),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 5),
            _DockButton(icon: micMuted ? Icons.mic_off_rounded : Icons.mic_rounded, onTap: () => _runAndHideSeatActions(onMicTap), active: !micMuted, muted: micMuted),
            const SizedBox(width: 5),
            _DockButton(icon: Icons.sports_esports_rounded, onTap: () => _runAndHideSeatActions(onGamesTap)),
            const SizedBox(width: 5),
            _DockButton(icon: Icons.card_giftcard_rounded, onTap: () => _runAndHideSeatActions(onGiftTap), gift: true),
          ],
        ),
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({required this.icon, required this.onTap, this.active = false, this.muted = false, this.gift = false, this.badgeCount = 0});

  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final bool muted;
  final bool gift;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final bg = muted ? RoomColors.coral.withValues(alpha: 0.22) : active ? RoomColors.aqua.withValues(alpha: 0.24) : Colors.white.withValues(alpha: 0.055);
    final iconColor = muted ? RoomColors.coral : active ? RoomColors.aqua : Colors.white;

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
              width: 36,
              height: 36,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: gift ? const LinearGradient(colors: [RoomColors.gold, RoomColors.coral]) : null, color: gift ? null : bg, border: Border.all(color: Colors.white.withValues(alpha: 0.09))),
              child: Icon(icon, color: gift ? Colors.white : iconColor, size: 19),
            ),
            if (badgeCount > 0)
              Positioned(
                right: -2,
                top: -3,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: RoomColors.coral, borderRadius: BorderRadius.circular(999), border: Border.all(color: RoomColors.deep, width: 1)),
                  child: Text(badgeCount > 99 ? '99+' : '$badgeCount', style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
