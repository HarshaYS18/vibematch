import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../app/app_routes.dart';
import '../../controllers/inbox_controller.dart';
import '../../models/inbox_models.dart';
import '../widgets/inbox_message_media_content.dart';
import '../widgets/social_emoji_pack_sheet.dart';
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

  InboxConversation get _conversation => widget.controller.conversationById(widget.conversation.id) ?? widget.conversation;

  bool get _readOnly {
    final conversation = _conversation;
    return conversation.isOfficial || conversation.isStranger || conversation.isBlocked;
  }

  @override
  void initState() {
    super.initState();
    widget.controller.markConversationRead(widget.conversation.id);
    widget.controller.addListener(_handleChanged);
  }

  @override
  void dispose() {
    widget.controller.clearActiveConversation(widget.conversation.id);
    widget.controller.removeListener(_handleChanged);
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

  void _sendText() {
    if (_readOnly) return;
    widget.controller.sendTextMessage(
      conversationId: _conversation.id,
      text: _textController.text,
      replyToText: _replyToText,
    );
    _textController.clear();
    setState(() => _replyToText = null);
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF251538),
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      );
  }

  void _openInvitedRoom(InboxMessage message) {
    final conversation = _conversation;
    final roomName = message.inviteRoomName ?? conversation.currentRoomName ?? 'Live Room';
    final roomId = message.inviteRoomId ?? conversation.currentRoomId ?? roomName;
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

  void _insertEmoji(String emoji) {
    final selection = _textController.selection;
    final oldText = _textController.text;
    final start = selection.start >= 0 ? selection.start : oldText.length;
    final end = selection.end >= 0 ? selection.end : oldText.length;
    final newText = oldText.replaceRange(start, end, emoji);
    final newOffset = start + emoji.length;
    _textController.value = TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: newOffset));
  }

  void _openEmojiPack() {
    if (_readOnly) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SocialEmojiPackSheet(onEmojiSelected: _insertEmoji),
    );
  }

  Future<void> _pickDocumentAttachment() async {
    if (_readOnly) return;
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: false, type: FileType.any, withData: false, withReadStream: false);
      final file = result?.files.single;
      if (file == null) return;
      widget.controller.addPickedDocumentAttachment(
        conversationId: _conversation.id,
        fileName: file.name,
        sizeBytes: file.size,
        filePath: file.path,
      );
    } catch (_) {
      _showToast('Document picker failed. Please try again.');
    }
  }

  Future<void> _openAttachmentSheet() async {
    if (_readOnly) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AttachmentSheet(
        onPick: (type) async {
          Navigator.pop(context);
          if (type == InboxMessageType.document) {
            await _pickDocumentAttachment();
            return;
          }
          widget.controller.addMockAttachment(conversationId: _conversation.id, type: type);
        },
      ),
    );
  }

  Future<void> _acceptLoveBondRequest(InboxMessage message) async {
    await widget.controller.acceptLoveBondRequest(conversationId: _conversation.id, message: message);
    if (mounted) _showToast('Relationship request accepted.');
  }

  Future<void> _rejectLoveBondRequest(InboxMessage message) async {
    await widget.controller.rejectLoveBondRequest(conversationId: _conversation.id, message: message);
    if (mounted) _showToast('Relationship request rejected.');
  }

  void _openMessageActions(InboxMessage message) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MessageActionsSheet(
        message: message,
        onReply: () {
          Navigator.pop(context);
          setState(() => _replyToText = message.text);
        },
        onCopy: () {
          Navigator.pop(context);
          _showToast('Copy mapped locally. Clipboard wiring later.');
        },
        onStar: () {
          Navigator.pop(context);
          widget.controller.toggleStarMessage(conversationId: _conversation.id, message: message);
        },
        onForward: () {
          Navigator.pop(context);
          widget.controller.forwardMessage(fromConversationId: _conversation.id, message: message);
        },
        onDelete: () {
          Navigator.pop(context);
          widget.controller.deleteMessage(conversationId: _conversation.id, message: message);
        },
        onReaction: (reaction) {
          Navigator.pop(context);
          widget.controller.setReaction(conversationId: _conversation.id, message: message, reaction: reaction);
        },
      ),
    );
  }

  void _openCallPlaceholder({required bool video}) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CallFoundationSheet(conversation: _conversation, isVideo: video),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conversation = _conversation;
    final messages = conversation.messages;
    return Scaffold(
      backgroundColor: const Color(0xFF12091F),
      body: SafeArea(
        child: Column(
          children: [
            _ChatHeader(
              conversation: conversation,
              onBackTap: widget.onBackTap ?? () => Navigator.pop(context),
              onMoreTap: widget.onMoreTap,
              onVoiceCallTap: () => _openCallPlaceholder(video: false),
              onVideoCallTap: () => _openCallPlaceholder(video: true),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFF8F5FF), Color(0xFFFFF7F2)],
                  ),
                ),
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 18),
                  itemCount: messages.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return SwipeReplyMessage(
                      isMine: message.isMine,
                      onReply: () => setState(() => _replyToText = message.text),
                      child: _MessageBubble(
                        message: message,
                        conversation: conversation,
                        onLongPress: () => _openMessageActions(message),
                        onJoinInviteTap: message.isInvite ? () => _openInvitedRoom(message) : null,
                        onAcceptLoveBondTap: message.isLoveBondRequest ? () => _acceptLoveBondRequest(message) : null,
                        onRejectLoveBondTap: message.isLoveBondRequest ? () => _rejectLoveBondRequest(message) : null,
                      ),
                    );
                  },
                ),
              ),
            ),
            if (_replyToText != null)
              _ReplyPreview(text: _replyToText!, onClose: () => setState(() => _replyToText = null)),
            _ChatInputBar(
              readOnly: _readOnly,
              controller: _textController,
              onAttachTap: _openAttachmentSheet,
              onEmojiTap: _openEmojiPack,
              onVoiceTap: () => widget.controller.addMockAttachment(conversationId: conversation.id, type: InboxMessageType.voice),
              onSendTap: _sendText,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.conversation, required this.onBackTap, required this.onMoreTap, required this.onVoiceCallTap, required this.onVideoCallTap});

  final InboxConversation conversation;
  final VoidCallback onBackTap;
  final VoidCallback onMoreTap;
  final VoidCallback onVoiceCallTap;
  final VoidCallback onVideoCallTap;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = conversation.avatarUrl?.trim();
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 8, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF12091F),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Row(
        children: [
          IconButton(onPressed: onBackTap, icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
          Container(
            width: 42,
            height: 42,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: conversation.colors)),
            child: ClipOval(
              child: avatarUrl == null || avatarUrl.isEmpty
                  ? _HeaderAvatarText(conversation: conversation)
                  : Image.network(avatarUrl, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => _HeaderAvatarText(conversation: conversation)),
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
                        style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w900),
                      ),
                    ),
                    if (conversation.isOfficial)
                      const Icon(Icons.verified_rounded, color: Color(0xFF2DD4BF), size: 15),
                  ],
                ),
                Text(
                  conversation.safePresenceText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFFCDBCE7), fontSize: 11.2, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          IconButton(onPressed: onVoiceCallTap, icon: const Icon(Icons.call_rounded, color: Colors.white, size: 20)),
          IconButton(onPressed: onVideoCallTap, icon: const Icon(Icons.videocam_rounded, color: Colors.white, size: 21)),
          IconButton(onPressed: onMoreTap, icon: const Icon(Icons.more_vert_rounded, color: Colors.white)),
        ],
      ),
    );
  }
}

