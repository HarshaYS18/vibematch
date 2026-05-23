import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/app_routes.dart';
import '../../controllers/inbox_controller.dart';
import '../../models/inbox_models.dart';
import '../widgets/inbox_call_action_sheet.dart';
import '../widgets/inbox_call_realtime_presenter.dart';
import '../widgets/swipe_reply_message.dart';

class InboxChatPage extends StatefulWidget {
  const InboxChatPage({
    super.key,
    required this.conversation,
    required this.controller,
    required this.onMoreTap,
    this.onBackTap,
  });

  final InboxConversation conversation;
  final InboxController controller;
  final VoidCallback onMoreTap;
  final VoidCallback? onBackTap;

  @override
  State<InboxChatPage> createState() => _InboxChatPageState();
}

class _InboxChatPageState extends State<InboxChatPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _replyToText;
  String? _lastActivity;

  static const Color paper = Color(0xFFFAF7F1);
  static const Color ink = Color(0xFF17111F);
  static const Color plum = Color(0xFF251538);
  static const Color aqua = Color(0xFF12C7B7);
  static const Color violet = Color(0xFF7C3AED);
  static const Color pink = Color(0xFFE84C72);

  InboxConversation get _conversation =>
      widget.controller.conversationById(widget.conversation.id) ??
      widget.conversation;

  bool get _readOnly => _conversation.isOfficial || _conversation.isStranger;

  @override
  void initState() {
    super.initState();
    widget.controller.markConversationRead(widget.conversation.id);
    widget.controller.addListener(_handleChanged);
    _textController.addListener(_handleInputChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted)
        unawaited(
          widget.controller.openConversationFromBackend(widget.conversation.id),
        );
    });
  }

  @override
  void dispose() {
    unawaited(
      widget.controller.closeSecretDriftSession(conversation: _conversation),
    );
    widget.controller.clearActiveConversation(widget.conversation.id);
    widget.controller.removeListener(_handleChanged);
    _textController.removeListener(_handleInputChanged);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleChanged() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  void _jumpToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _sendActivity(String activity) {
    if (_lastActivity == activity) return;
    _lastActivity = activity;
    widget.controller.sendChatActivity(
      conversationId: _conversation.id,
      activity: activity,
    );
  }

  void _handleInputChanged() {
    if (!mounted) return;
    _sendActivity(_textController.text.trim().isEmpty ? 'idle' : 'typing');
    setState(() {});
  }

  void _sendText() {
    final text = _textController.text.trim();
    if (_readOnly || text.isEmpty) return;
    widget.controller.sendTextMessage(
      conversationId: _conversation.id,
      text: text,
      replyToText: _replyToText,
    );
    _textController.clear();
    _sendActivity('idle');
    setState(() => _replyToText = null);
  }

  Future<void> _handleBack() async {
    final customBack = widget.onBackTap;
    if (customBack != null) {
      customBack();
      return;
    }
    Navigator.maybePop(context);
  }

  void _openCallSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => InboxCallActionSheet(
        conversation: _conversation,
        callController: widget.controller.callController,
      ),
    );
  }

  void _openInvitedRoom(InboxMessage message) {
    final conversation = _conversation;
    final roomName =
        message.inviteRoomName ?? conversation.currentRoomName ?? 'Live Room';
    final roomId =
        message.inviteRoomId ?? conversation.currentRoomId ?? roomName;
    Navigator.pushNamed(
      context,
      VmRoutes.liveRoom,
      arguments: LiveRoomRouteArgs(
        roomName: roomName,
        roomId: roomId,
        language: 'Telugu',
        modeTitle: 'Open',
        onlineCount: 1,
      ),
    );
  }

  String _statusText(InboxConversation conversation) {
    final remote = widget.controller.remoteActivityForConversation(
      conversation.id,
    );
    if (remote != null) return remote.replaceAll('_', ' ');
    if (conversation.isOnline) return 'online';
    return conversation.safePresenceText;
  }

  @override
  Widget build(BuildContext context) {
    final conversation = _conversation;
    final messages = conversation.messages;
    return InboxCallRealtimePresenter(
      callController: widget.controller.callController,
      child: Scaffold(
        backgroundColor: paper,
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(
                conversation: conversation,
                statusText: _statusText(conversation),
                onBack: () => unawaited(_handleBack()),
                onCall: _openCallSheet,
                onMore: widget.onMoreTap,
              ),
              if (conversation.secretDriftEnabled)
                _SlimNotice(text: conversation.secretDriftLabel),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [paper, Color(0xFFF2EDF8)],
                    ),
                  ),
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: SwipeReplyMessage(
                          isMine: message.isMine,
                          onReply: () =>
                              setState(() => _replyToText = message.text),
                          child: _MessageBubble(
                            message: message,
                            onLongPress: widget.onMoreTap,
                            onInviteTap: message.isInvite
                                ? () => _openInvitedRoom(message)
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (_replyToText != null)
                _ReplyPreview(
                  text: _replyToText!,
                  onClose: () => setState(() => _replyToText = null),
                ),
              _Composer(
                readOnly: _readOnly,
                controller: _textController,
                onSend: _sendText,
                onAttach: () => widget.controller.addGeneratedAttachment(
                  conversationId: conversation.id,
                  type: InboxMessageType.image,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.conversation,
    required this.statusText,
    required this.onBack,
    required this.onCall,
    required this.onMore,
  });

  final InboxConversation conversation;
  final String statusText;
  final VoidCallback onBack;
  final VoidCallback onCall;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = conversation.avatarUrl?.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _InboxChatPageState.ink,
              size: 20,
            ),
          ),
          Container(
            width: 44,
            height: 44,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: conversation.colors),
            ),
            child: CircleAvatar(
              backgroundColor: _InboxChatPageState.plum,
              backgroundImage: avatarUrl == null || avatarUrl.isEmpty
                  ? null
                  : NetworkImage(avatarUrl),
              child: avatarUrl == null || avatarUrl.isEmpty
                  ? Text(
                      conversation.avatarText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        conversation.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _InboxChatPageState.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (conversation.isOfficial)
                      const Icon(
                        Icons.verified_rounded,
                        color: Color(0xFFC99A3B),
                        size: 16,
                      ),
                  ],
                ),
                Text(
                  statusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF756A7D),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCall,
            icon: const Icon(
              Icons.call_rounded,
              color: _InboxChatPageState.ink,
              size: 21,
            ),
          ),
          IconButton(
            onPressed: onCall,
            icon: const Icon(
              Icons.videocam_rounded,
              color: _InboxChatPageState.ink,
              size: 22,
            ),
          ),
          IconButton(
            onPressed: onMore,
            icon: const Icon(
              Icons.more_horiz_rounded,
              color: _InboxChatPageState.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.onLongPress,
    required this.onInviteTap,
  });

  final InboxMessage message;
  final VoidCallback onLongPress;
  final VoidCallback? onInviteTap;

  @override
  Widget build(BuildContext context) {
    final mine = message.isMine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        onDoubleTap: onLongPress,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.76,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: mine
                  ? const LinearGradient(
                      colors: [
                        _InboxChatPageState.violet,
                        _InboxChatPageState.pink,
                      ],
                    )
                  : null,
              color: mine ? null : Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(21),
                topRight: const Radius.circular(21),
                bottomLeft: Radius.circular(mine ? 21 : 7),
                bottomRight: Radius.circular(mine ? 7 : 21),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xFF251538,
                  ).withValues(alpha: mine ? 0.13 : 0.055),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: _body(mine),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(bool mine) {
    if (message.isInvite) {
      return InkWell(
        onTap: onInviteTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.meeting_room_rounded,
              color: mine ? Colors.white : _InboxChatPageState.aqua,
              size: 20,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message.inviteRoomName ?? message.text,
                style: TextStyle(
                  color: mine ? Colors.white : _InboxChatPageState.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      );
    }
    final text = switch (message.type) {
      InboxMessageType.image => 'Photo • ${message.text}',
      InboxMessageType.document => 'Document • ${message.text}',
      InboxMessageType.voice => 'Voice message',
      InboxMessageType.callLog => 'Call • ${message.text}',
      _ => message.text,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.replyToText != null)
          Container(
            margin: const EdgeInsets.only(bottom: 7),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: mine
                  ? Colors.white.withValues(alpha: 0.15)
                  : const Color(0xFFF1EAF8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message.replyToText!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: mine ? Colors.white70 : const Color(0xFF74647F),
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        Text(
          text,
          style: TextStyle(
            color: mine ? Colors.white : _InboxChatPageState.ink,
            fontSize: 14,
            height: 1.34,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.time,
              style: TextStyle(
                color: mine ? Colors.white70 : const Color(0xFF9A8FA4),
                fontSize: 10.3,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (mine) ...[
              const SizedBox(width: 5),
              Icon(
                message.status == InboxMessageStatus.read
                    ? Icons.done_all_rounded
                    : Icons.done_rounded,
                color: Colors.white70,
                size: 13,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({required this.text, required this.onClose});
  final String text;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
      color: _InboxChatPageState.paper,
      child: Row(
        children: [
          Container(
            width: 3,
            height: 30,
            decoration: BoxDecoration(
              color: _InboxChatPageState.aqua,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF756A7D),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.readOnly,
    required this.controller,
    required this.onSend,
    required this.onAttach,
  });
  final bool readOnly;
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    final canSend = controller.text.trim().isNotEmpty && !readOnly;
    return Container(
      padding: EdgeInsets.fromLTRB(
        10,
        8,
        10,
        10 + MediaQuery.paddingOf(context).bottom,
      ),
      color: _InboxChatPageState.paper,
      child: Row(
        children: [
          _RoundIcon(
            icon: Icons.add_rounded,
            onTap: readOnly ? null : onAttach,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.045),
                    blurRadius: 13,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: TextField(
                controller: controller,
                enabled: !readOnly,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: readOnly ? 'Read-only chat' : 'Message',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _RoundIcon(
            icon: canSend ? Icons.arrow_upward_rounded : Icons.mic_rounded,
            onTap: canSend ? onSend : null,
            filled: canSend,
          ),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.onTap,
    this.filled = false,
  });
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: filled ? _InboxChatPageState.plum : Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: filled ? Colors.white : _InboxChatPageState.plum,
          size: 21,
        ),
      ),
    );
  }
}

class _SlimNotice extends StatelessWidget {
  const _SlimNotice({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: const Color(0xFFEFE7F7),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _InboxChatPageState.plum,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
