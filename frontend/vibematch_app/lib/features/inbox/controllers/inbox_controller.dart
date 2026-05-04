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

  List<InboxConversation> get conversations => List.unmodifiable(_conversations);

  List<InboxConversation> get unlockedConversations {
    return _conversations.where((conversation) => !conversation.isLockedByBackend).toList();
  }

  List<InboxConversation> get lockedConversations {
    return _conversations.where((conversation) => conversation.isLockedByBackend).toList();
  }

  int get lockedCount => lockedConversations.length;

  int get unreadCount {
    return _conversations.fold<int>(0, (sum, chat) => sum + chat.unreadCount);
  }

  List<InboxConversation> get visibleConversations {
    final base = unlockedConversations;

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

    _conversations = _conversations.map((chat) {
      if (chat.id != conversation.id) return chat;
      return chat.copyWith(isLockedByBackend: !chat.isLockedByBackend);
    }).toList();

    notifyListeners();
  }

  void toggleBlock(InboxConversation conversation) {
    if (conversation.isOfficial) return;

    _conversations = _conversations.map((chat) {
      if (chat.id != conversation.id) return chat;
      return chat.copyWith(isBlocked: !chat.isBlocked);
    }).toList();

    notifyListeners();
  }
}
