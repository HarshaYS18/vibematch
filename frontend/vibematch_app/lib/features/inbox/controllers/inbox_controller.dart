import 'package:flutter/foundation.dart';

import '../data/inbox_mock_data.dart';
import '../models/inbox_models.dart';

class InboxController extends ChangeNotifier {
  static const String mockAccountPasscode = '1234';

  String selectedFilter = 'All';
  bool lockedVaultUnlocked = false;
  ChatBackupFrequency backupFrequency = ChatBackupFrequency.weekly;
  bool backupEnabled = true;
  bool strangersCanMessage = true;
  bool strangersCanMentionInVibes = true;

  final List<String> filters = const [
    'All',
    'Unread',
    'Online',
    'Room Invites',
    'Official',
    'Strangers',
    'Blocked',
  ];

  List<InboxConversation> _conversations = List<InboxConversation>.from(
    InboxMockData.conversations,
  );

  final List<InboxReportTask> _reportTasks = <InboxReportTask>[];

  List<InboxConversation> get conversations => List.unmodifiable(_conversations);
  List<InboxReportTask> get reportTasks => List.unmodifiable(_reportTasks);
  int get pendingReportTaskCount => _reportTasks.where((task) => task.isPending).length;

  List<InboxConversation> get unlockedConversations {
    return _sortedConversations(_conversations.where((conversation) => !conversation.isLockedByBackend).toList());
  }

  List<InboxConversation> get lockedConversations {
    return _sortedConversations(_conversations.where((conversation) => conversation.isLockedByBackend).toList());
  }

  int get lockedCount => lockedConversations.length;

  int get unreadCount {
    return _conversations.fold<int>(0, (sum, chat) => sum + chat.unreadCount);
  }

  List<InboxConversation> get visibleConversations {
    final base = unlockedConversations.where((chat) => !chat.isArchived).toList();

    switch (selectedFilter) {
      case 'Unread':
        return base.where((chat) => chat.unreadCount > 0).toList();
      case 'Online':
        return base.where((chat) => chat.isOnline).toList();
      case 'Room Invites':
        return base.where((chat) => chat.type == InboxConversationType.roomInvite).toList();
      case 'Official':
        return base.where((chat) => chat.type == InboxConversationType.official).toList();
      case 'Strangers':
        return base.where((chat) => chat.type == InboxConversationType.stranger).toList();
      case 'Blocked':
        return base.where((chat) => chat.isBlocked).toList();
      default:
        return base;
    }
  }

