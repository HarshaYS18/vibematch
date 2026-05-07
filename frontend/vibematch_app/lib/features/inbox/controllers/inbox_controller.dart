import 'package:flutter/foundation.dart';

import '../data/inbox_api_service.dart';
import '../data/inbox_mock_data.dart';
import '../data/inbox_socket_service.dart';
import '../models/inbox_models.dart';

class InboxController extends ChangeNotifier {
  InboxController({InboxApiService? apiService, InboxSocketService? socketService})
      : _apiService = apiService ?? InboxApiService(),
        _socketService = socketService ?? InboxSocketService();

  static const String mockAccountPasscode = '1234';

  final InboxApiService _apiService;
  final InboxSocketService _socketService;
  String selectedFilter = 'All';
  bool lockedVaultUnlocked = false;
  bool isLoading = false;
  bool _disposed = false;
  String? errorMessage;
  ChatBackupFrequency backupFrequency = ChatBackupFrequency.weekly;
  bool backupEnabled = true;
  bool strangersCanMessage = true;
  bool strangersCanMentionInVibes = true;

  final List<String> filters = const ['All', 'Unread', 'Online', 'Room Invites', 'Official', 'Strangers', 'Blocked'];

  List<InboxConversation> _conversations = List<InboxConversation>.from(InboxMockData.conversations);
  final List<InboxReportTask> _reportTasks = <InboxReportTask>[];

  List<InboxConversation> get conversations => List.unmodifiable(_conversations);
  List<InboxReportTask> get reportTasks => List.unmodifiable(_reportTasks);
  int get pendingReportTaskCount => _reportTasks.where((task) => task.isPending).length;
  int get lockedCount => lockedConversations.length;
  int get unreadCount => _conversations.fold<int>(0, (sum, chat) => sum + chat.unreadCount);

  List<InboxConversation> get unlockedConversations => _sortedConversations(_conversations.where((chat) => !chat.isLockedByBackend).toList());
  List<InboxConversation> get lockedConversations => _sortedConversations(_conversations.where((chat) => chat.isLockedByBackend).toList());

  List<InboxConversation> get visibleConversations {
    final base = unlockedConversations.where((chat) => !chat.isArchived).toList();
    switch (selectedFilter) {
      case 'Unread': return base.where((chat) => chat.unreadCount > 0).toList();
      case 'Online': return base.where((chat) => chat.isOnline).toList();
      case 'Room Invites': return base.where((chat) => chat.type == InboxConversationType.roomInvite).toList();
      case 'Official': return base.where((chat) => chat.type == InboxConversationType.official).toList();
      case 'Strangers': return base.where((chat) => chat.type == InboxConversationType.stranger).toList();
      case 'Blocked': return base.where((chat) => chat.isBlocked).toList();
      default: return base;
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
      _conversations = await _apiService.loadConversations();
      _reportTasks
        ..clear()
        ..addAll(await _apiService.loadReportTasks());
      await _socketService.connect(onEvent: _handleRealtimeEvent);
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      _safeNotify();
    }
  }

  void _handleRealtimeEvent(Map<String, dynamic> event) {
    final name = event['event']?.toString();
    switch (name) {
      case 'inbox_message_created':
        final conversationId = event['conversation_id']?.toString();
        final rawMessage = event['message'];
        if (conversationId != null && rawMessage is Map<String, dynamic>) {
          final message = _apiService.messageFromJson(rawMessage);
          final conversation = conversationById(conversationId);
          final alreadyExists = conversation?.messages.any((item) => item.id != null && item.id == message.id) ?? false;
          if (!alreadyExists) _appendMessage(conversationId, message);
        }
        break;
      case 'inbox_message_updated':
        final conversationId = event['conversation_id']?.toString();
        final rawMessage = event['message'];
        if (conversationId != null && rawMessage is Map<String, dynamic>) {
          final message = _apiService.messageFromJson(rawMessage);
          _updateMessage(conversationId: conversationId, message: message, mapper: (_) => message);
        }
        break;
      case 'inbox_message_deleted':
        final conversationId = event['conversation_id']?.toString();
        final messageId = event['message_id']?.toString();
        if (conversationId != null && messageId != null) {
          _removeMessageById(conversationId, messageId);
        }
        break;
      case 'inbox_conversation_updated':
        loadFromBackend();
        break;
      case 'inbox_report_task_updated':
      case 'inbox_report_status_updated':
        final rawTask = event['task'];
        if (rawTask is Map<String, dynamic>) {
          final task = _apiService.reportFromJson(rawTask);
          _upsertReportTask(task);
        }
        break;
      default:
        break;
    }
  }

