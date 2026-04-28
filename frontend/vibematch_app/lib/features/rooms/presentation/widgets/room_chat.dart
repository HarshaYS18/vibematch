import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../live_room_models.dart';
import 'room_action_pages.dart';
import 'room_seats.dart';
import 'room_text_bubbles.dart';
import 'room_theme.dart';
import 'vip_badge.dart';

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
  int _clearedMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _lastMessageCount = widget.messages.length;
    roomChatClearSignal.addListener(_handleClearChat);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(jump: true));
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
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final newMessageCount = (widget.messages.length - _clearedMessageCount).clamp(0, widget.messages.length);
    if (newMessageCount == 0) return const SizedBox.expand();
    final visibleMessages = widget.messages.take(newMessageCount).toList(growable: false).reversed.toList(growable: false);

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

    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              fit: FlexFit.loose,
              child: _TransparentUserMessageFlexBox(
                messageText: message.message,
                enableMessageActions: false,
                child: Text(
                  message.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RoomColors.gold,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final row = Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            fit: FlexFit.loose,
            child: _TransparentUserMessageFlexBox(
              messageText: message.message,
              enableMessageActions: !message.isGift,
              onTap: onSenderTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    fit: FlexFit.loose,
                    child: RichText(
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        children: [
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _openVipSvipCenter(context),
                              child: VipBadge(
                                level: message.vipLevel,
                                size: VipBadgeSize.tiny,
                                showWhenZero: true,
                              ),
                            ),
                          ),
                          const TextSpan(text: '  '),
                          TextSpan(
                            text: message.senderName,
                            recognizer: TapGestureRecognizer()..onTap = onSenderTap,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14.8,
                              fontWeight: FontWeight.w900,
                              height: 1.15,
                            ),
                          ),
                          const TextSpan(text: '  '),
                          ..._messageSpans(message),
                        ],
                      ),
                    ),
                  ),
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
                decoration: BoxDecoration(
                  color: RoomColors.aqua,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: RoomColors.aqua.withValues(alpha: 0.24),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Text(
                  'Agree',
                  style: TextStyle(
                    color: RoomColors.deep,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return row;
  }

  void _openVipSvipCenter(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoomActionPage(
          title: 'VIP & SVIP Centre',
          subtitle:
              '${message.senderName} is VIP ${message.vipLevel}. VIP benefits, SVIP rules, badge upgrades, recharge progress and frozen VIP status will connect here.',
          icon: Icons.workspace_premium_rounded,
          cards: [
            RoomActionCard(
              title: 'Current VIP',
              value: 'VIP ${message.vipLevel}',
              icon: Icons.workspace_premium_rounded,
              color: RoomColors.gold,
            ),
            RoomActionCard(
              title: 'Monthly SVIP',
              value: 'SVIP status connects from backend',
              icon: Icons.auto_awesome_rounded,
              color: RoomColors.violet,
            ),
            const RoomActionCard(
              title: 'VIP 30+ shine',
              value: 'Premium badge shine and extra glow unlock at VIP 30+',
              icon: Icons.auto_awesome_rounded,
              color: RoomColors.aqua,
            ),
          ],
        ),
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
      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: const TextStyle(
            color: RoomColors.aqua,
            fontSize: 14.2,
            fontWeight: FontWeight.w900,
            height: 1.15,
          ),
        ),
      );
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

enum _ChatMessageAction { copy, report }

class _TransparentUserMessageFlexBox extends StatelessWidget {
  const _TransparentUserMessageFlexBox({
    required this.child,
    required this.messageText,
    this.onTap,
    this.enableMessageActions = true,
  });

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

    final selected = await showMenu<_ChatMessageAction>(
      context: context,
      color: Colors.white.withValues(alpha: 0.40),
      elevation: 14,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.30), width: 0.8),
      ),
      position: RelativeRect.fromLTRB(
        left,
        top,
        overlaySize.width - left,
        overlaySize.height - top,
      ),
      items: const [
        PopupMenuItem<_ChatMessageAction>(
          value: _ChatMessageAction.copy,
          height: 36,
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: _MessageActionPillItem(
            icon: Icons.copy_rounded,
            label: 'Copy',
            color: RoomColors.aqua,
          ),
        ),
        PopupMenuItem<_ChatMessageAction>(
          value: _ChatMessageAction.report,
          height: 36,
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: _MessageActionPillItem(
            icon: Icons.report_gmailerrorred_rounded,
            label: 'Report',
            color: RoomColors.coral,
          ),
        ),
      ],
    );

    FocusManager.instance.primaryFocus?.unfocus();
    if (!context.mounted || selected == null) return;

    if (selected == _ChatMessageAction.copy) {
      FocusManager.instance.primaryFocus?.unfocus();
      await Clipboard.setData(ClipboardData(text: messageText));
      FocusManager.instance.primaryFocus?.unfocus();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Message copied'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1100),
          backgroundColor: const Color(0xFF171024).withValues(alpha: 0.96),
        ),
      );
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    RoomToast.show(context, 'Report message will connect here');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      onLongPressStart: enableMessageActions
          ? (details) {
              FocusManager.instance.primaryFocus?.unfocus();
              _showMessageActionPill(context, details.globalPosition);
            }
          : null,
      child: Container(
        // Dynamic user-message flex box with a very light foggy white fill.
        // It improves message readability while keeping the chat background visible.
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.105),
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.34),
            width: 0.9,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.045),
              blurRadius: 10,
              spreadRadius: 0.5,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _MessageActionPillItem extends StatelessWidget {
  const _MessageActionPillItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 17),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            color: RoomColors.plum,
            fontSize: 12.4,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tiny = constraints.maxWidth < 340;
          final compact = constraints.maxWidth < 380;
          final gap = tiny ? 3.0 : compact ? 4.0 : 5.0;
          final horizontalPadding = tiny ? 6.0 : 8.0;
          final dockButtonSize = tiny ? 31.0 : compact ? 33.0 : 36.0;
          final dockIconSize = tiny ? 17.0 : compact ? 18.0 : 19.0;
          final inputHeight = tiny ? 36.0 : 38.0;
          final inputIconMin = tiny ? 26.0 : 30.0;
          final inputIconSize = tiny ? 18.0 : 20.0;
          final showImageButton = constraints.maxWidth >= 330;

          return Container(
            padding: EdgeInsets.fromLTRB(horizontalPadding, 5, horizontalPadding, 6),
            decoration: BoxDecoration(
              color: RoomColors.deep.withValues(alpha: 0.94),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
            ),
            child: Row(
              children: [
                _DockButton(
                  icon: Icons.mail_outline_rounded,
                  onTap: () => _runAndHideSeatActions(onInboxTap),
                  badgeCount: inboxUnreadCount,
                  size: dockButtonSize,
                  iconSize: dockIconSize,
                ),
                SizedBox(width: gap),
                Expanded(
                  child: Container(
                    height: inputHeight,
                    padding: EdgeInsets.only(left: tiny ? 8 : 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.30),
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            focusNode: focusNode,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: tiny ? 12.8 : 13.5,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Message...',
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.36),
                                fontWeight: FontWeight.w800,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            onTap: dismissRoomSeatActionPill,
                            onSubmitted: (_) => _runAndHideSeatActions(onSendTap),
                          ),
                        ),
                        if (showImageButton)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(minWidth: inputIconMin, minHeight: inputIconMin),
                            onPressed: imagesEnabled
                                ? () => _runAndHideSeatActions(
                                      () => RoomToast.show(context, 'Image message picker will connect here'),
                                    )
                                : null,
                            icon: Icon(
                              Icons.image_rounded,
                              color: Colors.white.withValues(alpha: imagesEnabled ? 0.78 : 0.22),
                              size: inputIconSize,
                            ),
                          ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(minWidth: inputIconMin, minHeight: inputIconMin),
                          onPressed: () => _runAndHideSeatActions(onEmojiTap),
                          icon: Icon(Icons.emoji_emotions_rounded, color: RoomColors.gold, size: inputIconSize),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(minWidth: inputIconMin, minHeight: inputIconMin),
                          onPressed: () => _runAndHideSeatActions(onSendTap),
                          icon: Icon(Icons.send_rounded, color: RoomColors.aqua, size: inputIconSize + 1),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: gap),
                _DockButton(
                  icon: micMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  onTap: () => _runAndHideSeatActions(onMicTap),
                  active: !micMuted,
                  muted: micMuted,
                  size: dockButtonSize,
                  iconSize: dockIconSize,
                ),
                SizedBox(width: gap),
                _DockButton(
                  icon: Icons.sports_esports_rounded,
                  onTap: () => _runAndHideSeatActions(onGamesTap),
                  size: dockButtonSize,
                  iconSize: dockIconSize,
                ),
                SizedBox(width: gap),
                _DockButton(
                  icon: Icons.card_giftcard_rounded,
                  onTap: () => _runAndHideSeatActions(onGiftTap),
                  gift: true,
                  size: dockButtonSize,
                  iconSize: dockIconSize,
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
    this.gift = false,
    this.badgeCount = 0,
    this.size = 36,
    this.iconSize = 19,
  });

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
    final bg = muted
        ? RoomColors.coral.withValues(alpha: 0.22)
        : active
            ? RoomColors.aqua.withValues(alpha: 0.24)
            : Colors.white.withValues(alpha: 0.055);
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
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: gift ? const LinearGradient(colors: [RoomColors.gold, RoomColors.coral]) : null,
                color: gift ? null : bg,
                border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
              ),
              child: Icon(icon, color: gift ? Colors.white : iconColor, size: iconSize),
            ),
            if (badgeCount > 0)
              Positioned(
                right: -2,
                top: -3,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
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
                      fontSize: 8.5,
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