class _HeaderAvatarText extends StatelessWidget {
  const _HeaderAvatarText({required this.conversation});
  final InboxConversation conversation;
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(gradient: LinearGradient(colors: conversation.colors)),
        child: Center(child: Text(conversation.avatarText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
      );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.conversation, required this.onLongPress, required this.onJoinInviteTap, required this.onAcceptLoveBondTap, required this.onRejectLoveBondTap});

  final InboxMessage message;
  final InboxConversation conversation;
  final VoidCallback onLongPress;
  final VoidCallback? onJoinInviteTap;
  final VoidCallback? onAcceptLoveBondTap;
  final VoidCallback? onRejectLoveBondTap;

  bool get _hasMediaContent => message.type == InboxMessageType.image || message.type == InboxMessageType.document || message.type == InboxMessageType.voice;

  @override
  Widget build(BuildContext context) {
    final mine = message.isMine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        onDoubleTap: onLongPress,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 304),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                gradient: mine ? const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFFF4F9A)]) : null,
                color: mine ? null : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(mine ? 20 : 6),
                  bottomRight: Radius.circular(mine ? 6 : 20),
                ),
                border: mine ? null : Border.all(color: const Color(0xFFE9DDF5)),
                boxShadow: [BoxShadow(color: const Color(0xFF1E1230).withValues(alpha: 0.07), blurRadius: 14, offset: const Offset(0, 8))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.isForwarded) _BubbleMeta(label: 'Forwarded', mine: mine, icon: Icons.shortcut_rounded),
                  if (message.replyToText != null) _ReplySnippet(text: message.replyToText!, mine: mine),
                  if (message.isLoveBondRequest)
                    _LoveBondRequestCard(message: message, onAccept: onAcceptLoveBondTap, onReject: onRejectLoveBondTap)
                  else if (message.isInvite)
                    _InviteCard(message: message, onTap: onJoinInviteTap)
                  else if (message.isSystem)
                    _SystemMessageCard(text: message.text)
                  else if (_hasMediaContent)
                    InboxMessageMediaContent(message: message, mine: mine)
                  else
                    Text(
                      message.text,
                      style: TextStyle(color: mine ? Colors.white : const Color(0xFF251538), fontSize: 13.2, height: 1.32, fontWeight: FontWeight.w700),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.isStarred) ...[
                        Icon(Icons.star_rounded, color: mine ? Colors.white70 : const Color(0xFFC99A3B), size: 12),
                        const SizedBox(width: 4),
                      ],
                      Text(message.time, style: TextStyle(color: mine ? Colors.white70 : const Color(0xFF9B8CA5), fontSize: 10.3, fontWeight: FontWeight.w800)),
                      if (mine) ...[const SizedBox(width: 5), _ReadReceipt(status: message.status)],
                    ],
                  ),
                ],
              ),
            ),
            if (message.reaction != null)
              Positioned(
                right: mine ? 8 : null,
                left: mine ? null : 8,
                bottom: -14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFFE9DDF5))),
                  child: Text(message.reaction!, style: const TextStyle(fontSize: 13)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BubbleMeta extends StatelessWidget {
  const _BubbleMeta({required this.label, required this.mine, required this.icon});
  final String label;
  final bool mine;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: mine ? Colors.white70 : const Color(0xFF7B6A86), size: 12), const SizedBox(width: 4), Text(label, style: TextStyle(color: mine ? Colors.white70 : const Color(0xFF7B6A86), fontSize: 10.5, fontWeight: FontWeight.w800))]),
      );
}