  Future<InboxConversation?> createDirectConversation({required int targetUserId}) async {
    try {
      final conversation = await _apiService.createDirectConversation(targetUserId: targetUserId);
      _upsertConversation(conversation);
      return conversation;
    } catch (error) {
      errorMessage = error.toString();
      _safeNotify();
      return null;
    }
  }

  List<InboxConversation> _sortedConversations(List<InboxConversation> items) {
    return [...items]..sort((a, b) => a.isPinned == b.isPinned ? 0 : (a.isPinned ? -1 : 1));
  }

  InboxConversation? conversationById(String conversationId) {
    for (final conversation in _conversations) {
      if (conversation.id == conversationId) return conversation;
    }
    return null;
  }

  List<InboxSearchResult> searchInbox(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return const [];
    final results = <InboxSearchResult>[];
    for (final conversation in unlockedConversations) {
      if (conversation.title.toLowerCase().contains(normalizedQuery) || conversation.subtitle.toLowerCase().contains(normalizedQuery) || (conversation.currentRoomName?.toLowerCase() ?? '').contains(normalizedQuery)) {
        results.add(InboxSearchResult(conversation: conversation, matchType: conversation.isMutualFollowChat ? InboxSearchMatchType.mutualFollow : InboxSearchMatchType.chat, title: conversation.title, preview: conversation.subtitle, matchedText: query.trim()));
      }
      for (final message in conversation.messages) {
        if (message.text.toLowerCase().contains(normalizedQuery)) {
          results.add(InboxSearchResult(conversation: conversation, matchType: InboxSearchMatchType.message, title: conversation.title, preview: message.text, matchedText: query.trim(), message: message));
        }
      }
    }
    return results;
  }

  bool validatePasscode(String value) => value.trim() == mockAccountPasscode;
  void unlockLockedVault() { lockedVaultUnlocked = true; _safeNotify(); }
  void lockLockedVault() { lockedVaultUnlocked = false; _safeNotify(); }
  void selectFilter(String filter) { selectedFilter = filter; _safeNotify(); }
  void setBackupEnabled(bool value) { backupEnabled = value; _safeNotify(); }
  void setBackupFrequency(ChatBackupFrequency frequency) { backupFrequency = frequency; _safeNotify(); }
  void setStrangersCanMessage(bool value) { strangersCanMessage = value; _safeNotify(); }
  void setStrangersCanMentionInVibes(bool value) { strangersCanMentionInVibes = value; _safeNotify(); }

  Future<void> toggleBackendLock(InboxConversation conversation) => _updateState(conversation, isLocked: !conversation.isLockedByBackend);
  Future<void> toggleBlock(InboxConversation conversation) => _updateState(conversation, isBlocked: !conversation.isBlocked);
  Future<void> toggleMute(InboxConversation conversation) => _updateState(conversation, isMuted: !conversation.isMuted);
  Future<void> togglePin(InboxConversation conversation) => _updateState(conversation, isPinned: !conversation.isPinned);
  void toggleArchive(InboxConversation conversation) {}

  Future<void> _updateState(InboxConversation conversation, {bool? isMuted, bool? isPinned, bool? isLocked, bool? isBlocked}) async {
    if (conversation.isOfficial && (isLocked != null || isBlocked != null || isMuted != null)) return;
    _replaceConversation(conversation.id, (chat) => chat.copyWith(isMuted: isMuted, isPinned: isPinned, isLockedByBackend: isLocked, isBlocked: isBlocked));
    try {
      final updated = await _apiService.updateConversationState(conversationId: conversation.id, isMuted: isMuted, isPinned: isPinned, isLocked: isLocked, isBlocked: isBlocked);
      _replaceConversation(conversation.id, (_) => updated);
    } catch (_) {}
  }

