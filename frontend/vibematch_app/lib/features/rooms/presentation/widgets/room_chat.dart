import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../../core/widgets/vm_gradient_name_text.dart';
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

void clearRoomChatHistory() => roomChatClearSignal.value++;

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
  Timer? _ticker;
  int _clearedMessageCount = 0;
  int _lastMessageCount = 0;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _lastMessageCount = widget.messages.length;
    roomChatClearSignal.addListener(_handleClearChat);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToBottom(jump: true),
    );
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _tick++);
    });
  }

  @override
  void didUpdateWidget(covariant RoomChatFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length < _clearedMessageCount)
      _clearedMessageCount = widget.messages.length;
    if (widget.messages.length != _lastMessageCount) {
      _lastMessageCount = widget.messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  @override
  void dispose() {
    roomChatClearSignal.removeListener(_handleClearChat);
    _ticker?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleClearChat() {
    if (mounted) setState(() => _clearedMessageCount = widget.messages.length);
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
    _tick;
    final newMessageCount = (widget.messages.length - _clearedMessageCount)
        .clamp(0, widget.messages.length);
    if (newMessageCount == 0) return const SizedBox.expand();

    final visibleMessages = widget.messages
        .take(newMessageCount)
        .where((message) => !message.autoDismissed)
        .toList(growable: false)
        .reversed
        .toList(growable: false);

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
            onSenderTap: widget.onSenderTap == null
                ? null
                : () => widget.onSenderTap!(message),
            onMentionTap: widget.onMentionTap,
            onApproveSeatApplication: () =>
                widget.onApproveSeatApplication(message),
            onRejectSeatApplication: () =>
                widget.onRejectSeatApplication(message),
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
    required this.onRejectSeatApplication,
    this.onSenderTap,
    this.onMentionTap,
  });

  final ChatEntry message;
  final bool canManageSeatApplications;
  final VoidCallback onApproveSeatApplication;
  final VoidCallback onRejectSeatApplication;
  final VoidCallback? onSenderTap;
  final ValueChanged<String>? onMentionTap;

  @override
  Widget build(BuildContext context) {
    if (message.isSystemMessage)
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: _SystemEventLine(message: message),
      );

    final showActions =
        message.isSeatApplication &&
        canManageSeatApplications &&
        !message.applicationResolved;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            fit: FlexFit.loose,
            child: _ChatGlassBox(
              onTap: onSenderTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ChatAvatar(
                    senderName: message.senderName,
                    avatarUrl: message.senderAvatarUrl,
                    radius: 13.5,
                    backgroundColor: message.isSeatApplication
                        ? RoomColors.aqua
                        : RoomColors.violet,
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
                          text: TextSpan(
                            children: [
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: ChatVipBadge(
                                  level: message.vipLevel,
                                  showWhenZero: true,
                                ),
                              ),
                              const TextSpan(text: '  '),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: GestureDetector(
                                  onTap: onSenderTap,
                                  child: VmGradientNameText(
                                    text: message.senderName,
                                    gradientColors: message.senderNameGradientColors,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.8,
                                      fontWeight: FontWeight.w900,
                                      height: 1.15,
                                    ),
                                  ),
                                ),
                              ),
                              const TextSpan(text: '\n '),
                              ..._messageSpans(message, onMentionTap),
                            ],
                          ),
                        ),
                        if (message.isImageMessage) ...[
                          const SizedBox(height: 6),
                          _ChatImagePreview(imageUrl: message.imageUrl!),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showActions) ...[
            const SizedBox(width: 8),
            _SeatApplicationActionButton(
              label: 'Reject',
              background: RoomColors.coral.withValues(alpha: 0.92),
              foreground: Colors.white,
              onTap: onRejectSeatApplication,
            ),
            const SizedBox(width: 6),
            _SeatApplicationActionButton(
              label: 'Agree',
              background: RoomColors.aqua,
              foreground: RoomColors.deep,
              onTap: onApproveSeatApplication,
            ),
          ],
        ],
      ),
    );
  }

  List<InlineSpan> _messageSpans(ChatEntry message, ValueChanged<String>? onMentionTap) {
    final parts = message.message.split(RegExp(r'(\s+)'));
    return parts.map((part) {
      final isMention = part.startsWith('@') && part.length > 1;
      if (!isMention) {
        return TextSpan(
          text: part,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.94),
            fontSize: 13.2,
            fontWeight: FontWeight.w700,
            height: 1.24,
          ),
        );
      }
      return TextSpan(
        text: part,
        recognizer: TapGestureRecognizer()
          ..onTap = () => onMentionTap?.call(part.replaceFirst('@', '')),
        style: const TextStyle(
          color: RoomColors.aqua,
          fontSize: 13.2,
          fontWeight: FontWeight.w900,
          height: 1.24,
        ),
      );
    }).toList(growable: false);
  }
}

class _SystemEventLine extends StatelessWidget {
  const _SystemEventLine({required this.message});

  final ChatEntry message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Text(
          message.message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: 11.2,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ChatGlassBox extends StatelessWidget {
  const _ChatGlassBox({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          child: child,
        ),
      ),
    );
  }
}

class _ChatAvatar extends StatelessWidget {
  const _ChatAvatar({
    required this.senderName,
    this.avatarUrl,
    required this.radius,
    required this.backgroundColor,
  });

  final String senderName;
  final String? avatarUrl;
  final double radius;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      backgroundImage: url == null || url.isEmpty ? null : NetworkImage(url),
      child: url == null || url.isEmpty
          ? Text(
              avatarLetter(senderName),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
            )
          : null,
    );
  }
}

class _ChatImagePreview extends StatelessWidget {
  const _ChatImagePreview({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        imageUrl,
        width: 168,
        height: 118,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 168,
          height: 74,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Text(
            'Image unavailable',
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

class _SeatApplicationActionButton extends StatelessWidget {
  const _SeatApplicationActionButton({required this.label, required this.background, required this.foreground, required this.onTap});

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          child: Text(
            label,
            style: TextStyle(color: foreground, fontSize: 11, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}
