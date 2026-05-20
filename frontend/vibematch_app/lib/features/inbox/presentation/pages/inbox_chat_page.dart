import 'dart:async';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/app_routes.dart';
import '../../../media/data/media_upload_api_service.dart';
import '../../data/inbox_api_service.dart';
import '../../data/inbox_voice_recorder_service.dart';
import '../../controllers/inbox_controller.dart';
import '../../models/inbox_call_models.dart';
import '../../models/inbox_models.dart';
import 'inbox_active_call_page.dart';
import '../widgets/inbox_message_media_content.dart';
import '../widgets/inbox_message_action_sheet_v2.dart';
import '../widgets/inbox_call_realtime_presenter.dart';
import '../widgets/inbox_chat_theme_picker_sheet.dart';
import '../widgets/social_emoji_pack_sheet.dart';
import '../widgets/swipe_reply_message.dart';
import '../widgets/inbox_light_premium_tokens.dart';
import '../widgets/inbox_time_formatters.dart';

const String _driftCoachSeenKey = 'funkey_inbox_drift_coach_seen_v1';

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
  bool _showDriftCoach = false;
  double _timeRevealDrag = 0;
  String? _lastSentActivity;
  InboxCallType? _startingCallType;

  InboxConversation get _conversation =>
      widget.controller.conversationById(widget.conversation.id) ??
      widget.conversation;

  bool get _readOnly {
    final conversation = _conversation;
    return conversation.isOfficial ||
        conversation.isStranger ||
        conversation.isBlocked;
  }

  @override
  void initState() {
    super.initState();
    widget.controller.markConversationRead(widget.conversation.id);
    widget.controller.addListener(_handleChanged);
    _textController.addListener(_handleTextInputChanged);
    unawaited(_loadDriftCoachState());
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
    if (event.delta.dx <= 0 || event.delta.dx.abs() < event.delta.dy.abs())
      return;
    _timeRevealDrag += event.delta.dx;
    if (_timeRevealDrag > 18 && !_showMessageTimes && mounted) {
      setState(() => _showMessageTimes = true);
    }
  }

  Future<void> _loadDriftCoachState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _showDriftCoach = !(prefs.getBool(_driftCoachSeenKey) ?? false);
    });
  }

  Future<void> _markDriftCoachSeen() async {
    if (_showDriftCoach && mounted) {
      setState(() => _showDriftCoach = false);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_driftCoachSeenKey, true);
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
          backgroundColor: InboxLightPremiumTokens.ink,
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
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

  void _insertEmoji(String emoji) {
    final selection = _textController.selection;
    final oldText = _textController.text;
    final start = selection.start >= 0 ? selection.start : oldText.length;
    final end = selection.end >= 0 ? selection.end : oldText.length;
    final newText = oldText.replaceRange(start, end, emoji);
    final newOffset = start + emoji.length;
    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
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
        allowedExtensions: [
          'pdf',
          'txt',
          'csv',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'ppt',
          'pptx',
          'zip',
        ],
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
        text: 'Document: ${file.name} - $sizeLabel',
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
    if (raw.contains('413'))
      return 'Document is too large. Choose a file under 20 MB.';
    if (raw.contains('401') || raw.toLowerCase().contains('login'))
      return 'Session expired. Login again before sending document.';
    if (raw.contains('400') && raw.toLowerCase().contains('unsupported'))
      return 'Unsupported document type. Use PDF, TXT, CSV, Word, Excel, PowerPoint, or ZIP.';
    if (raw.toLowerCase().contains('failed to fetch') ||
        raw.toLowerCase().contains('xmlhttprequest'))
      return 'Upload failed. Check FastAPI is running and try again.';
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
        text: 'Photo attached',
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
    if (raw.contains('413'))
      return 'Image is too large. Choose an image under 10 MB.';
    if (raw.contains('401') || raw.toLowerCase().contains('login'))
      return 'Session expired. Login again before sending image.';
    if (raw.contains('400') && raw.toLowerCase().contains('unsupported'))
      return 'Unsupported image type. Choose JPG, PNG, WEBP, or GIF.';
    if (raw.toLowerCase().contains('failed to fetch') ||
        raw.toLowerCase().contains('xmlhttprequest'))
      return 'Upload failed. Check FastAPI is running and try again.';
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
        text: 'Voice message - $durationLabel',
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
    if (raw.contains('413'))
      return 'Voice file is too large. Keep it under 10 MB.';
    if (raw.contains('401') || raw.toLowerCase().contains('login'))
      return 'Session expired. Login again before sending voice.';
    if (raw.toLowerCase().contains('permission'))
      return 'Microphone permission is needed to record voice.';
    if (raw.toLowerCase().contains('failed to fetch') ||
        raw.toLowerCase().contains('xmlhttprequest'))
      return 'Upload failed. Check FastAPI is running and try again.';
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
          }
        },
      ),
    );
  }

  Future<void> _acceptLoveBondRequest(InboxMessage message) async {
    await widget.controller.acceptLoveBondRequest(
      conversationId: _conversation.id,
      message: message,
    );
    if (mounted) _showToast('Relationship request accepted.');
  }

  Future<void> _rejectLoveBondRequest(InboxMessage message) async {
    await widget.controller.rejectLoveBondRequest(
      conversationId: _conversation.id,
      message: message,
    );
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
        if (mounted) _showToast('Message forwarded.');
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
      await widget.controller.closeSecretDriftSession(
        conversation: conversation,
      );
    }
    if (!mounted) return;
    final customBack = widget.onBackTap;
    if (customBack != null) {
      customBack();
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _toggleSecretDrift({bool fromCoach = false}) async {
    if (fromCoach || _showDriftCoach) {
      unawaited(_markDriftCoachSeen());
    }
    await widget.controller.toggleSecretDrift(conversation: _conversation);
    if (!mounted) return;
    final latest = _conversation;
    final enabled = latest.secretDriftEnabled;
    _showToast(enabled ? 'Secret Drift enabled.' : 'Secret Drift disabled.');
  }

  Future<void> _startDirectCall(InboxCallType type) async {
    if (_readOnly || _startingCallType != null) return;
    final conversation = _conversation;
    final existingCall = widget.controller.callController.activeCall;
    if (existingCall != null && !existingCall.isTerminal) {
      _showToast(
        'You already have an active call. End it before starting another one.',
      );
      return;
    }

    setState(() => _startingCallType = type);
    final session = await widget.controller.callController.startCall(
      conversation: conversation,
      callType: type,
    );
    if (!mounted) return;
    setState(() => _startingCallType = null);

    if (session == null) {
      _showToast(
        widget.controller.callController.errorMessage ??
            'Could not start call.',
      );
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => InboxActiveCallPage(
          callController: widget.controller.callController,
          initialSession: session,
        ),
      ),
    );
  }

  String _chatStatusText(InboxConversation conversation) {
    final remoteActivity = widget.controller.remoteActivityForConversation(
      conversation.id,
    );
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
    final wallpaperKey =
        conversation.wallpaperKey ?? widget.controller.defaultWallpaperKey;
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
        backgroundColor: InboxLightPremiumTokens.ink,
        body: SafeArea(
          child: Column(
            children: [
              _ChatHeader(
                conversation: conversation,
                statusText: _chatStatusText(conversation),
                onBackTap: () => unawaited(_handleBackFromChat()),
                onMoreTap: _openChatMoreSheet,
                callsEnabled: !_readOnly,
                startingCallType: _startingCallType,
                onVoiceCallTap: () =>
                    unawaited(_startDirectCall(InboxCallType.audio)),
                onVideoCallTap: () =>
                    unawaited(_startDirectCall(InboxCallType.video)),
              ),
              Expanded(
                child: Listener(
                  onPointerMove: _handleTimeRevealPointerMove,
                  onPointerUp: (_) => _clearTimeReveal(),
                  onPointerCancel: (_) => _clearTimeReveal(),
                  child: _ChatWallpaperCanvas(
                    conversation: conversation,
                    chatTheme: chatTheme,
                    defaultWallpaperUrl: widget.controller.defaultWallpaperUrl,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: messages.isEmpty
                              ? _EmptyChatState(
                                  conversation: conversation,
                                  readOnly: _readOnly,
                                )
                              : ListView.separated(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    16,
                                    12,
                                    18,
                                  ),
                                  itemCount: messages.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final message = messages[index];
                                    return SwipeReplyMessage(
                                      isMine: message.isMine,
                                      onReply: () => setState(
                                        () => _replyToText = message.text,
                                      ),
                                      child: _MessageBubble(
                                        showTime: _showMessageTimes,
                                        message: message,
                                        conversation: conversation,
                                        onLongPress: () =>
                                            _openMessageActions(message),
                                        onJoinInviteTap: message.isInvite
                                            ? () => _openInvitedRoom(message)
                                            : null,
                                        onAcceptLoveBondTap:
                                            message.isLoveBondRequest
                                            ? () => _acceptLoveBondRequest(
                                                message,
                                              )
                                            : null,
                                        onRejectLoveBondTap:
                                            message.isLoveBondRequest
                                            ? () => _rejectLoveBondRequest(
                                                message,
                                              )
                                            : null,
                                        onRetryFailedTap:
                                            message.isMine &&
                                                message.status ==
                                                    InboxMessageStatus.failed
                                            ? () => widget.controller
                                                  .retryFailedMessage(
                                                    conversationId:
                                                        _conversation.id,
                                                    message: message,
                                                  )
                                            : null,
                                      ),
                                    );
                                  },
                                ),
                        ),
                        if (_showMessageTimes)
                          const Positioned(
                            top: 12,
                            right: 12,
                            child: _TimeRevealPill(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!_readOnly)
                _SecretDriftSwipeActivator(
                  active: conversation.secretDriftEnabled,
                  onActivated: () => _toggleSecretDrift(
                    fromCoach:
                        !conversation.secretDriftEnabled && _showDriftCoach,
                  ),
                ),
              if (_replyToText != null)
                _ReplyPreview(
                  text: _replyToText!,
                  onClose: () => setState(() => _replyToText = null),
                ),
              _ChatInputBar(
                readOnly: _readOnly,
                driftMode: conversation.secretDriftEnabled,
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

class _ChatWallpaperCanvas extends StatelessWidget {
  const _ChatWallpaperCanvas({
    required this.conversation,
    required this.chatTheme,
    required this.child,
    this.defaultWallpaperUrl,
  });

  final InboxConversation conversation;
  final InboxChatThemeChoice chatTheme;
  final Widget child;
  final String? defaultWallpaperUrl;

  String? get _wallpaperUrl {
    final candidates = <String?>[
      conversation.wallpaperUrl,
      defaultWallpaperUrl,
      chatTheme.wallpaperUrl,
    ];
    for (final candidate in candidates) {
      final value = candidate?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = chatTheme.colors.length >= 2
        ? chatTheme.colors
        : const [InboxLightPremiumTokens.pearl, Color(0xFFFFF7F2)];
    final brightness = ThemeData.estimateBrightnessForColor(colors.first);
    final isDark = brightness == Brightness.dark;
    final wallpaperKey = conversation.wallpaperKey ?? chatTheme.wallpaperKey;
    final wallpaperUrl = _wallpaperUrl;

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: colors,
              ),
            ),
          ),
          CustomPaint(
            painter: _WallpaperTexturePainter(
              colors: colors,
              wallpaperKey: wallpaperKey,
              isDark: isDark,
            ),
          ),
          if (wallpaperUrl != null)
            _WallpaperImageLayer(url: wallpaperUrl, isDark: isDark),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  (isDark ? Colors.black : Colors.white).withValues(
                    alpha: isDark ? 0.12 : 0.34,
                  ),
                  (isDark ? Colors.black : Colors.white).withValues(
                    alpha: isDark ? 0.28 : 0.58,
                  ),
                ],
              ),
            ),
          ),
          if (conversation.secretDriftEnabled)
            const _SecretDriftCanvasOverlay(),
          child,
        ],
      ),
    );
  }
}