  Future<void> sendTextMessage({required String conversationId, required String text, String? replyToText}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final local = InboxMessage(id: 'local_${DateTime.now().microsecondsSinceEpoch}', sender: 'You', text: trimmed, time: 'Now', isMine: true, status: InboxMessageStatus.read, replyToText: replyToText);
    _appendMessage(conversationId, local);
    try {
      final sent = await _apiService.sendMessage(conversationId: conversationId, text: trimmed, replyToText: replyToText);
      _replaceLocalMessage(conversationId, local, sent);
    } catch (_) {}
  }

  void addMockAttachment({required String conversationId, required InboxMessageType type}) {
    final text = switch (type) { InboxMessageType.image => '📷 Photo attached', InboxMessageType.voice => '🎙 Voice message 0:08', InboxMessageType.document => '📄 Document attached', InboxMessageType.location => '📍 Shared location', _ => 'Attachment' };
    _appendMessage(conversationId, InboxMessage(id: 'local_${DateTime.now().microsecondsSinceEpoch}', sender: 'You', text: text, time: 'Now', isMine: true, type: type, status: InboxMessageStatus.read));
  }

  Future<InboxReportTask> submitConversationReport({required InboxConversation conversation, required String reason}) async {
    final snapshot = conversation.messages.length <= 30 ? conversation.messages : conversation.messages.sublist(conversation.messages.length - 30);
    final local = InboxReportTask(id: 'report_${DateTime.now().microsecondsSinceEpoch}', reportedConversationId: conversation.id, reportedUserName: conversation.title, reporterName: 'You', reason: reason.trim().isEmpty ? 'Unsafe or abusive conversation' : reason.trim(), snapshot: List<InboxMessage>.unmodifiable(snapshot), createdAtLabel: 'Now', status: InboxReportStatus.pendingCsReview);
    _reportTasks.insert(0, local);
    _sendTeamSystemMessage('Report submitted. CS will review the conversation snapshot and escalate if action is needed.');
    _safeNotify();
    try {
      final remote = await _apiService.submitReport(conversation: conversation, reason: local.reason);
      _replaceReportTask(local.id, remote);
      return remote;
    } catch (_) { return local; }
  }

  Future<void> rejectReportTask(InboxReportTask task) async {
    _replaceReportTask(task.id, task.copyWith(status: InboxReportStatus.rejectedByCs, csNote: 'CS reviewed the snapshot and did not find enough evidence for punishment.'));
    _sendTeamSystemMessage('Report failed. CS reviewed your report about ${task.reportedUserName}, but there was not enough evidence to punish the user.');
    try { _replaceReportTask(task.id, await _apiService.rejectReport(task)); } catch (_) {}
  }

  Future<void> acceptReportTask(InboxReportTask task) async {
    _replaceReportTask(task.id, task.copyWith(status: InboxReportStatus.acceptedEscalated, csNote: 'CS accepted the report and sent it to Monitor team for punishment action.', monitorAction: 'Pending Monitor action'));
    _sendTeamSystemMessage('Report successful. ${task.reportedUserName} has been sent to Monitor team for punishment review.');
    try { _replaceReportTask(task.id, await _apiService.acceptReport(task)); } catch (_) {}
  }

  Future<void> applyMonitorAction(InboxReportTask task, String actionLabel) async {
    _replaceReportTask(task.id, task.copyWith(status: InboxReportStatus.monitorActionTaken, monitorAction: actionLabel));
    _sendTeamSystemMessage('Report successful. ${task.reportedUserName} has been punished by Monitor team: $actionLabel.');
    try { _replaceReportTask(task.id, await _apiService.applyMonitorAction(task, actionLabel)); } catch (_) {}
  }