class _ReplySnippet extends StatelessWidget {
  const _ReplySnippet({required this.text, required this.mine});
  final String text;
  final bool mine;
  @override
  Widget build(BuildContext context) => Container(
        width: 252,
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: mine ? Colors.white.withValues(alpha: 0.14) : const Color(0xFFF8F5FF),
          borderRadius: BorderRadius.circular(13),
          border: Border(left: BorderSide(color: mine ? const Color(0xFF2DD4BF) : const Color(0xFFFF4F9A), width: 3)),
        ),
        child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: mine ? Colors.white70 : const Color(0xFF7B6A86), fontSize: 11.2, fontWeight: FontWeight.w800)),
      );
}

class _SystemMessageCard extends StatelessWidget {
  const _SystemMessageCard({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        width: 252,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF99F6E4))),
        child: Row(children: [const Icon(Icons.verified_rounded, color: Color(0xFF0F766E), size: 18), const SizedBox(width: 8), Expanded(child: Text(text, style: const TextStyle(color: Color(0xFF134E4A), fontSize: 12, fontWeight: FontWeight.w800, height: 1.25)))]),
      );
}

class _LoveBondRequestCard extends StatelessWidget {
  const _LoveBondRequestCard({required this.message, required this.onAccept, required this.onReject});
  final InboxMessage message;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  bool get _pending => (message.loveBondStatus ?? 'pending').toLowerCase() == 'pending';
  @override
  Widget build(BuildContext context) {
    final cardName = message.loveBondCardName?.trim().isNotEmpty == true ? message.loveBondCardName!.trim() : 'Relationship';
    return Container(
      width: 252,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF5AAA), Color(0xFF6D5DF6)]), borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.favorite_rounded, color: Colors.white, size: 23),
        const SizedBox(height: 7),
        Text(cardName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(message.text, style: const TextStyle(color: Colors.white70, fontSize: 11.2, fontWeight: FontWeight.w800, height: 1.25)),
        const SizedBox(height: 10),
        if (_pending && !message.isMine)
          Row(children: [Expanded(child: _PillAction(label: 'Reject', icon: Icons.close_rounded, onTap: onReject, filled: false)), const SizedBox(width: 8), Expanded(child: _PillAction(label: 'Accept', icon: Icons.check_rounded, onTap: onAccept, filled: true))])
        else
          _StatusPill(label: (message.loveBondStatus ?? 'pending').toUpperCase()),
      ]),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.message, required this.onTap});
  final InboxMessage message;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final roomName = message.inviteRoomName ?? 'Room';
    return Container(
      width: 252,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF12C7B7), Color(0xFF6D5DF6)]), borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.meeting_room_rounded, color: Colors.white, size: 22),
        const SizedBox(height: 7),
        Text(roomName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        const Text('Room invite - access checked before entry', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800)),
        const SizedBox(height: 9),
        _PillAction(label: 'Join room', icon: Icons.login_rounded, onTap: onTap, filled: true),
      ]),
    );
  }
}

