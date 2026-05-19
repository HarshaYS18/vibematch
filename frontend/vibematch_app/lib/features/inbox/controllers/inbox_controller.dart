import 'package:flutter/foundation.dart';

import '../data/inbox_api_service.dart';
import '../data/inbox_backup_api_service.dart';
import '../../profile/data/love_bond_realtime_service.dart';
import '../data/inbox_socket_service.dart';
import '../models/inbox_models.dart';

class InboxController extends ChangeNotifier {
  InboxController({
    InboxApiService? apiService,
    InboxBackupApiService? backupApiService,
    InboxSocketService? socketService,
  }) : _apiService = apiService ?? InboxApiService(),
       _backupApiService = backupApiService ?? const InboxBackupApiService(),
       _socketService = socketService ?? InboxSocketService();

  final InboxApiService _apiService;
  final InboxBackupApiService _backupApiService;
  final InboxSocketService _socketService;
  String selectedFilter = 'All';
  bool lockedVaultUnlocked = false;
  bool isLoading = false;
  bool _disposed = false;
  String? errorMessage;
  InboxLockStatus lockStatus = const InboxLockStatus(isEnabled: false);
  InboxBackupStatus backupStatus = const InboxBackupStatus(
    isEnabled: false,
    isAuthorized: false,
    provider: 'google_drive',
    frequency: ChatBackupFrequency.weekly,
    lastStatus: 'not_connected',
  );
  InboxBackupJob? lastBackupJob;
  InboxBackupJob? lastRestoreJob;
  String? lastGoogleDriveAuthorizationUrl;
  String? lastDebugOtp;
  bool strangersCanMessage = true;
  bool strangersCanMentionInVibes = true;
  String? _activeConversationId;
  final Map<String, String> _remoteActivityByConversationId = <String, String>{};

  String? remoteActivityForConversation(String conversationId) {
    final value = _remoteActivityByConversationId[conversationId];
    if (value == null || value == 'idle') return null;
    return value;
  }

  bool get backupEnabled => backupStatus.isEnabled;
  ChatBackupFrequency get backupFrequency => backupStatus.frequency;

  final List<String> filters = const [
    'All',
    'Unread',
    'Online',
    'Room Invites',
    'Official',
    'Strangers',
    'Blocked',
  ];

  List<InboxConversation> _conversations = <InboxConversation>[];
  final List<InboxReportTask> _reportTasks = <InboxReportTask>[];

  List<InboxConversation> get conversations =>
      List.unmodifiable(_conversations);
  List<InboxReportTask> get reportTasks => List.unmodifiable(_reportTasks);
  int get pendingReportTaskCount =>
      _reportTasks.where((task) => task.isPending).length;
  int get lockedCount => lockedConversations.length;
  int get unreadCount =>
      _conversations.fold<int>(0, (sum, chat) => sum + chat.unreadCount);

  List<InboxConversation> get unlockedConversations => _sortedConversations(
    _conversations.where((chat) => !chat.isLockedByBackend).toList(),
  );
  List<InboxConversation> get lockedConversations => _sortedConversations(
    _conversations.where((chat) => chat.isLockedByBackend).toList(),
  );