class _TimeRevealPill extends StatelessWidget {
  const _TimeRevealPill();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: InboxLightPremiumTokens.ink.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule_rounded, color: Colors.white, size: 14),
              SizedBox(width: 6),
              Text(
                'Message times',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecretDriftCanvasOverlay extends StatelessWidget {
  const _SecretDriftCanvasOverlay();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF160B25).withValues(alpha: 0.36),
                const Color(0xFF080510).withValues(alpha: 0.50),
              ],
            ),
          ),
        ),
        CustomPaint(painter: _DriftModePainter()),
      ],
    );
  }
}

class _DriftModePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.055);
    for (double y = 34; y < size.height; y += 56) {
      final path = Path()..moveTo(-20, y);
      path.quadraticBezierTo(
        size.width * 0.28,
        y - 18,
        size.width * 0.58,
        y + 3,
      );
      path.quadraticBezierTo(size.width * 0.82, y + 20, size.width + 20, y - 6);
      canvas.drawPath(path, paint);
    }

    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = InboxLightPremiumTokens.pink.withValues(alpha: 0.065);
    for (double y = 24; y < size.height; y += 72) {
      for (double x = 28; x < size.width; x += 86) {
        canvas.drawCircle(Offset(x, y), 2, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DriftModePainter oldDelegate) => false;
}

class _WallpaperImageLayer extends StatelessWidget {
  const _WallpaperImageLayer({required this.url, required this.isDark});

  final String url;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final image = url.startsWith('http://') || url.startsWith('https://')
        ? Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox.shrink(),
          )
        : url.startsWith('assets/')
        ? Image.asset(
            url,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox.shrink(),
          )
        : const SizedBox.shrink();

    return Opacity(
      opacity: isDark ? 0.32 : 0.24,
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(
          (isDark ? Colors.black : Colors.white).withValues(alpha: 0.18),
          BlendMode.srcATop,
        ),
        child: image,
      ),
    );
  }
}