class _PillAction extends StatelessWidget {
  const _PillAction({required this.label, required this.icon, required this.onTap, required this.filled});
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: filled ? Colors.white : Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withValues(alpha: 0.38))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: filled ? const Color(0xFF251538) : Colors.white, size: 14), const SizedBox(width: 4), Text(label, style: TextStyle(color: filled ? const Color(0xFF251538) : Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900))]),
        ),
      );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.20), borderRadius: BorderRadius.circular(999)), child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900)));
}

class _ReadReceipt extends StatelessWidget {
  const _ReadReceipt({required this.status});
  final InboxMessageStatus status;
  @override
  Widget build(BuildContext context) {
    final icon = switch (status) { InboxMessageStatus.sending => Icons.schedule_rounded, InboxMessageStatus.sent => Icons.check_rounded, InboxMessageStatus.delivered => Icons.done_all_rounded, InboxMessageStatus.read => Icons.done_all_rounded, InboxMessageStatus.failed => Icons.error_outline_rounded };
    final color = status == InboxMessageStatus.read ? const Color(0xFF2DD4BF) : Colors.white70;
    return Icon(icon, color: color, size: 14);
  }
}

class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({required this.text, required this.onClose});
  final String text;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) => Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: const Color(0xFFF8F5FF), borderRadius: BorderRadius.circular(16), border: const Border(left: BorderSide(color: Color(0xFFFF4F9A), width: 4))),
          child: Row(children: [Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF251538), fontWeight: FontWeight.w800))), IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded, size: 18))]),
        ),
      );
}

class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({required this.readOnly, required this.controller, required this.onAttachTap, required this.onEmojiTap, required this.onVoiceTap, required this.onSendTap});
  final bool readOnly;
  final TextEditingController controller;
  final VoidCallback onAttachTap;
  final VoidCallback onEmojiTap;
  final VoidCallback onVoiceTap;
  final VoidCallback onSendTap;
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(10, 8, 10, 8 + MediaQuery.paddingOf(context).bottom),
        color: Colors.white,
        child: Row(children: [
          IconButton(onPressed: readOnly ? null : onEmojiTap, icon: const Icon(Icons.emoji_emotions_outlined, color: Color(0xFF7C3AED))),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 44, maxHeight: 96),
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(color: const Color(0xFFF8F5FF), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE9DDF5))),
              child: TextField(controller: controller, enabled: !readOnly, minLines: 1, maxLines: 4, decoration: InputDecoration(border: InputBorder.none, hintText: readOnly ? 'Replies disabled for this chat' : 'Message...', hintStyle: const TextStyle(color: Color(0xFF8C8198), fontWeight: FontWeight.w700))),
            ),
          ),
          IconButton(onPressed: readOnly ? null : onAttachTap, icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF7C3AED))),
          IconButton(onPressed: readOnly ? null : onVoiceTap, icon: const Icon(Icons.mic_rounded, color: Color(0xFF7C3AED))),
          InkWell(borderRadius: BorderRadius.circular(999), onTap: readOnly ? null : onSendTap, child: Container(width: 42, height: 42, decoration: BoxDecoration(gradient: readOnly ? null : const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFFF4F9A)]), color: readOnly ? const Color(0xFFB8A8BD) : null, shape: BoxShape.circle), child: const Icon(Icons.send_rounded, color: Colors.white, size: 18))),
        ]),
      );
}