  List<InboxConversation> get visibleConversations {
    final base = unlockedConversations
        .where((chat) => !chat.isArchived)
        .toList();
    switch (selectedFilter) {
      case 'Unread':
        return base.where((chat) => chat.unreadCount > 0).toList();
      case 'Online':
        return base.where((chat) => chat.isOnline).toList();
      case 'Room Invites':
        return base
            .where((chat) => chat.type == InboxConversationType.roomInvite)
            .toList();
      case 'Official':
        return base
            .where((chat) => chat.type == InboxConversationType.official)
            .toList();
      case 'Strangers':
        return base
            .where((chat) => chat.type == InboxConversationType.stranger)
            .toList();
      case 'Blocked':
        return base.where((chat) => chat.isBlocked).toList();
      default:
        return base;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _socketService.disconnect();
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> loadFromBackend() async {
    isLoading = true;
    errorMessage = null;
    _safeNotify();
    try {
      lockStatus = await _apiService.loadLockStatus();
      backupStatus = await _backupApiService.loadStatus();
      _conversations = await _apiService.loadConversations();
      _reportTasks
        ..clear()
        ..addAll(await _apiService.loadReportTasks());
      await _socketService.connect(onEvent: _handleRealtimeEvent);
    } catch (error) {
      errorMessage = error.toString();
      _conversations = <InboxConversation>[];
    } finally {
      isLoading = false;
      _safeNotify();
    }
  }

  Future<String> startGoogleDriveAuthorization() async {
    lastGoogleDriveAuthorizationUrl = await _backupApiService
        .loadGoogleDriveSetupUrl();
    _safeNotify();
    return lastGoogleDriveAuthorizationUrl!;
  }

  Future<void> connectGoogleDrive({
    String? googleDriveEmail,
    String? setupCode,
  }) async {
    backupStatus = await _backupApiService.connectGoogleDrive(
      googleDriveEmail: googleDriveEmail,
      setupCode: setupCode,
    );
    _safeNotify();
  }

  Future<void> setBackupEnabled(bool value) async {
    backupStatus = await _backupApiService.updateSettings(isEnabled: value);
    _safeNotify();
  }

  Future<void> setBackupFrequency(ChatBackupFrequency frequency) async {
    backupStatus = await _backupApiService.updateSettings(frequency: frequency);
    _safeNotify();
  }

  Future<InboxBackupJob> runBackupNow() async {
    lastBackupJob = await _backupApiService.runBackupNow();
    backupStatus = await _backupApiService.loadStatus();
    _safeNotify();
    return lastBackupJob!;
  }

  Future<InboxBackupJob> restoreLatestBackup() async {
    lastRestoreJob = await _backupApiService.restoreLatestBackup();
    backupStatus = await _backupApiService.loadStatus();
    await loadFromBackend();
    return lastRestoreJob!;
  }

  Future<String?> startLockSetup(String mobileNumber) async {
    lastDebugOtp = await _apiService.startLockSetup(mobileNumber: mobileNumber);
    _safeNotify();
    return lastDebugOtp;
  }

  Future<void> verifyLockSetup({
    required String mobileNumber,
    required String otp,
    required String lockCode,
  }) async {
    lockStatus = await _apiService.verifyLockSetup(
      mobileNumber: mobileNumber,
      otp: otp,
      lockCode: lockCode,
    );
    lockedVaultUnlocked = true;
    _safeNotify();
  }

  Future<bool> verifyLock(String lockCode) async {
    try {
      await _apiService.verifyLock(lockCode: lockCode);
      lockedVaultUnlocked = true;
      _safeNotify();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> changeLock({
    required String currentLockCode,
    required String newLockCode,
  }) async {
    lockStatus = await _apiService.changeLock(
      currentLockCode: currentLockCode,
      newLockCode: newLockCode,
    );
    _safeNotify();
  }

  Future<String?> startLockRecovery(String mobileNumber) async {
    lastDebugOtp = await _apiService.startLockRecovery(
      mobileNumber: mobileNumber,
    );
    lockStatus = lockStatus.copyWith(recoveryRequested: true);
    _safeNotify();
    return lastDebugOtp;
  }

  Future<void> verifyLockRecovery({
    required String mobileNumber,
    required String otp,
    required String newLockCode,
  }) async {
    lockStatus = await _apiService.verifyLockRecovery(
      mobileNumber: mobileNumber,
      otp: otp,
      newLockCode: newLockCode,
    );
    lockedVaultUnlocked = true;
    _safeNotify();
  }

  Future<String> requestCsLockRecovery() async {
    final message = await _apiService.requestCsLockRecovery();
    lockStatus = lockStatus.copyWith(recoveryRequested: true);
    _safeNotify();
    return message;
  }

  void _handleRealtimeEvent(Map<String, dynamic> event) {
    final name = event['event']?.toString();
    switch (name) {
      case 'inbox_message_created':
        final conversationId = event['conversation_id']?.toString();
        final rawMessage = event['message'];
        if (conversationId != null && rawMessage is Map<String, dynamic>) {
          final message = _apiService.messageFromJson(rawMessage);
          _appendOrReconcileMessage(conversationId, message);
          if (!message.isMine && _activeConversationId == conversationId) {
            Future<void>.microtask(() => openConversationFromBackend(conversationId));
          }
        }
        break;
      case 'inbox_message_updated':
        final conversationId = event['conversation_id']?.toString();
        final rawMessage = event['message'];
        if (conversationId != null && rawMessage is Map<String, dynamic>) {
          final message = _apiService.messageFromJson(rawMessage);
          _updateMessage(
            conversationId: conversationId,
            message: message,
            mapper: (_) => message,
          );
        }
        break;
      case 'inbox_message_deleted':
        final conversationId = event['conversation_id']?.toString();
        final messageId = event['message_id']?.toString();
        if (conversationId != null && messageId != null)
          _removeMessageById(conversationId, messageId);
        break;
      case 'inbox_conversation_updated':
        loadFromBackend();
        break;
      case 'inbox_presence_updated':
        loadFromBackend();
        break;
      case 'inbox_typing_start':
        final conversationId = event['conversation_id']?.toString();
        if (conversationId != null && event['user_id'] != null) {
          _setRemoteActivity(conversationId, 'typing');
        }
        break;
      case 'inbox_typing_stop':
        final conversationId = event['conversation_id']?.toString();
        if (conversationId != null && event['user_id'] != null) {
          _setRemoteActivity(conversationId, 'idle');
        }
        break;
      case 'inbox_chat_activity':
      case 'chat_activity':
        final conversationId = event['conversation_id']?.toString();
        final activity = event['activity']?.toString();
        final isMine = event['is_mine'] == true || event['from_self'] == true;
        if (conversationId != null && activity != null && !isMine) {
          _setRemoteActivity(conversationId, activity);
        }
        break;
      case 'inbox_messages_read':
        final conversationId = event['conversation_id']?.toString();
        if (conversationId != null) _setConversationUnread(conversationId, 0);
        break;
      case 'inbox_report_task_updated':
      case 'inbox_report_status_updated':
        final rawTask = event['task'];
        if (rawTask is Map<String, dynamic>)
          _upsertReportTask(_apiService.reportFromJson(rawTask));
        break;
      default:
        break;
    }
  }

  void sendChatActivity({
    required String conversationId,
    required String activity,
  }) {
    _socketService.sendChatActivity(
      conversationId: conversationId,
      activity: activity,
    );
  }

  void _setRemoteActivity(String conversationId, String activity) {
    if (activity == 'idle') {
      _remoteActivityByConversationId.remove(conversationId);
    } else {
      _remoteActivityByConversationId[conversationId] = activity;
      Future<void>.delayed(const Duration(seconds: 5), () {
        if (_remoteActivityByConversationId[conversationId] == activity) {
          _remoteActivityByConversationId.remove(conversationId);
          _safeNotify();
        }
      });
    }
    _safeNotify();
  }

  Future<InboxConversation?> createDirectConversation({
    required int targetUserId,
  }) async {
    try {
      final conversation = await _apiService.createDirectConversation(
        targetUserId: targetUserId,
      );
      _upsertConversation(conversation);
      return conversation;
    } catch (error) {
      errorMessage = error.toString();
      _safeNotify();
      return null;
    }
  }

  List<InboxConversation> _sortedConversations(List<InboxConversation> items) =>
      [...items]
        ..sort((a, b) => a.isPinned == b.isPinned ? 0 : (a.isPinned ? -1 : 1));

  InboxConversation? conversationById(String conversationId) {
    for (final conversation in _conversations) {
      if (conversation.id == conversationId) return conversation;
    }
    return null;
  }

  Future<void> openConversationFromBackend(String conversationId) async {
    try {
      final updated = await _apiService.getConversation(conversationId);
      _upsertConversation(updated);
      notifyListeners();
    } catch (_) {
      markConversationRead(conversationId);
    }
  }

  void markConversationRead(String conversationId) {
    _activeConversationId = conversationId;
    _setConversationUnread(conversationId, 0);
    _socketService.markRead(conversationId);
  }

  void clearActiveConversation(String conversationId) {
    if (_activeConversationId != conversationId) return;
    _activeConversationId = null;
  }

  List<InboxSearchResult> searchInbox(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return const [];
    final results = <InboxSearchResult>[];
    for (final conversation in unlockedConversations) {
      if (conversation.title.toLowerCase().contains(normalizedQuery) ||
          conversation.subtitle.toLowerCase().contains(normalizedQuery) ||
          (conversation.currentRoomName?.toLowerCase() ?? '').contains(
            normalizedQuery,
          )) {
        results.add(
          InboxSearchResult(
            conversation: conversation,
            matchType: conversation.isMutualFollowChat
                ? InboxSearchMatchType.mutualFollow
                : InboxSearchMatchType.chat,
            title: conversation.title,
            preview: conversation.subtitle,
            matchedText: query.trim(),
          ),
        );
      }
      for (final message in conversation.messages) {
        if (message.text.toLowerCase().contains(normalizedQuery)) {
          results.add(
            InboxSearchResult(
              conversation: conversation,
              matchType: InboxSearchMatchType.message,
              title: conversation.title,
              preview: message.text,
              matchedText: query.trim(),
              message: message,
            ),
          );
        }
      }
    }
    return results;
  }

  bool validatePasscode(String value) => value.trim().length >= 4;
  void unlockLockedVault() {
    lockedVaultUnlocked = true;
    _safeNotify();
  }

  void lockLockedVault() {
    lockedVaultUnlocked = false;
    _safeNotify();
  }

  void selectFilter(String filter) {
    selectedFilter = filter;
    _safeNotify();
  }

  void setStrangersCanMessage(bool value) {
    strangersCanMessage = value;
    _safeNotify();
  }

  void setStrangersCanMentionInVibes(bool value) {
    strangersCanMentionInVibes = value;
    _safeNotify();
  }

  Future<void> toggleBackendLock(InboxConversation conversation) =>
      _updateState(conversation, isLocked: !conversation.isLockedByBackend);
  Future<void> toggleBlock(InboxConversation conversation) =>
      _updateState(conversation, isBlocked: !conversation.isBlocked);
  Future<void> toggleMute(InboxConversation conversation) =>
      _updateState(conversation, isMuted: !conversation.isMuted);
  Future<void> togglePin(InboxConversation conversation) =>
      _updateState(conversation, isPinned: !conversation.isPinned);
  void toggleArchive(InboxConversation conversation) {
    _replaceConversation(
      conversation.id,
      (chat) => chat.copyWith(isArchived: !chat.isArchived),
    );
  }

  Future<void> _updateState(
    InboxConversation conversation, {
    bool? isMuted,
    bool? isPinned,
    bool? isLocked,
    bool? isBlocked,
  }) async {
    if (conversation.isOfficial &&
        (isLocked != null || isBlocked != null || isMuted != null))
      return;
    _replaceConversation(
      conversation.id,
      (chat) => chat.copyWith(
        isMuted: isMuted,
        isPinned: isPinned,
        isLockedByBackend: isLocked,
        isBlocked: isBlocked,
      ),
    );
    try {
      final updated = await _apiService.updateConversationState(
        conversationId: conversation.id,
        isMuted: isMuted,
        isPinned: isPinned,
        isLocked: isLocked,
        isBlocked: isBlocked,
      );
      _replaceConversation(conversation.id, (_) => updated);
    } catch (_) {}
  }

  Future<void> acceptLoveBondRequest({
    required String conversationId,
    required InboxMessage message,
  }) async {
    final requestId = message.loveBondRequestId;
    if (requestId == null || requestId.trim().isEmpty) return;

    _updateMessage(
      conversationId: conversationId,
      message: message,
      mapper: (item) => item.copyWith(
        text: 'Accepted ${item.loveBondCardName ?? 'relationship'} request.',
        loveBondStatus: 'accepted',
      ),
    );

    try {
      await LoveBondRealtimeService.acceptRequestOnBackend(
        requestId: requestId,
        receiverPublicUserId: 0,
      );
      await loadFromBackend();
    } catch (_) {
      _updateMessage(
        conversationId: conversationId,
        message: message,
        mapper: (item) => item.copyWith(
          text: message.text,
          loveBondStatus: message.loveBondStatus ?? 'pending',
        ),
      );
    }
  }

  Future<void> rejectLoveBondRequest({
    required String conversationId,
    required InboxMessage message,
  }) async {
    final requestId = message.loveBondRequestId;
    if (requestId == null || requestId.trim().isEmpty) return;

    _updateMessage(
      conversationId: conversationId,
      message: message,
      mapper: (item) => item.copyWith(
        text: 'Rejected ${item.loveBondCardName ?? 'relationship'} request.',
        loveBondStatus: 'rejected',
      ),
    );

    try {
      await LoveBondRealtimeService.rejectRequestOnBackend(
        requestId: requestId,
        receiverPublicUserId: 0,
      );
      await loadFromBackend();
    } catch (_) {
      _updateMessage(
        conversationId: conversationId,
        message: message,
        mapper: (item) => item.copyWith(
          text: message.text,
          loveBondStatus: message.loveBondStatus ?? 'pending',
        ),
      );
    }
  }

  Future<void> sendTextMessage({
    required String conversationId,
    required String text,
    String? replyToText,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final local = InboxMessage(
      id: 'local_${DateTime.now().microsecondsSinceEpoch}',
      sender: 'You',
      text: trimmed,
      time: 'Now',
      isMine: true,
      status: InboxMessageStatus.sending,
      replyToText: replyToText,
    );
    _appendMessage(conversationId, local);
    try {
      final sent = await _apiService.sendMessage(
        conversationId: conversationId,
        text: trimmed,
        replyToText: replyToText,
      );
      _replaceLocalMessage(conversationId, local, sent);
    } catch (error) {
      errorMessage = error.toString();
      _updateMessage(
        conversationId: conversationId,
        message: local,
        mapper: (item) => item.copyWith(status: InboxMessageStatus.failed),
      );
    }
  }

  Future<void> retryFailedMessage({
    required String conversationId,
    required InboxMessage message,
  }) async {
    if (!message.isMine || message.status != InboxMessageStatus.failed) return;

    final retrying = message.copyWith(status: InboxMessageStatus.sending, time: 'Now');

    _updateMessage(
      conversationId: conversationId,
      message: message,
      mapper: (_) => retrying,
    );

    try {
      final sent = await _apiService.sendMessage(
        conversationId: conversationId,
        text: retrying.text,
        type: _messageTypeApiValue(retrying.type),
        replyToText: retrying.replyToText,
        inviteRoomName: retrying.inviteRoomName,
        inviteRoomId: retrying.inviteRoomId,
        attachmentUrl: retrying.attachmentUrl,
      );
      _replaceLocalMessage(conversationId, retrying, sent);
    } catch (error) {
      errorMessage = error.toString();
      _updateMessage(
        conversationId: conversationId,
        message: retrying,
        mapper: (item) => item.copyWith(status: InboxMessageStatus.failed),
      );
    }
  }

  String _messageTypeApiValue(InboxMessageType type) {
    return switch (type) {
      InboxMessageType.image => 'image',
      InboxMessageType.voice => 'voice',
      InboxMessageType.document => 'document',
      InboxMessageType.location => 'location',
      InboxMessageType.contact => 'contact',
      InboxMessageType.roomInvite => 'room_invite',
      InboxMessageType.relationshipRequest => 'relationship_request',
      InboxMessageType.system => 'system',
      InboxMessageType.storyReply => 'story_reply',
      InboxMessageType.callLog => 'call_log',
      InboxMessageType.text => 'text',
    };
  }

  void addMockAttachment({
    required String conversationId,
    required InboxMessageType type,
  }) {
    final text = switch (type) {
      InboxMessageType.image => '📷 Photo attached',
      InboxMessageType.voice => '🎙 Voice message 0:08',
      InboxMessageType.document => '📄 Document attached',
      InboxMessageType.location => '📍 Shared location',
      _ => 'Attachment',
    };
    _appendMessage(
      conversationId,
      InboxMessage(
        id: 'local_${DateTime.now().microsecondsSinceEpoch}',
        sender: 'You',
        text: text,
        time: 'Now',
        isMine: true,
        type: type,
        status: InboxMessageStatus.read,
      ),
    );
  }

  void addPickedDocumentAttachment({
    required String conversationId,
    required String fileName,
    required int sizeBytes,
    String? filePath,
  }) {
    final sizeLabel = _formatBytes(sizeBytes);
    _appendMessage(
      conversationId,
      InboxMessage(
        id: 'doc_${DateTime.now().microsecondsSinceEpoch}',
        sender: 'You',
        text: '📄 $fileName • $sizeLabel',
        time: 'Now',
        isMine: true,
        type: InboxMessageType.document,
        status: InboxMessageStatus.read,
      ),
    );
  }

  Future<InboxReportTask> submitConversationReport({
    required InboxConversation conversation,
    required String reason,
  }) async {
    final snapshot = conversation.messages.length <= 30
        ? conversation.messages
        : conversation.messages.sublist(conversation.messages.length - 30);
    final local = InboxReportTask(
      id: 'report_${DateTime.now().microsecondsSinceEpoch}',
      reportedConversationId: conversation.id,
      reportedUserName: conversation.title,
      reporterName: 'You',
      reason: reason.trim().isEmpty
          ? 'Unsafe or abusive conversation'
          : reason.trim(),
      snapshot: List<InboxMessage>.unmodifiable(snapshot),
      createdAtLabel: 'Now',
      status: InboxReportStatus.pendingCsReview,
    );
    _reportTasks.insert(0, local);
    _safeNotify();
    try {
      final remote = await _apiService.submitReport(
        conversation: conversation,
        reason: local.reason,
      );
      _replaceReportTask(local.id, remote);
      return remote;
    } catch (_) {
      return local;
    }
  }

  Future<void> rejectReportTask(InboxReportTask task) async {
    _replaceReportTask(
      task.id,
      task.copyWith(status: InboxReportStatus.rejectedByCs),
    );
    try {
      _replaceReportTask(task.id, await _apiService.rejectReport(task));
    } catch (_) {}
  }

  Future<void> acceptReportTask(InboxReportTask task) async {
    _replaceReportTask(
      task.id,
      task.copyWith(
        status: InboxReportStatus.acceptedEscalated,
        monitorAction: 'Pending Monitor action',
      ),
    );
    try {
      _replaceReportTask(task.id, await _apiService.acceptReport(task));
    } catch (_) {}
  }

  Future<void> applyMonitorAction(
    InboxReportTask task,
    String actionLabel,
  ) async {
    _replaceReportTask(
      task.id,
      task.copyWith(
        status: InboxReportStatus.monitorActionTaken,
        monitorAction: actionLabel,
      ),
    );
    try {
      _replaceReportTask(
        task.id,
        await _apiService.applyMonitorAction(task, actionLabel),
      );
    } catch (_) {}
  }

  Future<void> setReaction({
    required String conversationId,
    required InboxMessage message,
    required String reaction,
  }) async {
    _updateMessage(
      conversationId: conversationId,
      message: message,
      mapper: (item) => item.copyWith(reaction: reaction),
    );
    if (message.id != null) {
      try {
        await _apiService.updateMessage(
          conversationId: conversationId,
          messageId: message.id!,
          reaction: reaction,
        );
      } catch (_) {}
    }
  }

  Future<void> toggleStarMessage({
    required String conversationId,
    required InboxMessage message,
  }) async {
    final next = !message.isStarred;
    _updateMessage(
      conversationId: conversationId,
      message: message,
      mapper: (item) => item.copyWith(isStarred: next),
    );
    if (message.id != null) {
      try {
        await _apiService.updateMessage(
          conversationId: conversationId,
          messageId: message.id!,
          isStarred: next,
        );
      } catch (_) {}
    }
  }

  Future<void> deleteMessage({
    required String conversationId,
    required InboxMessage message,
  }) async {
    _replaceConversation(conversationId, (chat) {
      final updated = chat.messages
          .where((item) => !_sameMessage(item, message))
          .toList();
      return chat.copyWith(
        messages: updated,
        subtitle: updated.isEmpty ? 'No messages yet' : updated.last.text,
      );
    });
    if (message.id != null) {
      try {
        await _apiService.deleteMessage(
          conversationId: conversationId,
          messageId: message.id!,
        );
      } catch (_) {}
    }
  }

  void forwardMessage({
    required String fromConversationId,
    required InboxMessage message,
  }) {
    _appendMessage(
      fromConversationId,
      message.copyWith(
        id: 'forward_${DateTime.now().microsecondsSinceEpoch}',
        sender: 'You',
        time: 'Now',
        isMine: true,
        isForwarded: true,
        status: InboxMessageStatus.read,
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
  }

  void _appendMessage(String conversationId, InboxMessage message) =>
      _replaceConversation(
        conversationId,
        (chat) => chat.copyWith(
          messages: [...chat.messages, message],
          subtitle: message.text,
          time: 'Now',
          unreadCount: message.isMine ? 0 : chat.unreadCount + 1,
        ),
      );
  void _appendOrReconcileMessage(String conversationId, InboxMessage message) {
    if (!message.isMine && _activeConversationId == conversationId) {
      _socketService.markRead(conversationId);
    }
    _replaceConversation(conversationId, (chat) {
      final messages = [...chat.messages];
      final exactIndex = messages.indexWhere(
        (item) => item.id != null && item.id == message.id,
      );
      if (exactIndex != -1) {
        messages[exactIndex] = message;
        return chat.copyWith(
          messages: messages,
          subtitle: message.text,
          time: 'Now',
        );
      }
      final pendingIndex = messages.lastIndexWhere(
        (item) => _isPendingLocalMatch(item, message),
      );
      if (pendingIndex != -1) {
        messages[pendingIndex] = message;
        return chat.copyWith(
          messages: messages,
          subtitle: message.text,
          time: 'Now',
          unreadCount: 0,
        );
      }
      messages.add(message);
      return chat.copyWith(
        messages: messages,
        subtitle: message.text,
        time: 'Now',
        unreadCount: _nextUnreadCount(chat, message),
      );
    });
  }

  void _replaceLocalMessage(
    String conversationId,
    InboxMessage local,
    InboxMessage remote,
  ) => _replaceConversation(conversationId, (chat) {
    final messages = [...chat.messages];
    final localIndex = messages.indexWhere((item) => _sameMessage(item, local));
    final remoteIndex = messages.indexWhere(
      (item) => item.id != null && item.id == remote.id,
    );
    if (localIndex != -1 && remoteIndex != -1 && localIndex != remoteIndex) {
      messages.removeAt(localIndex);
      final adjustedRemoteIndex = remoteIndex > localIndex
          ? remoteIndex - 1
          : remoteIndex;
      messages[adjustedRemoteIndex] = remote;
    } else if (localIndex != -1) {
      messages[localIndex] = remote;
    } else if (remoteIndex != -1) {
      messages[remoteIndex] = remote;
    } else {
      messages.add(remote);
    }
    return chat.copyWith(
      messages: messages,
      subtitle: remote.text,
      time: 'Now',
      unreadCount: 0,
    );
  });
  void _removeMessageById(String conversationId, String messageId) =>
      _replaceConversation(conversationId, (chat) {
        final updated = chat.messages
            .where((item) => item.id != messageId)
            .toList();
        return chat.copyWith(
          messages: updated,
          subtitle: updated.isEmpty ? 'No messages yet' : updated.last.text,
        );
      });
  void _updateMessage({
    required String conversationId,
    required InboxMessage message,
    required InboxMessage Function(InboxMessage item) mapper,
  }) => _replaceConversation(
    conversationId,
    (chat) => chat.copyWith(
      messages: chat.messages
          .map((item) => _sameMessage(item, message) ? mapper(item) : item)
          .toList(),
    ),
  );
  void _replaceConversation(
    String conversationId,
    InboxConversation Function(InboxConversation chat) mapper,
  ) {
    _conversations = _conversations
        .map((chat) => chat.id == conversationId ? mapper(chat) : chat)
        .toList();
    _safeNotify();
  }

  void _setConversationUnread(String conversationId, int unreadCount) =>
      _replaceConversation(
        conversationId,
        (chat) => chat.copyWith(unreadCount: unreadCount),
      );
  void _upsertConversation(InboxConversation conversation) {
    final index = _conversations.indexWhere(
      (item) => item.id == conversation.id,
    );
    if (index == -1) {
      _conversations.insert(0, conversation);
    } else {
      _conversations[index] = conversation;
    }
    _safeNotify();
  }

  void _replaceReportTask(String taskId, InboxReportTask replacement) {
    for (var index = 0; index < _reportTasks.length; index++) {
      if (_reportTasks[index].id == taskId) {
        _reportTasks[index] = replacement;
        _safeNotify();
        return;
      }
    }
  }

  void _upsertReportTask(InboxReportTask task) {
    final index = _reportTasks.indexWhere((item) => item.id == task.id);
    if (index == -1) {
      _reportTasks.insert(0, task);
    } else {
      _reportTasks[index] = task;
    }
    _safeNotify();
  }

  bool _sameMessage(InboxMessage a, InboxMessage b) =>
      a.id != null && b.id != null
      ? a.id == b.id
      : a.sender == b.sender &&
            a.text == b.text &&
            a.time == b.time &&
            a.isMine == b.isMine;
  int _nextUnreadCount(InboxConversation chat, InboxMessage message) {
    if (message.isMine || chat.id == _activeConversationId) return 0;
    if (chat.isMuted) return chat.unreadCount;
    return chat.unreadCount + 1;
  }

  bool _isPendingLocalMatch(InboxMessage local, InboxMessage remote) {
    final localId = local.id ?? '';
    if (!localId.startsWith('local_') && !localId.startsWith('doc_'))
      return false;
    if (!local.isMine || !remote.isMine) return false;
    return local.text.trim() == remote.text.trim() &&
        local.type == remote.type &&
        local.replyToText == remote.replyToText;
  }
}