  Future<void> setReaction({required String conversationId, required InboxMessage message, required String reaction}) async {
    _updateMessage(conversationId: conversationId, message: message, mapper: (item) => item.copyWith(reaction: reaction));
    if (message.id != null) { try { await _apiService.updateMessage(conversationId: conversationId, messageId: message.id!, reaction: reaction); } catch (_) {} }
  }

  Future<void> toggleStarMessage({required String conversationId, required InboxMessage message}) async {
    final next = !message.isStarred;
    _updateMessage(conversationId: conversationId, message: message, mapper: (item) => item.copyWith(isStarred: next));
    if (message.id != null) { try { await _apiService.updateMessage(conversationId: conversationId, messageId: message.id!, isStarred: next); } catch (_) {} }
  }

  Future<void> deleteMessage({required String conversationId, required InboxMessage message}) async {
    _replaceConversation(conversationId, (chat) { final updated = chat.messages.where((item) => !_sameMessage(item, message)).toList(); return chat.copyWith(messages: updated, subtitle: updated.isEmpty ? 'No messages yet' : updated.last.text); });
    if (message.id != null) { try { await _apiService.deleteMessage(conversationId: conversationId, messageId: message.id!); } catch (_) {} }
  }

  void forwardMessage({required String fromConversationId, required InboxMessage message}) {
    _appendMessage(fromConversationId, message.copyWith(id: 'forward_${DateTime.now().microsecondsSinceEpoch}', sender: 'You', time: 'Now', isMine: true, isForwarded: true, status: InboxMessageStatus.read));
  }

  void _sendTeamSystemMessage(String text) {
    final team = conversationById('team_official');
    if (team == null) return;
    _appendMessage(team.id, InboxMessage(id: 'system_${DateTime.now().microsecondsSinceEpoch}', sender: 'Vibe Match Team', text: text, time: 'Now', isMine: false, type: InboxMessageType.system));
  }

  void _appendMessage(String conversationId, InboxMessage message) => _replaceConversation(conversationId, (chat) => chat.copyWith(messages: [...chat.messages, message], subtitle: message.text, time: 'Now', unreadCount: 0));
  void _replaceLocalMessage(String conversationId, InboxMessage local, InboxMessage remote) => _updateMessage(conversationId: conversationId, message: local, mapper: (_) => remote);
  void _removeMessageById(String conversationId, String messageId) => _replaceConversation(conversationId, (chat) { final updated = chat.messages.where((item) => item.id != messageId).toList(); return chat.copyWith(messages: updated, subtitle: updated.isEmpty ? 'No messages yet' : updated.last.text); });
  void _updateMessage({required String conversationId, required InboxMessage message, required InboxMessage Function(InboxMessage item) mapper}) => _replaceConversation(conversationId, (chat) => chat.copyWith(messages: chat.messages.map((item) => _sameMessage(item, message) ? mapper(item) : item).toList()));
  void _replaceConversation(String conversationId, InboxConversation Function(InboxConversation chat) mapper) { _conversations = _conversations.map((chat) => chat.id == conversationId ? mapper(chat) : chat).toList(); _safeNotify(); }
  void _upsertConversation(InboxConversation conversation) { final index = _conversations.indexWhere((item) => item.id == conversation.id); if (index == -1) { _conversations.insert(0, conversation); } else { _conversations[index] = conversation; } _safeNotify(); }
  void _replaceReportTask(String taskId, InboxReportTask replacement) { for (var index = 0; index < _reportTasks.length; index++) { if (_reportTasks[index].id == taskId) { _reportTasks[index] = replacement; _safeNotify(); return; } } }
  void _upsertReportTask(InboxReportTask task) { final index = _reportTasks.indexWhere((item) => item.id == task.id); if (index == -1) { _reportTasks.insert(0, task); } else { _reportTasks[index] = task; } _safeNotify(); }
  bool _sameMessage(InboxMessage a, InboxMessage b) => a.id != null && b.id != null ? a.id == b.id : a.sender == b.sender && a.text == b.text && a.time == b.time && a.isMine == b.isMine;
}