class _MessageActionsSheet extends StatelessWidget {
  const _MessageActionsSheet({required this.message, required this.onReply, required this.onCopy, required this.onStar, required this.onForward, required this.onDelete, required this.onReaction});
  final InboxMessage message;
  final VoidCallback onReply;
  final VoidCallback onCopy;
  final VoidCallback onStar;
  final VoidCallback onForward;
  final VoidCallback onDelete;
  final ValueChanged<String> onReaction;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.all(14),
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.paddingOf(context).bottom),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: ['❤️', '😂', '😮', '🙏', '🔥'].map((reaction) => InkWell(borderRadius: BorderRadius.circular(999), onTap: () => onReaction(reaction), child: Padding(padding: const EdgeInsets.all(9), child: Text(reaction, style: const TextStyle(fontSize: 23))))).toList()),
          const SizedBox(height: 10),
          _ActionTile(icon: Icons.reply_rounded, title: 'Reply', onTap: onReply),
          _ActionTile(icon: Icons.copy_rounded, title: 'Copy', onTap: onCopy),
          _ActionTile(icon: message.isStarred ? Icons.star_rounded : Icons.star_border_rounded, title: message.isStarred ? 'Unstar' : 'Star', onTap: onStar),
          _ActionTile(icon: Icons.shortcut_rounded, title: 'Forward', onTap: onForward),
          _ActionTile(icon: Icons.delete_rounded, title: 'Delete for me', onTap: onDelete, danger: true),
        ]),
      );
}

class _AttachmentSheet extends StatelessWidget {
  const _AttachmentSheet({required this.onPick});
  final ValueChanged<InboxMessageType> onPick;
  @override
  Widget build(BuildContext context) {
    final items = [_AttachmentItem(type: InboxMessageType.image, icon: Icons.image_rounded, label: 'Gallery'), _AttachmentItem(type: InboxMessageType.document, icon: Icons.description_rounded, label: 'Document'), _AttachmentItem(type: InboxMessageType.location, icon: Icons.location_on_rounded, label: 'Location')];
    return Container(
      margin: const EdgeInsets.all(14),
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
      child: GridView.count(crossAxisCount: 3, shrinkWrap: true, children: items.map((item) => InkWell(borderRadius: BorderRadius.circular(20), onTap: () => onPick(item.type), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 46, height: 46, decoration: BoxDecoration(color: const Color(0xFF7C3AED).withValues(alpha: 0.12), shape: BoxShape.circle), child: Icon(item.icon, color: const Color(0xFF7C3AED))), const SizedBox(height: 7), Text(item.label, style: const TextStyle(color: Color(0xFF251538), fontSize: 11, fontWeight: FontWeight.w800))]))).toList()),
    );
  }
}

class _AttachmentItem {
  _AttachmentItem({required this.type, required this.icon, required this.label});
  final InboxMessageType type;
  final IconData icon;
  final String label;
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, required this.onTap, this.danger = false});
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool danger;
  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFE84C72) : const Color(0xFF251538);
    return InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11), child: Row(children: [Icon(icon, color: color, size: 21), const SizedBox(width: 12), Text(title, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900))])));
  }
}

class _CallFoundationSheet extends StatelessWidget {
  const _CallFoundationSheet({required this.conversation, required this.isVideo});
  final InboxConversation conversation;
  final bool isVideo;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.all(14),
        padding: EdgeInsets.fromLTRB(18, 18, 18, 18 + MediaQuery.paddingOf(context).bottom),
        decoration: BoxDecoration(color: const Color(0xFF12091F), borderRadius: BorderRadius.circular(30)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 74, height: 74, decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: conversation.colors)), child: Center(child: Text(conversation.avatarText, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)))),
          const SizedBox(height: 12),
          Text(isVideo ? 'Video call foundation' : 'Audio call foundation', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('Incoming screen, active call screen, summary screen and notification contracts are prepared as shared models. Native call overlay will be wired later.', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFCDBCE7), fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.3)),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _CallButton(icon: Icons.call_end_rounded, color: const Color(0xFFE84C72), onTap: () => Navigator.pop(context)),
            const SizedBox(width: 18),
            _CallButton(icon: isVideo ? Icons.videocam_rounded : Icons.call_rounded, color: const Color(0xFF18D17B), onTap: () => Navigator.pop(context)),
          ]),
        ]),
      );
}

class _CallButton extends StatelessWidget {
  const _CallButton({required this.icon, required this.color, required this.onTap});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(999), child: Container(width: 54, height: 54, decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: Icon(icon, color: Colors.white)));
}