class _WallpaperTexturePainter extends CustomPainter {
  const _WallpaperTexturePainter({
    required this.colors,
    required this.wallpaperKey,
    required this.isDark,
  });

  final List<Color> colors;
  final String wallpaperKey;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || colors.isEmpty) return;
    final seed = wallpaperKey.hashCode.abs();
    final accent = colors.last;
    final base = isDark ? Colors.white : Colors.black;
    final shortSide = math.max(1.0, math.min(size.width, size.height));

    for (var index = 0; index < 8; index++) {
      final xSeed = ((seed >> (index % 12)) + index * 37) % 100;
      final ySeed = ((seed >> ((index + 3) % 12)) + index * 53) % 100;
      final radius = shortSide * (0.18 + (index % 3) * 0.035);
      final center = Offset(
        size.width * xSeed / 100,
        size.height * ySeed / 100,
      );
      final rect = Rect.fromCircle(center: center, radius: radius);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: isDark ? 0.16 : 0.18),
            accent.withValues(alpha: 0),
          ],
        ).createShader(rect);
      canvas.drawCircle(center, radius, paint);
    }

    final linePaint = Paint()
      ..color = base.withValues(alpha: isDark ? 0.035 : 0.028)
      ..strokeWidth = 1;
    for (double offset = -size.height; offset < size.width; offset += 32) {
      canvas.drawLine(
        Offset(offset, size.height),
        Offset(offset + size.height, 0),
        linePaint,
      );
    }

    final dotPaint = Paint()
      ..color = base.withValues(alpha: isDark ? 0.042 : 0.032);
    for (double y = 22; y < size.height; y += 38) {
      for (double x = 18; x < size.width; x += 42) {
        final drift = ((x + y + seed) % 9) - 4;
        canvas.drawCircle(Offset(x + drift, y), 1.1, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WallpaperTexturePainter oldDelegate) {
    return oldDelegate.wallpaperKey != wallpaperKey ||
        oldDelegate.isDark != isDark ||
        oldDelegate.colors != colors;
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState({required this.conversation, required this.readOnly});

  final InboxConversation conversation;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final title = readOnly ? 'Chat is quiet' : 'Start the conversation';
    final subtitle = conversation.isOfficial
        ? 'Official updates will land here.'
        : conversation.isStranger
        ? 'Accept the request before replying.'
        : conversation.isBlocked
        ? 'Unblock this profile to continue.'
        : 'Say hi or share a moment when you are ready.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
              ),
              child: const Icon(
                Icons.forum_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.74),
                fontSize: 12.4,
                height: 1.28,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.conversation,
    required this.statusText,
    required this.onBackTap,
    required this.onMoreTap,
    required this.callsEnabled,
    required this.startingCallType,
    required this.onVoiceCallTap,
    required this.onVideoCallTap,
  });

  final InboxConversation conversation;
  final String statusText;
  final VoidCallback onBackTap;
  final VoidCallback onMoreTap;
  final bool callsEnabled;
  final InboxCallType? startingCallType;
  final VoidCallback onVoiceCallTap;
  final VoidCallback onVideoCallTap;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = conversation.avatarUrl?.trim();
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 8, 8, 10),
      decoration: BoxDecoration(
        color: InboxLightPremiumTokens.ink,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBackTap,
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          Container(
            width: 42,
            height: 42,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: conversation.colors),
            ),
            child: ClipOval(
              child: avatarUrl == null || avatarUrl.isEmpty
                  ? _HeaderAvatarText(conversation: conversation)
                  : Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _HeaderAvatarText(conversation: conversation),
                    ),
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
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (conversation.isOfficial)
                      const Icon(
                        Icons.verified_rounded,
                        color: InboxLightPremiumTokens.aqua,
                        size: 15,
                      ),
                  ],
                ),
                Text(
                  statusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFCDBCE7),
                    fontSize: 11.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (conversation.hasChatStreak) ...[
            _HeaderChatStreakPill(conversation: conversation),
            const SizedBox(width: 4),
          ],
          if (callsEnabled) ...[
            _HeaderCallButton(
              icon: Icons.call_rounded,
              busy: startingCallType == InboxCallType.audio,
              onTap: onVoiceCallTap,
            ),
            _HeaderCallButton(
              icon: Icons.videocam_rounded,
              busy: startingCallType == InboxCallType.video,
              onTap: onVideoCallTap,
            ),
          ],
          IconButton(
            onPressed: onMoreTap,
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _HeaderCallButton extends StatelessWidget {
  const _HeaderCallButton({
    required this.icon,
    required this.busy,
    required this.onTap,
  });

  final IconData icon;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: busy ? null : onTap,
      icon: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(icon, color: Colors.white, size: 21),
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
        : Color(0xFFEFE7FF);

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
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: conversation.colors),
    ),
    child: Center(
      child: Text(
        conversation.avatarText,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
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

  bool get _hasMediaContent =>
      message.type == InboxMessageType.image ||
      message.type == InboxMessageType.document ||
      message.type == InboxMessageType.voice;

  @override
  Widget build(BuildContext context) {
    final mine = message.isMine;
    final localTime = inboxLocalTimeLabel(message.time);
    final showInlineReceipt =
        mine &&
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
                gradient: mine
                    ? const LinearGradient(
                        colors: [
                          InboxLightPremiumTokens.violet,
                          InboxLightPremiumTokens.pink,
                        ],
                      )
                    : null,
                color: mine ? null : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(mine ? 20 : 6),
                  bottomRight: Radius.circular(mine ? 6 : 20),
                ),
                border: mine
                    ? null
                    : Border.all(color: InboxLightPremiumTokens.border),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E1230).withValues(alpha: 0.07),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.isForwarded)
                    _BubbleMeta(
                      label: 'Forwarded',
                      mine: mine,
                      icon: Icons.shortcut_rounded,
                    ),
                  if (message.replyToText != null)
                    _ReplySnippet(text: message.replyToText!, mine: mine),
                  if (message.isLoveBondRequest)
                    _LoveBondRequestCard(
                      message: message,
                      onAccept: onAcceptLoveBondTap,
                      onReject: onRejectLoveBondTap,
                    )
                  else if (message.isInvite)
                    _InviteCard(message: message, onTap: onJoinInviteTap)
                  else if (message.isSystem)
                    _SystemMessageCard(text: message.text)
                  else if (message.type == InboxMessageType.callLog)
                    _CallLogMessageCard(message: message)
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
                              color: mine
                                  ? Colors.white
                                  : InboxLightPremiumTokens.ink,
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
                            child: _ReadReceipt(
                              status: message.status,
                              mine: mine,
                            ),
                          ),
                        ],
                      ],
                    ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.isStarred) ...[
                        Icon(
                          Icons.star_rounded,
                          color: mine
                              ? Colors.white70
                              : InboxLightPremiumTokens.gold,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                      ],
                      if (showTime) ...[
                        Text(
                          '${mine ? 'You' : message.sender} - $localTime',
                          style: TextStyle(
                            color: mine
                                ? Colors.white70
                                : InboxLightPremiumTokens.softMuted,
                            fontSize: 10.3,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                      if (mine) ...[
                        if (showTime && !showInlineReceipt)
                          const SizedBox(width: 5),
                        if (!showInlineReceipt)
                          _ReadReceipt(status: message.status, mine: mine),
                        if (message.status == InboxMessageStatus.failed &&
                            onRetryFailedTap != null) ...[
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: InboxLightPremiumTokens.border),
                  ),
                  child: Text(
                    message.reaction!,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BubbleMeta extends StatelessWidget {
  const _BubbleMeta({
    required this.label,
    required this.mine,
    required this.icon,
  });
  final String label;
  final bool mine;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: mine ? Colors.white70 : InboxLightPremiumTokens.muted,
          size: 12,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: mine ? Colors.white70 : InboxLightPremiumTokens.muted,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
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
      color: mine
          ? Colors.white.withValues(alpha: 0.14)
          : InboxLightPremiumTokens.pearl,
      borderRadius: BorderRadius.circular(13),
      border: Border(
        left: BorderSide(
          color: mine
              ? InboxLightPremiumTokens.aqua
              : InboxLightPremiumTokens.pink,
          width: 3,
        ),
      ),
    ),
    child: Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: mine ? Colors.white70 : InboxLightPremiumTokens.muted,
        fontSize: 11.2,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _SystemMessageCard extends StatelessWidget {
  const _SystemMessageCard({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    width: 252,
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: const Color(0xFFECFDF5),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF99F6E4)),
    ),
    child: Row(
      children: [
        const Icon(Icons.verified_rounded, color: Color(0xFF0F766E), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF134E4A),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
        ),
      ],
    ),
  );
}

class _CallLogMessageCard extends StatelessWidget {
  const _CallLogMessageCard({required this.message});

  final InboxMessage message;

  @override
  Widget build(BuildContext context) {
    final lower = message.text.toLowerCase();
    final missed = lower.contains('missed');
    final video = lower.contains('video');
    final incoming = lower.contains('incoming') || lower.contains('missed');
    final color = missed
        ? InboxLightPremiumTokens.danger
        : InboxLightPremiumTokens.aqua;
    final directionIcon = incoming
        ? Icons.call_received_rounded
        : Icons.call_made_rounded;

    return Container(
      width: 252,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: InboxLightPremiumTokens.pearl,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: InboxLightPremiumTokens.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              video ? Icons.videocam_rounded : Icons.call_rounded,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.text.trim().isEmpty ? 'Call' : message.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: InboxLightPremiumTokens.ink,
                    fontSize: 12.4,
                    fontWeight: FontWeight.w900,
                    height: 1.22,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      directionIcon,
                      color: InboxLightPremiumTokens.muted,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      inboxLocalTimeLabel(message.time),
                      style: const TextStyle(
                        color: InboxLightPremiumTokens.muted,
                        fontSize: 10.8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoveBondRequestCard extends StatelessWidget {
  const _LoveBondRequestCard({
    required this.message,
    required this.onAccept,
    required this.onReject,
  });
  final InboxMessage message;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  bool get _pending =>
      (message.loveBondStatus ?? 'pending').toLowerCase() == 'pending';
  @override
  Widget build(BuildContext context) {
    final cardName = message.loveBondCardName?.trim().isNotEmpty == true
        ? message.loveBondCardName!.trim()
        : 'Relationship';
    return Container(
      width: 252,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF5AAA), InboxLightPremiumTokens.violetDeep],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.favorite_rounded, color: Colors.white, size: 23),
          const SizedBox(height: 7),
          Text(
            cardName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message.text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11.2,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),
          if (_pending && !message.isMine)
            Row(
              children: [
                Expanded(
                  child: _PillAction(
                    label: 'Reject',
                    icon: Icons.close_rounded,
                    onTap: onReject,
                    filled: false,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PillAction(
                    label: 'Accept',
                    icon: Icons.check_rounded,
                    onTap: onAccept,
                    filled: true,
                  ),
                ),
              ],
            )
          else
            _StatusPill(
              label: (message.loveBondStatus ?? 'pending').toUpperCase(),
            ),
        ],
      ),
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
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            InboxLightPremiumTokens.aqua,
            InboxLightPremiumTokens.violetDeep,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.meeting_room_rounded, color: Colors.white, size: 22),
          const SizedBox(height: 7),
          Text(
            roomName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Room invite - access checked before entry',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 9),
          _PillAction(
            label: 'Join room',
            icon: Icons.login_rounded,
            onTap: onTap,
            filled: true,
          ),
        ],
      ),
    );
  }
}

