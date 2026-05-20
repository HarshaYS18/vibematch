import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/app_routes.dart';
import '../../../media/data/media_upload_api_service.dart';
import '../../data/inbox_api_service.dart';
import '../../data/inbox_voice_recorder_service.dart';
import '../../controllers/inbox_controller.dart';
import '../../models/inbox_models.dart';
import '../widgets/inbox_message_media_content.dart';
import '../widgets/inbox_message_action_sheet_v2.dart';
import '../widgets/inbox_call_action_sheet.dart';
import '../widgets/inbox_call_realtime_presenter.dart';
import '../widgets/inbox_chat_theme_picker_sheet.dart';
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
  final ImagePicker _imagePicker = ImagePicker();
  final MediaUploadApiService _mediaUploadApi = const MediaUploadApiService();
  final InboxApiService _inboxApi = InboxApiService();
  final InboxVoiceRecorderService _voiceRecorder = InboxVoiceRecorderService();
  String? _replyToText;
  bool _sendingImage = false;
  bool _sendingDocument = false;
  bool _sendingVoice = false;
  bool _recordingVoice = false;
  bool _showMessageTimes = false;
  double _timeRevealDrag = 0;
  String? _lastSentActivity;

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
    _textController.addListener(_handleTextInputChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.controller.openConversationFromBackend(widget.conversation.id));
    });
  }

  @override
  void dispose() {
    unawaited(widget.controller.closeSecretDriftSession(conversation: _conversation));
    widget.controller.clearActiveConversation(widget.conversation.id);
    widget.controller.removeListener(_handleChanged);
    _textController.removeListener(_handleTextInputChanged);
    _textController.dispose();
    _scrollController.dispose();
    unawaited(_voiceRecorder.dispose());
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

  void _handleTimeRevealPointerMove(PointerMoveEvent event) {
    if (event.delta.dx <= 0 || event.delta.dx.abs() < event.delta.dy.abs()) return;
    _timeRevealDrag += event.delta.dx;
    if (_timeRevealDrag > 18 && !_showMessageTimes && mounted) {
      setState(() => _showMessageTimes = true);
    }
  }

  void _clearTimeReveal() {
    _timeRevealDrag = 0;
    if (_showMessageTimes && mounted) {
      setState(() => _showMessageTimes = false);
    }
  }

  void _sendActivity(String activity) {
    if (_lastSentActivity == activity) return;
    _lastSentActivity = activity;
    widget.controller.sendChatActivity(
      conversationId: _conversation.id,
      activity: activity,
    );
  }

  void _sendIdleActivity() {
    if (_lastSentActivity == 'idle') return;
    _lastSentActivity = 'idle';
    widget.controller.sendChatActivity(
      conversationId: _conversation.id,
      activity: 'idle',
    );
  }

  void _handleTextInputChanged() {
    if (!mounted) return;
    if (_textController.text.trim().isNotEmpty) {
      _sendActivity('typing');
    } else {
      _sendIdleActivity();
    }
    setState(() {});
  }

  void _sendText() {
    if (_readOnly) return;
    widget.controller.sendTextMessage(
      conversationId: _conversation.id,
      text: _textController.text,
      replyToText: _replyToText,
    );
    _textController.clear();
    _sendIdleActivity();
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
    if (_readOnly || _sendingDocument) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'csv', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'zip'],
        withData: true,
        withReadStream: false,
      );
      final file = result?.files.single;
      if (file == null) return;

      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        _showToast('Could not read selected document.');
        return;
      }
      if (bytes.length > 20 * 1024 * 1024) {
        _showToast('Inbox document must be 20 MB or smaller.');
        return;
      }

      setState(() => _sendingDocument = true);
      _showToast('Uploading document...');

      final uploaded = await _mediaUploadApi.uploadChatDocumentBytes(
        bytes: bytes,
        filename: file.name,
      );
      if (uploaded.url.trim().isEmpty) {
        throw Exception('Upload completed without document URL.');
      }

      final sizeLabel = _formatAttachmentBytes(bytes.length);
      await _inboxApi.sendMessage(
        conversationId: _conversation.id,
        text: '📄 ${file.name} • $sizeLabel',
        type: 'document',
        attachmentUrl: uploaded.url,
      );

      await widget.controller.loadFromBackend();
      if (mounted) _showToast('Document sent.');
    } catch (error) {
      if (mounted) _showToast(_friendlyDocumentError(error));
    } finally {
      if (mounted) setState(() => _sendingDocument = false);
    }
  }

  String _formatAttachmentBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
  }

  String _friendlyDocumentError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    if (raw.contains('413')) return 'Document is too large. Choose a file under 20 MB.';
    if (raw.contains('401') || raw.toLowerCase().contains('login')) return 'Session expired. Login again before sending document.';
    if (raw.contains('400') && raw.toLowerCase().contains('unsupported')) return 'Unsupported document type. Use PDF, TXT, CSV, Word, Excel, PowerPoint, or ZIP.';
    if (raw.toLowerCase().contains('failed to fetch') || raw.toLowerCase().contains('xmlhttprequest')) return 'Upload failed. Check FastAPI is running and try again.';
    return raw.isEmpty ? 'Document send failed. Please try again.' : raw;
  }


  Future<void> _pickAndSendImageAttachment() async {
    if (_readOnly || _sendingImage) return;
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        _showToast('Selected image is empty.');
        return;
      }
      if (bytes.length > 10 * 1024 * 1024) {
        _showToast('Inbox image must be 10 MB or smaller.');
        return;
      }

      setState(() => _sendingImage = true);
      _showToast('Uploading image...');

      final uploaded = await _mediaUploadApi.uploadChatImageXFile(picked);
      if (uploaded.url.trim().isEmpty) {
        throw Exception('Upload completed without image URL.');
      }

      await _inboxApi.sendMessage(
        conversationId: _conversation.id,
        text: '📷 Photo attached',
        type: 'image',
        attachmentUrl: uploaded.url,
      );

      await widget.controller.loadFromBackend();
      if (mounted) _showToast('Image sent.');
    } catch (error) {
      if (mounted) _showToast(_friendlyImageError(error));
    } finally {
      if (mounted) setState(() => _sendingImage = false);
    }
  }

  String _friendlyImageError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    if (raw.contains('413')) return 'Image is too large. Choose an image under 10 MB.';
    if (raw.contains('401') || raw.toLowerCase().contains('login')) return 'Session expired. Login again before sending image.';
    if (raw.contains('400') && raw.toLowerCase().contains('unsupported')) return 'Unsupported image type. Choose JPG, PNG, WEBP, or GIF.';
    if (raw.toLowerCase().contains('failed to fetch') || raw.toLowerCase().contains('xmlhttprequest')) return 'Upload failed. Check FastAPI is running and try again.';
    return raw.isEmpty ? 'Image send failed. Please try again.' : raw;
  }

  void _showHoldToRecordHint() {
    if (_readOnly) return;
    _showToast('Hold the mic to record. Release to send.');
  }

  Future<void> _startVoiceRecording() async {
    if (_readOnly || _sendingVoice || _recordingVoice) return;
    try {
      final started = await _voiceRecorder.start();
      if (!started) {
        _showToast('Microphone permission is needed to record voice.');
        return;
      }
      if (mounted) {
        setState(() => _recordingVoice = true);
        _showToast('Recording... release to send.');
      }
    } catch (error) {
      if (mounted) _showToast(_friendlyVoiceError(error));
    }
  }

  Future<void> _stopAndSendVoiceRecording() async {
    if (!_recordingVoice) return;
    setState(() {
      _recordingVoice = false;
      _sendingVoice = true;
    });

    try {
      final recorded = await _voiceRecorder.stop();
      if (recorded == null || recorded.bytes.isEmpty) {
        _showToast('No voice recording found.');
        return;
      }
      if (recorded.isTooShort) {
        _showToast('Voice message is too short.');
        return;
      }
      if (recorded.isTooLarge) {
        _showToast('Voice message must be 10 MB or smaller.');
        return;
      }

      _showToast('Sending voice message...');

      final uploaded = await _mediaUploadApi.uploadChatVoiceBytes(
        bytes: recorded.bytes,
        filename: recorded.filename,
      );
      if (uploaded.url.trim().isEmpty) {
        throw Exception('Upload completed without voice URL.');
      }

      final durationLabel = _formatVoiceDuration(recorded.duration);
      await _inboxApi.sendMessage(
        conversationId: _conversation.id,
        text: '🎙 Voice message • $durationLabel',
        type: 'voice',
        attachmentUrl: uploaded.url,
      );

      await widget.controller.loadFromBackend();
      if (mounted) _showToast('Voice message sent.');
    } catch (error) {
      if (mounted) _showToast(_friendlyVoiceError(error));
    } finally {
      if (mounted) setState(() => _sendingVoice = false);
    }
  }

  Future<void> _cancelVoiceRecording() async {
    if (!_recordingVoice) return;
    await _voiceRecorder.cancel();
    if (mounted) {
      setState(() => _recordingVoice = false);
      _showToast('Voice recording cancelled.');
    }
  }

  String _formatVoiceDuration(Duration duration) {
    final totalSeconds = duration.inSeconds.clamp(0, 599);
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes <= 0) return '0:${seconds.toString().padLeft(2, '0')}';
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _friendlyVoiceError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    if (raw.contains('413')) return 'Voice file is too large. Keep it under 10 MB.';
    if (raw.contains('401') || raw.toLowerCase().contains('login')) return 'Session expired. Login again before sending voice.';
    if (raw.toLowerCase().contains('permission')) return 'Microphone permission is needed to record voice.';
    if (raw.toLowerCase().contains('failed to fetch') || raw.toLowerCase().contains('xmlhttprequest')) return 'Upload failed. Check FastAPI is running and try again.';
    return raw.isEmpty ? 'Voice send failed. Please try again.' : raw;
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
          if (type == InboxMessageType.image) {
            await _pickAndSendImageAttachment();
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

  Future<void> _openMessageActions(InboxMessage message) async {
    final result = await showInboxMessageActionSheetV2(
      context: context,
      message: message,
    );
    if (!mounted || result == null) return;

    switch (result.action) {
      case InboxMessageAction.reply:
        setState(() => _replyToText = message.text);
        break;
      case InboxMessageAction.copy:
        await Clipboard.setData(ClipboardData(text: message.text));
        if (mounted) _showToast('Message copied.');
        break;
      case InboxMessageAction.star:
        await widget.controller.toggleStarMessage(
          conversationId: _conversation.id,
          message: message,
        );
        break;
      case InboxMessageAction.forward:
        widget.controller.forwardMessage(
          fromConversationId: _conversation.id,
          message: message,
        );
        if (mounted) _showToast('Forward mapped locally.');
        break;
      case InboxMessageAction.edit:
        final editedText = result.editedText?.trim();
        if (editedText == null || editedText.isEmpty) return;
        await widget.controller.editTextMessage(
          conversationId: _conversation.id,
          message: message,
          text: editedText,
        );
        if (mounted) _showToast('Message updated.');
        break;
      case InboxMessageAction.removeForMe:
        await widget.controller.deleteMessageForMe(
          conversationId: _conversation.id,
          message: message,
        );
        if (mounted) _showToast('Removed for you.');
        break;
      case InboxMessageAction.unsend:
        await widget.controller.deleteMessage(
          conversationId: _conversation.id,
          message: message,
        );
        if (mounted) _showToast('Message unsent.');
        break;
      case InboxMessageAction.react:
        final reaction = result.reaction;
        if (reaction == null) return;
        await widget.controller.setReaction(
          conversationId: _conversation.id,
          message: message,
          reaction: reaction,
        );
        break;
      case InboxMessageAction.cancel:
        break;
    }
  }


  void _openChatMoreSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChatMoreSheet(
        conversation: _conversation,
        onDisappearingTap: () {
          Navigator.pop(context);
          unawaited(_toggleSecretDrift());
        },
        onOriginalMoreTap: widget.onMoreTap,
      ),
    );
  }

  Future<void> _handleBackFromChat() async {
    final conversation = _conversation;
    if (conversation.secretDriftEnabled) {
      await widget.controller.closeSecretDriftSession(conversation: conversation);
    }
    if (!mounted) return;
    final customBack = widget.onBackTap;
    if (customBack != null) {
      customBack();
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _toggleSecretDrift() async {
    await widget.controller.toggleSecretDrift(conversation: _conversation);
    if (!mounted) return;
    final enabled = !_conversation.secretDriftEnabled;
    _showToast(enabled ? 'Secret Drift enabled.' : 'Secret Drift disabled.');
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

  String _chatStatusText(InboxConversation conversation) {
    final remoteActivity = widget.controller.remoteActivityForConversation(conversation.id);
    if (remoteActivity != null) return _activityLabel(remoteActivity);

    if (conversation.isOnline) return 'online';
    return conversation.safePresenceText;
  }

  String _activityLabel(String activity) {
    return switch (activity) {
      'typing' => 'typing...',
      'recording_voice' => 'recording voice...',
      'sending_audio' => 'sending audio...',
      'sending_photo' => 'sending photo...',
      'sending_video' => 'sending video...',
      'sending_document' => 'sending document...',
      'listening_audio' => 'listening to audio...',
      _ => activity.replaceAll('_', ' '),
    };
  }

  InboxChatThemeChoice _resolvedChatTheme(InboxConversation conversation) {
    final key = conversation.chatTheme ?? widget.controller.defaultChatTheme;
    final wallpaperKey = conversation.wallpaperKey ?? widget.controller.defaultWallpaperKey;
    return inboxChatThemeChoices.firstWhere(
      (choice) => choice.key == key || choice.wallpaperKey == wallpaperKey,
      orElse: () => inboxChatThemeChoices.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final conversation = _conversation;
    final messages = conversation.messages;
    final chatTheme = _resolvedChatTheme(conversation);
    return InboxCallRealtimePresenter(
      callController: widget.controller.callController,
      child: Scaffold(
        backgroundColor: const Color(0xFF12091F),
      body: SafeArea(
        child: Column(
          children: [
            _ChatHeader(
              conversation: conversation,
              statusText: _chatStatusText(conversation),
              onBackTap: () => unawaited(_handleBackFromChat()),
              onMoreTap: _openChatMoreSheet,
              onVoiceCallTap: _openCallSheet,
              onVideoCallTap: _openCallSheet,
            ),
            if (conversation.secretDriftEnabled)
              _SecretDriftBanner(label: conversation.secretDriftLabel),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: chatTheme.colors,
                  ),
                ),
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 18),
                  itemCount: messages.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return Listener(
                      onPointerMove: _handleTimeRevealPointerMove,
                      onPointerUp: (_) => _clearTimeReveal(),
                      onPointerCancel: (_) => _clearTimeReveal(),
                      child: SwipeReplyMessage(
                        isMine: message.isMine,
                      onReply: () => setState(() => _replyToText = message.text),
                        child: _MessageBubble(
                          showTime: _showMessageTimes,
                          message: message,
                        conversation: conversation,
                        onLongPress: () => _openMessageActions(message),
                        onJoinInviteTap: message.isInvite ? () => _openInvitedRoom(message) : null,
                        onAcceptLoveBondTap: message.isLoveBondRequest ? () => _acceptLoveBondRequest(message) : null,
                          onRejectLoveBondTap: message.isLoveBondRequest ? () => _rejectLoveBondRequest(message) : null,
                          onRetryFailedTap: message.isMine && message.status == InboxMessageStatus.failed
                              ? () => widget.controller.retryFailedMessage(conversationId: _conversation.id, message: message)
                              : null,
                        ),
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
              recordingVoice: _recordingVoice,
              sendingVoice: _sendingVoice,
              onVoiceTap: _showHoldToRecordHint,
              onVoiceLongPressStart: _startVoiceRecording,
              onVoiceLongPressEnd: _stopAndSendVoiceRecording,
              onVoiceLongPressCancel: _cancelVoiceRecording,
              onSendTap: _sendText,
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.conversation, required this.statusText, required this.onBackTap, required this.onMoreTap, required this.onVoiceCallTap, required this.onVideoCallTap});

  final InboxConversation conversation;
  final String statusText;
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
                  statusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFFCDBCE7), fontSize: 11.2, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          if (conversation.hasChatStreak) ...[
            _HeaderChatStreakPill(conversation: conversation),
            const SizedBox(width: 4),
          ],
          IconButton(onPressed: onVoiceCallTap, icon: const Icon(Icons.call_rounded, color: Colors.white, size: 20)),
          IconButton(onPressed: onVideoCallTap, icon: const Icon(Icons.videocam_rounded, color: Colors.white, size: 21)),
          IconButton(onPressed: onMoreTap, icon: const Icon(Icons.more_vert_rounded, color: Colors.white)),
        ],
      ),
    );
  }
}


class _HeaderChatStreakPill extends StatelessWidget {
  const _HeaderChatStreakPill({required this.conversation});

  final InboxConversation conversation;

  @override
  Widget build(BuildContext context) {
    final color = conversation.chatStreakActiveToday
        ? const Color(0xFFFFA000)
        : const Color(0xFFCDBCE7);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_rounded, color: color, size: 12),
          const SizedBox(width: 3),
          Text(
            '${conversation.chatStreakCount}',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
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
  const _MessageBubble({
    required this.showTime,
    required this.message,
    required this.conversation,
    required this.onLongPress,
    required this.onJoinInviteTap,
    required this.onAcceptLoveBondTap,
    required this.onRejectLoveBondTap,
    required this.onRetryFailedTap,
  });

  final bool showTime;
  final InboxMessage message;
  final InboxConversation conversation;
  final VoidCallback onLongPress;
  final VoidCallback? onJoinInviteTap;
  final VoidCallback? onAcceptLoveBondTap;
  final VoidCallback? onRejectLoveBondTap;
  final VoidCallback? onRetryFailedTap;

  bool get _hasMediaContent => message.type == InboxMessageType.image || message.type == InboxMessageType.document || message.type == InboxMessageType.voice;

  @override
  Widget build(BuildContext context) {
    final mine = message.isMine;
    final showInlineReceipt = mine &&
        !_hasMediaContent &&
        !message.isLoveBondRequest &&
        !message.isInvite &&
        !message.isSystem;
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            message.text,
                            style: TextStyle(
                              color: mine ? Colors.white : const Color(0xFF251538),
                              fontSize: 13.2,
                              height: 1.32,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (showInlineReceipt) ...[
                          const SizedBox(width: 5),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 1),
                            child: _ReadReceipt(status: message.status, mine: mine),
                          ),
                        ],
                      ],
                    ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.isStarred) ...[
                        Icon(Icons.star_rounded, color: mine ? Colors.white70 : const Color(0xFFC99A3B), size: 12),
                        const SizedBox(width: 4),
                      ],
                      if (showTime) ...[
                        Text(
                          '${mine ? 'You' : message.sender} • ${message.time}',
                          style: TextStyle(
                            color: mine ? Colors.white70 : const Color(0xFF9B8CA5),
                            fontSize: 10.3,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                      if (mine) ...[
                        if (showTime && !showInlineReceipt) const SizedBox(width: 5),
                        if (!showInlineReceipt) _ReadReceipt(status: message.status, mine: mine),
                        if (message.status == InboxMessageStatus.failed && onRetryFailedTap != null) ...[
                          const SizedBox(width: 6),
                          _RetryChip(onTap: onRetryFailedTap!),
                        ],
                      ],
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
  const _ReadReceipt({required this.status, required this.mine});

  final InboxMessageStatus status;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final icon = switch (status) {
      InboxMessageStatus.sending => Icons.schedule_rounded,
      InboxMessageStatus.sent => Icons.check_rounded,
      InboxMessageStatus.delivered => Icons.done_all_rounded,
      InboxMessageStatus.read => Icons.done_all_rounded,
      InboxMessageStatus.failed => Icons.error_outline_rounded,
    };

    final label = switch (status) {
      InboxMessageStatus.sending => 'Sending',
      InboxMessageStatus.sent => 'Sent',
      InboxMessageStatus.delivered => 'Delivered',
      InboxMessageStatus.read => 'Read',
      InboxMessageStatus.failed => 'Failed',
    };

    final color = switch (status) {
      InboxMessageStatus.read => const Color(0xFF34D5FF),
      InboxMessageStatus.failed => const Color(0xFFFFD1DC),
      _ => mine ? Colors.white70 : const Color(0xFF9B8CA5),
    };

    return Tooltip(
      message: label,
      child: Icon(icon, color: color, size: 13.5),
    );
  }
}


class _RetryChip extends StatelessWidget {
  const _RetryChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.refresh_rounded, color: Colors.white, size: 11),
            SizedBox(width: 3),
            Text(
              'Retry',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9.8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
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

class _SecretDriftBanner extends StatelessWidget {
  const _SecretDriftBanner({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_rounded, color: Color(0xFFEA580C), size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF7C2D12),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMoreSheet extends StatelessWidget {
  const _ChatMoreSheet({
    required this.conversation,
    required this.onDisappearingTap,
    required this.onOriginalMoreTap,
  });

  final InboxConversation conversation;
  final VoidCallback onDisappearingTap;
  final VoidCallback onOriginalMoreTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(14),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionTile(
            icon: conversation.secretDriftEnabled ? Icons.timer_off_rounded : Icons.timer_rounded,
            title: conversation.secretDriftEnabled ? 'Turn off Secret Drift' : 'Turn on Secret Drift',
            onTap: onDisappearingTap,
          ),
          _ActionTile(
            icon: Icons.more_horiz_rounded,
            title: 'More chat options',
            onTap: onOriginalMoreTap,
          ),
        ],
      ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({
    required this.readOnly,
    required this.controller,
    required this.recordingVoice,
    required this.sendingVoice,
    required this.onAttachTap,
    required this.onEmojiTap,
    required this.onVoiceTap,
    required this.onVoiceLongPressStart,
    required this.onVoiceLongPressEnd,
    required this.onVoiceLongPressCancel,
    required this.onSendTap,
  });
  final bool readOnly;
  final TextEditingController controller;
  final bool recordingVoice;
  final bool sendingVoice;
  final VoidCallback onAttachTap;
  final VoidCallback onEmojiTap;
  final VoidCallback onVoiceTap;
  final VoidCallback onVoiceLongPressStart;
  final VoidCallback onVoiceLongPressEnd;
  final VoidCallback onVoiceLongPressCancel;
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
          GestureDetector(
            onTap: readOnly ? null : onVoiceTap,
            onLongPressStart: readOnly || sendingVoice ? null : (_) => onVoiceLongPressStart(),
            onLongPressEnd: readOnly || sendingVoice ? null : (_) => onVoiceLongPressEnd(),
            onLongPressCancel: readOnly || sendingVoice ? null : onVoiceLongPressCancel,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 42,
              height: 42,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: recordingVoice ? const Color(0xFFE84C72) : const Color(0xFF7C3AED).withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                sendingVoice
                    ? Icons.hourglass_top_rounded
                    : recordingVoice
                        ? Icons.stop_rounded
                        : Icons.mic_rounded,
                color: recordingVoice ? Colors.white : const Color(0xFF7C3AED),
                size: 21,
              ),
            ),
          ),
          InkWell(borderRadius: BorderRadius.circular(999), onTap: readOnly ? null : onSendTap, child: Container(width: 42, height: 42, decoration: BoxDecoration(gradient: readOnly ? null : const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFFF4F9A)]), color: readOnly ? const Color(0xFFB8A8BD) : null, shape: BoxShape.circle), child: const Icon(Icons.send_rounded, color: Colors.white, size: 18))),
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