  List<InboxConversation> _sortedConversations(List<InboxConversation> items) {
    return [...items]..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return 0;
      });
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
      final title = conversation.title.toLowerCase();
      final subtitle = conversation.subtitle.toLowerCase();
      final roomName = conversation.currentRoomName?.toLowerCase() ?? '';

      final chatMatches = title.contains(normalizedQuery) ||
          subtitle.contains(normalizedQuery) ||
          roomName.contains(normalizedQuery);

      if (chatMatches) {
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
        if (!message.text.toLowerCase().contains(normalizedQuery)) continue;

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

    return results;
  }

  bool validatePasscode(String value) {
    return value.trim() == mockAccountPasscode;
  }

  void unlockLockedVault() {
    lockedVaultUnlocked = true;
    notifyListeners();
  }

  void lockLockedVault() {
    lockedVaultUnlocked = false;
    notifyListeners();
  }

  void selectFilter(String filter) {
    selectedFilter = filter;
    notifyListeners();
  }

  void setBackupEnabled(bool value) {
    backupEnabled = value;
    notifyListeners();
  }

  void setBackupFrequency(ChatBackupFrequency frequency) {
    backupFrequency = frequency;
    notifyListeners();
  }

  void setStrangersCanMessage(bool value) {
    strangersCanMessage = value;
    notifyListeners();
  }

  void setStrangersCanMentionInVibes(bool value) {
    strangersCanMentionInVibes = value;
    notifyListeners();
  }

  void toggleBackendLock(InboxConversation conversation) {
    if (conversation.isOfficial) return;
    _replaceConversation(conversation.id, (chat) => chat.copyWith(isLockedByBackend: !chat.isLockedByBackend));
  }

  void toggleBlock(InboxConversation conversation) {
    if (conversation.isOfficial) return;
    _replaceConversation(conversation.id, (chat) => chat.copyWith(isBlocked: !chat.isBlocked));
  }

  void toggleMute(InboxConversation conversation) {
    if (conversation.isOfficial) return;
    _replaceConversation(conversation.id, (chat) => chat.copyWith(isMuted: !chat.isMuted));
  }

  void togglePin(InboxConversation conversation) {
    _replaceConversation(conversation.id, (chat) => chat.copyWith(isPinned: !chat.isPinned));
  }

  void toggleArchive(InboxConversation conversation) {
    if (conversation.isOfficial) return;
    _replaceConversation(conversation.id, (chat) => chat.copyWith(isArchived: !chat.isArchived));
  }

  void sendTextMessage({
    required String conversationId,
    required String text,
    String? replyToText,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final message = InboxMessage(
      id: 'local_${DateTime.now().microsecondsSinceEpoch}',
      sender: 'You',
      text: trimmed,
      time: 'Now',
      isMine: true,
      status: InboxMessageStatus.read,
      replyToText: replyToText,
    );

    _appendMessage(conversationId, message);
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
      InboxMessageType.contact => '👤 Shared contact',
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

  InboxReportTask submitConversationReport({
    required InboxConversation conversation,
    required String reason,
  }) {
    final snapshot = conversation.messages.length <= 30
        ? conversation.messages
        : conversation.messages.sublist(conversation.messages.length - 30);

    final task = InboxReportTask(
      id: 'report_${DateTime.now().microsecondsSinceEpoch}',
      reportedConversationId: conversation.id,
      reportedUserName: conversation.title,
      reporterName: 'You',
      reason: reason.trim().isEmpty ? 'Unsafe or abusive conversation' : reason.trim(),
      snapshot: List<InboxMessage>.unmodifiable(snapshot),
      createdAtLabel: 'Now',
      status: InboxReportStatus.pendingCsReview,
    );

    _reportTasks.insert(0, task);
    _sendTeamSystemMessage(
      'Report submitted. CS will review the conversation snapshot and escalate if action is needed.',
    );
    notifyListeners();
    return task;
  }

  void rejectReportTask(InboxReportTask task) {
    _replaceReportTask(
      task.id,
      task.copyWith(
        status: InboxReportStatus.rejectedByCs,
        csNote: 'CS reviewed the snapshot and did not find enough evidence for punishment.',
      ),
    );
    _sendTeamSystemMessage('Report failed. CS reviewed your report about ${task.reportedUserName}, but there was not enough evidence to punish the user.');
  }

  void acceptReportTask(InboxReportTask task) {
    _replaceReportTask(
      task.id,
      task.copyWith(
        status: InboxReportStatus.acceptedEscalated,
        csNote: 'CS accepted the report and sent it to Monitor team for punishment action.',
        monitorAction: 'Pending Monitor action',
      ),
    );
    _sendTeamSystemMessage('Report successful. ${task.reportedUserName} has been sent to Monitor team for punishment review.');
  }

  void applyMonitorAction(InboxReportTask task, String actionLabel) {
    _replaceReportTask(
      task.id,
      task.copyWith(
        status: InboxReportStatus.monitorActionTaken,
        monitorAction: actionLabel,
      ),
    );
    _sendTeamSystemMessage('Report successful. ${task.reportedUserName} has been punished by Monitor team: $actionLabel.');
  }

  void _replaceReportTask(String taskId, InboxReportTask replacement) {
    for (var index = 0; index < _reportTasks.length; index++) {
      if (_reportTasks[index].id != taskId) continue;
      _reportTasks[index] = replacement;
      notifyListeners();
      return;
    }
  }

  void _sendTeamSystemMessage(String text) {
    final team = conversationById('team_official');
    if (team == null) return;
    _appendMessage(
      team.id,
      InboxMessage(
        id: 'system_${DateTime.now().microsecondsSinceEpoch}',
        sender: 'Vibe Match Team',
        text: text,
        time: 'Now',
        isMine: false,
        type: InboxMessageType.system,
      ),
    );
  }

  void setReaction({
    required String conversationId,
    required InboxMessage message,
    required String reaction,
  }) {
    _updateMessage(
      conversationId: conversationId,
      message: message,
      mapper: (item) => item.copyWith(reaction: reaction),
    );
  }

  void toggleStarMessage({
    required String conversationId,
    required InboxMessage message,
  }) {
    _updateMessage(
      conversationId: conversationId,
      message: message,
      mapper: (item) => item.copyWith(isStarred: !item.isStarred),
    );
  }

  void deleteMessage({
    required String conversationId,
    required InboxMessage message,
  }) {
    _replaceConversation(conversationId, (chat) {
      final updated = chat.messages.where((item) => !_sameMessage(item, message)).toList();
      return chat.copyWith(
        messages: updated,
        subtitle: updated.isEmpty ? 'No messages yet' : updated.last.text,
      );
    });
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

  void _appendMessage(String conversationId, InboxMessage message) {
    _replaceConversation(conversationId, (chat) {
      final updated = [...chat.messages, message];
      return chat.copyWith(
        messages: updated,
        subtitle: message.text,
        time: 'Now',
        unreadCount: 0,
      );
    });
  }

  void _updateMessage({
    required String conversationId,
    required InboxMessage message,
    required InboxMessage Function(InboxMessage item) mapper,
  }) {
    _replaceConversation(conversationId, (chat) {
      final updated = chat.messages.map((item) {
        if (!_sameMessage(item, message)) return item;
        return mapper(item);
      }).toList();
      return chat.copyWith(messages: updated);
    });
  }

  void _replaceConversation(
    String conversationId,
    InboxConversation Function(InboxConversation chat) mapper,
  ) {
    _conversations = _conversations.map((chat) {
      if (chat.id != conversationId) return chat;
      return mapper(chat);
    }).toList();

    notifyListeners();
  }

  bool _sameMessage(InboxMessage a, InboxMessage b) {
    if (a.id != null && b.id != null) return a.id == b.id;
    return a.sender == b.sender && a.text == b.text && a.time == b.time && a.isMine == b.isMine;
  }
}