class _PillAction extends StatelessWidget {
  const _PillAction({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.filled,
  });
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
      decoration: BoxDecoration(
        color: filled ? Colors.white : Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.38)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: filled ? InboxLightPremiumTokens.ink : Colors.white,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: filled ? InboxLightPremiumTokens.ink : Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.20),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10.5,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
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
      _ => mine ? Colors.white70 : InboxLightPremiumTokens.softMuted,
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
      decoration: BoxDecoration(
        color: InboxLightPremiumTokens.pearl,
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(color: InboxLightPremiumTokens.pink, width: 4),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: InboxLightPremiumTokens.ink,
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
    ),
  );
}

class _SecretDriftSwipeActivator extends StatefulWidget {
  const _SecretDriftSwipeActivator({
    required this.active,
    required this.onActivated,
  });

  final bool active;
  final Future<void> Function() onActivated;

  @override
  State<_SecretDriftSwipeActivator> createState() =>
      _SecretDriftSwipeActivatorState();
}

class _SecretDriftSwipeActivatorState
    extends State<_SecretDriftSwipeActivator> {
  double _drag = 0;
  bool _arming = false;

  static const double _threshold = 62;

  double get _progress => (_drag / _threshold).clamp(0, 1).toDouble();

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_arming) return;
    final delta = details.delta.dy;
    if (delta >= 0) {
      setState(() => _drag = (_drag - delta * 0.45).clamp(0, _threshold));
      return;
    }
    setState(() => _drag = (_drag - delta).clamp(0, _threshold));
  }

  Future<void> _handleDragEnd([DragEndDetails? _]) async {
    if (_arming) return;
    if (_progress < 1) {
      setState(() => _drag = 0);
      return;
    }
    setState(() => _arming = true);
    await HapticFeedback.lightImpact();
    try {
      await widget.onActivated();
    } finally {
      if (mounted) {
        setState(() {
          _drag = 0;
          _arming = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: _handleDragUpdate,
      onVerticalDragEnd: _handleDragEnd,
      onVerticalDragCancel: () => setState(() => _drag = 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 5, 12, 7),
        color: widget.active ? InboxLightPremiumTokens.ink : Colors.white,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.active
                  ? [
                      const Color(0xFF211133),
                      Color.lerp(
                        const Color(0xFF211133),
                        InboxLightPremiumTokens.violetDeep,
                        progress,
                      )!,
                    ]
                  : [
                      InboxLightPremiumTokens.pearl,
                      Color.lerp(
                        InboxLightPremiumTokens.pearl,
                        const Color(0xFFF1E7FF),
                        progress,
                      )!,
                    ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Color.lerp(
                InboxLightPremiumTokens.border,
                InboxLightPremiumTokens.violet,
                progress,
              )!,
            ),
            boxShadow: [
              if (progress > 0)
                BoxShadow(
                  color: const Color(
                    0xFF7C3AED,
                  ).withValues(alpha: 0.10 + (progress * 0.10)),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(
                        0xFF7C3AED,
                      ).withValues(alpha: 0.22 + (progress * 0.34)),
                      const Color(
                        0xFFFF4F9A,
                      ).withValues(alpha: 0.20 + (progress * 0.32)),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: _arming
                    ? const Padding(
                        padding: EdgeInsets.all(9),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Transform.translate(
                        offset: Offset(0, -5 * progress),
                        child: Icon(
                          Icons.keyboard_arrow_up_rounded,
                          color: widget.active
                              ? Colors.white
                              : InboxLightPremiumTokens.ink,
                          size: 24,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      progress >= 1
                          ? widget.active
                                ? 'Release to leave disappearing mode'
                                : 'Release to enter disappearing mode'
                          : widget.active
                          ? 'Swipe up to leave disappearing mode'
                          : 'Swipe up for disappearing messages',
                      style: TextStyle(
                        color: widget.active
                            ? Colors.white
                            : InboxLightPremiumTokens.ink,
                        fontSize: 12.4,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Stack(
                      children: [
                        Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: widget.active
                                ? Colors.white.withValues(alpha: 0.18)
                                : InboxLightPremiumTokens.border,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: progress,
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  InboxLightPremiumTokens.violet,
                                  InboxLightPremiumTokens.pink,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                widget.active
                    ? Icons.timer_off_rounded
                    : Icons.auto_awesome_rounded,
                color: widget.active
                    ? Colors.white
                    : InboxLightPremiumTokens.violet,
                size: 18,
              ),
            ],
          ),
        ),
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
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFE0D5CB),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: conversation.colors),
                ),
                child: ClipOval(
                  child: conversation.avatarUrl?.trim().isNotEmpty == true
                      ? Image.network(
                          conversation.avatarUrl!.trim(),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _HeaderAvatarText(conversation: conversation),
                        )
                      : _HeaderAvatarText(conversation: conversation),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: InboxLightPremiumTokens.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      conversation.safePresenceText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: InboxLightPremiumTokens.muted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ActionTile(
            icon: conversation.secretDriftEnabled
                ? Icons.timer_off_rounded
                : Icons.timer_rounded,
            title: conversation.secretDriftEnabled
                ? 'Turn off disappearing mode'
                : 'Turn on disappearing mode',
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
    required this.driftMode,
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
  final bool driftMode;
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
  Widget build(BuildContext context) {
    final hasText = controller.text.trim().isNotEmpty;
    final disabled = readOnly;
    final composerGradient = driftMode
        ? const LinearGradient(
            colors: [Color(0xFF211133), Color(0xFF3D1B5F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : null;
    return Container(
      padding: EdgeInsets.fromLTRB(
        10,
        8,
        10,
        8 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _ComposerIconButton(
            tooltip: 'Emoji',
            icon: Icons.emoji_emotions_outlined,
            onTap: disabled ? null : onEmojiTap,
          ),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              constraints: const BoxConstraints(minHeight: 46, maxHeight: 104),
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                gradient: disabled ? null : composerGradient,
                color: driftMode || disabled
                    ? disabled
                          ? const Color(0xFFF2EDF4)
                          : null
                    : InboxLightPremiumTokens.pearl,
                borderRadius: BorderRadius.circular(23),
                border: Border.all(
                  color: driftMode
                      ? InboxLightPremiumTokens.pink.withValues(alpha: 0.52)
                      : hasText
                      ? const Color(0xFFCDB7FF)
                      : InboxLightPremiumTokens.border,
                ),
              ),
              child: TextField(
                controller: controller,
                enabled: !disabled,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                cursorColor: driftMode
                    ? Colors.white
                    : InboxLightPremiumTokens.violet,
                style: TextStyle(
                  color: driftMode ? Colors.white : InboxLightPremiumTokens.ink,
                  fontWeight: FontWeight.w800,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  prefixIcon: driftMode
                      ? const Icon(
                          Icons.timer_rounded,
                          color: Colors.white,
                          size: 17,
                        )
                      : null,
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  hintText: disabled
                      ? 'Replies disabled'
                      : recordingVoice
                      ? 'Recording voice...'
                      : driftMode
                      ? 'Disappearing message...'
                      : 'Message...',
                  hintStyle: TextStyle(
                    color: driftMode
                        ? Colors.white.withValues(alpha: 0.72)
                        : const Color(0xFF8C8198),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          _ComposerIconButton(
            tooltip: 'Attach',
            icon: Icons.add_rounded,
            onTap: disabled ? null : onAttachTap,
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: disabled ? null : onVoiceTap,
            onLongPressStart: disabled || sendingVoice
                ? null
                : (_) => onVoiceLongPressStart(),
            onLongPressEnd: disabled || sendingVoice
                ? null
                : (_) => onVoiceLongPressEnd(),
            onLongPressCancel: disabled || sendingVoice
                ? null
                : onVoiceLongPressCancel,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: recordingVoice
                    ? InboxLightPremiumTokens.danger
                    : InboxLightPremiumTokens.violet.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(
                  color: recordingVoice
                      ? Colors.white.withValues(alpha: 0.20)
                      : InboxLightPremiumTokens.violet.withValues(alpha: 0.14),
                ),
              ),
              child: Icon(
                sendingVoice
                    ? Icons.hourglass_top_rounded
                    : recordingVoice
                    ? Icons.stop_rounded
                    : Icons.mic_rounded,
                color: recordingVoice
                    ? Colors.white
                    : InboxLightPremiumTokens.violet,
                size: 21,
              ),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: disabled || !hasText ? null : onSendTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: disabled || !hasText
                    ? null
                    : const LinearGradient(
                        colors: [
                          InboxLightPremiumTokens.violet,
                          InboxLightPremiumTokens.pink,
                        ],
                      ),
                color: disabled || !hasText ? const Color(0xFFE1D8E8) : null,
                shape: BoxShape.circle,
                boxShadow: disabled || !hasText
                    ? null
                    : [
                        BoxShadow(
                          color: const Color(
                            0xFF7C3AED,
                          ).withValues(alpha: 0.26),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
              ),
              child: Icon(
                Icons.send_rounded,
                color: disabled || !hasText
                    ? InboxLightPremiumTokens.softMuted
                    : Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: enabled
                ? InboxLightPremiumTokens.violet.withValues(alpha: 0.09)
                : const Color(0xFFE9E0EE),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: enabled
                ? InboxLightPremiumTokens.violet
                : InboxLightPremiumTokens.softMuted,
            size: 21,
          ),
        ),
      ),
    );
  }
}

class _AttachmentSheet extends StatelessWidget {
  const _AttachmentSheet({required this.onPick});
  final ValueChanged<InboxMessageType> onPick;
  @override
  Widget build(BuildContext context) {
    final items = [
      _AttachmentItem(
        type: InboxMessageType.image,
        icon: Icons.image_rounded,
        label: 'Gallery',
        subtitle: 'Photos from device',
        colors: const [
          InboxLightPremiumTokens.pink,
          InboxLightPremiumTokens.violet,
        ],
      ),
      _AttachmentItem(
        type: InboxMessageType.document,
        icon: Icons.description_rounded,
        label: 'Document',
        subtitle: 'PDF, Office, ZIP',
        colors: const [InboxLightPremiumTokens.aqua, Color(0xFF0F766E)],
      ),
    ];
    return Container(
      margin: const EdgeInsets.all(14),
      padding: EdgeInsets.fromLTRB(
        14,
        12,
        14,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFE0D5CB),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Send something',
                  style: TextStyle(
                    color: InboxLightPremiumTokens.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.88,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return _AttachmentActionTile(
                item: item,
                onTap: () => onPick(item.type),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AttachmentItem {
  _AttachmentItem({
    required this.type,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.colors,
  });
  final InboxMessageType type;
  final IconData icon;
  final String label;
  final String subtitle;
  final List<Color> colors;
}

class _AttachmentActionTile extends StatelessWidget {
  const _AttachmentActionTile({required this.item, required this.onTap});

  final _AttachmentItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: InboxLightPremiumTokens.pearl,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: InboxLightPremiumTokens.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: item.colors),
                borderRadius: BorderRadius.circular(17),
                boxShadow: [
                  BoxShadow(
                    color: item.colors.last.withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(item.icon, color: Colors.white, size: 23),
            ),
            const SizedBox(height: 8),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: InboxLightPremiumTokens.ink,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              item.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF8C8198),
                fontSize: 9.8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.danger = false,
  });
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool danger;
  @override
  Widget build(BuildContext context) {
    final color = danger
        ? InboxLightPremiumTokens.danger
        : InboxLightPremiumTokens.ink;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
        child: Row(
          children: [
            Icon(icon, color: color, size: 21),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
