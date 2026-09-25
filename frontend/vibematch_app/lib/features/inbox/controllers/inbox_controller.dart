import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/inbox_api_service.dart';
import '../data/inbox_backup_api_service.dart';
import '../data/inbox_message_tools_api_service.dart';
import '../data/inbox_preferences_api_service.dart';
import '../../profile/data/love_bond_realtime_service.dart';
import '../data/inbox_socket_service.dart';
import 'inbox_call_controller.dart';
import '../models/inbox_models.dart';

const Object _inboxUnset = Object();

class InboxState {
  const InboxState({
    this.selectedFilter = 'All',
    this.lockedVaultUnlocked = false,
    this.isLoading = false,
    this.errorMessage,
    this.lockStatus = const InboxLockStatus(isEnabled: false),
    this.backupStatus = const InboxBackupStatus(
      isEnabled: false,
      isAuthorized: false,
      provider: 'google_drive',
      frequency: ChatBackupFrequency.weekly,
      lastStatus: 'not_connected',
    ),
    this.lastBackupJob,
    this.lastRestoreJob,
    this.lastGoogleDriveAuthorizationUrl,
    this.lastSecurityCode,
    this.preferenceSettings = const InboxPreferenceSettings(
      strangersCanMessage: true,
      strangersCanMentionInVibes: true,
      readReceiptsEnabled: true,
      onlineVisibility: 'everyone',
      lastSeenVisibility: 'everyone',
      typingActivityVisibility: 'everyone',
      storyVisibility: 'friends',
      deviceUnlockEnabled: false,
      defaultChatTheme: 'pearl',
      defaultWallpaperKey: 'premium_pearl',
    ),
    this.activeConversationId,
    this.remoteActivityByConversationId = const <String, String>{},
    this.conversations = const <InboxConversation>[],
    this.conversationNextCursor,
    this.loadingMoreConversations = false,
    this.reportTasks = const <InboxReportTask>[],
  });

  final String selectedFilter;
  final bool lockedVaultUnlocked;
  final bool isLoading;
  final String? errorMessage;
  final InboxLockStatus lockStatus;
  final InboxBackupStatus backupStatus;
  final InboxBackupJob? lastBackupJob;
  final InboxBackupJob? lastRestoreJob;
  final String? lastGoogleDriveAuthorizationUrl;
  final String? lastSecurityCode;
  final InboxPreferenceSettings preferenceSettings;
  final String? activeConversationId;
  final Map<String, String> remoteActivityByConversationId;
  final List<InboxConversation> conversations;
  final String? conversationNextCursor;
  final bool loadingMoreConversations;
  final List<InboxReportTask> reportTasks;

  InboxState copyWith({
    String? selectedFilter,
    bool? lockedVaultUnlocked,
    bool? isLoading,
    Object? errorMessage = _inboxUnset,
    InboxLockStatus? lockStatus,
    InboxBackupStatus? backupStatus,
    Object? lastBackupJob = _inboxUnset,
    Object? lastRestoreJob = _inboxUnset,
    Object? lastGoogleDriveAuthorizationUrl = _inboxUnset,
    Object? lastSecurityCode = _inboxUnset,
    InboxPreferenceSettings? preferenceSettings,
    Object? activeConversationId = _inboxUnset,
    Map<String, String>? remoteActivityByConversationId,
    List<InboxConversation>? conversations,
    Object? conversationNextCursor = _inboxUnset,
    bool? loadingMoreConversations,
    List<InboxReportTask>? reportTasks,
  }) {
    return InboxState(
      selectedFilter: selectedFilter ?? this.selectedFilter,
      lockedVaultUnlocked:
          lockedVaultUnlocked ?? this.lockedVaultUnlocked,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: identical(errorMessage, _inboxUnset)
          ? this.errorMessage
          : errorMessage as String?,
      lockStatus: lockStatus ?? this.lockStatus,
      backupStatus: backupStatus ?? this.backupStatus,
      lastBackupJob: identical(lastBackupJob, _inboxUnset)
          ? this.lastBackupJob
          : lastBackupJob as InboxBackupJob?,
      lastRestoreJob: identical(lastRestoreJob, _inboxUnset)
          ? this.lastRestoreJob
          : lastRestoreJob as InboxBackupJob?,
      lastGoogleDriveAuthorizationUrl:
          identical(lastGoogleDriveAuthorizationUrl, _inboxUnset)
          ? this.lastGoogleDriveAuthorizationUrl
          : lastGoogleDriveAuthorizationUrl as String?,
      lastSecurityCode: identical(lastSecurityCode, _inboxUnset)
          ? this.lastSecurityCode
          : lastSecurityCode as String?,
      preferenceSettings: preferenceSettings ?? this.preferenceSettings,
      activeConversationId: identical(activeConversationId, _inboxUnset)
          ? this.activeConversationId
          : activeConversationId as String?,
      remoteActivityByConversationId:
          Map<String, String>.unmodifiable(
            remoteActivityByConversationId ??
                this.remoteActivityByConversationId,
          ),
      conversations: List<InboxConversation>.unmodifiable(
        conversations ?? this.conversations,
      ),
      conversationNextCursor:
          identical(conversationNextCursor, _inboxUnset)
          ? this.conversationNextCursor
          : conversationNextCursor as String?,
      loadingMoreConversations:
          loadingMoreConversations ?? this.loadingMoreConversations,
      reportTasks: List<InboxReportTask>.unmodifiable(
        reportTasks ?? this.reportTasks,
      ),
    );
  }
}

class InboxController extends AutoDisposeNotifier<InboxState> {
  late final InboxApiService _apiService;
  late final InboxBackupApiService _backupApiService;
  late final InboxPreferencesApiService _preferencesApiService;
  late final InboxMessageToolsApiService _messageToolsApiService;
  late final InboxSocketService _socketService;

  @override
  InboxState build() {
    _apiService = InboxApiService();
    _backupApiService = const InboxBackupApiService();
    _preferencesApiService = const InboxPreferencesApiService();
    _messageToolsApiService = InboxMessageToolsApiService();
    _socketService = InboxSocketService();
    ref.onDispose(_socketService.disconnect);
    return const InboxState();
  }

  InboxCallController get callController =>
      ref.read(inboxCallControllerProvider.notifier);

  String get selectedFilter => state.selectedFilter;
  set selectedFilter(String value) =>
      state = state.copyWith(selectedFilter: value);
  bool get lockedVaultUnlocked => state.lockedVaultUnlocked;
  set lockedVaultUnlocked(bool value) =>
      state = state.copyWith(lockedVaultUnlocked: value);
  bool get isLoading => state.isLoading;
  set isLoading(bool value) => state = state.copyWith(isLoading: value);
  String? get errorMessage => state.errorMessage;
  set errorMessage(String? value) =>
      state = state.copyWith(errorMessage: value);
  InboxLockStatus get lockStatus => state.lockStatus;
  set lockStatus(InboxLockStatus value) =>
      state = state.copyWith(lockStatus: value);
  InboxBackupStatus get backupStatus => state.backupStatus;
  set backupStatus(InboxBackupStatus value) =>
      state = state.copyWith(backupStatus: value);
  InboxBackupJob? get lastBackupJob => state.lastBackupJob;
  set lastBackupJob(InboxBackupJob? value) =>
      state = state.copyWith(lastBackupJob: value);
  InboxBackupJob? get lastRestoreJob => state.lastRestoreJob;
  set lastRestoreJob(InboxBackupJob? value) =>
      state = state.copyWith(lastRestoreJob: value);
  String? get lastGoogleDriveAuthorizationUrl =>
      state.lastGoogleDriveAuthorizationUrl;
  set lastGoogleDriveAuthorizationUrl(String? value) =>
      state = state.copyWith(lastGoogleDriveAuthorizationUrl: value);
  String? get lastSecurityCode => state.lastSecurityCode;
  set lastSecurityCode(String? value) =>
      state = state.copyWith(lastSecurityCode: value);
  InboxPreferenceSettings get preferenceSettings =>
      state.preferenceSettings;
  set preferenceSettings(InboxPreferenceSettings value) =>
      state = state.copyWith(preferenceSettings: value);

  bool get strangersCanMessage =>
      state.preferenceSettings.strangersCanMessage;
  bool get strangersCanMentionInVibes =>
      state.preferenceSettings.strangersCanMentionInVibes;
  bool get readReceiptsEnabled =>
      state.preferenceSettings.readReceiptsEnabled;
  bool get deviceUnlockEnabled =>
      state.preferenceSettings.deviceUnlockEnabled;
  String get onlineVisibility =>
      state.preferenceSettings.onlineVisibility;
  String get lastSeenVisibility =>
      state.preferenceSettings.lastSeenVisibility;
  String get typingActivityVisibility =>
      state.preferenceSettings.typingActivityVisibility;
  String get storyVisibility =>
      state.preferenceSettings.storyVisibility;
  String get defaultChatTheme =>
      state.preferenceSettings.defaultChatTheme;
  String get defaultWallpaperKey =>
      state.preferenceSettings.defaultWallpaperKey;
  String? get defaultWallpaperUrl =>
      state.preferenceSettings.defaultWallpaperUrl;

  String? get _activeConversationId => state.activeConversationId;
  set _activeConversationId(String? value) =>
      state = state.copyWith(activeConversationId: value);

  List<InboxConversation> get _conversations => state.conversations;
  set _conversations(List<InboxConversation> value) =>
      state = state.copyWith(conversations: value);
  String? get _conversationNextCursor => state.conversationNextCursor;
  set _conversationNextCursor(String? value) =>
      state = state.copyWith(conversationNextCursor: value);
  bool get _loadingMoreConversations => state.loadingMoreConversations;
  set _loadingMoreConversations(bool value) =>
      state = state.copyWith(loadingMoreConversations: value);
  List<InboxReportTask> get _reportTasks => state.reportTasks;
  set _reportTasks(List<InboxReportTask> value) =>
      state = state.copyWith(reportTasks: value);

  String? remoteActivityForConversation(String conversationId) {
    final value = state.remoteActivityByConversationId[conversationId];
    if (value == null || value == 'idle') return null;
    return value;
  }

  bool get backupEnabled => state.backupStatus.isEnabled;
  ChatBackupFrequency get backupFrequency => state.backupStatus.frequency;

  List<InboxConversation> get conversations => state.conversations;
  bool get hasMoreConversations => state.conversationNextCursor != null;
  bool get isLoadingMoreConversations => state.loadingMoreConversations;
  List<InboxReportTask> get reportTasks => state.reportTasks;
  int get pendingReportTaskCount =>
      state.reportTasks.where((task) => task.isPending).length;
  int get lockedCount => lockedConversations.length;
  int get unreadCount => state.conversations.fold<int>(
    0,
    (sum, chat) => sum + chat.unreadCount,
  );

  List<InboxConversation> get unlockedConversations =>
      _sortedConversations(
        state.conversations
            .where((chat) => !chat.isLockedByBackend)
            .toList(),
      );

  List<InboxConversation> get lockedConversations =>
      _sortedConversations(
        state.conversations
            .where((chat) => chat.isLockedByBackend)
            .toList(),
      );

  final List<String> filters = const [
    'All',
    'Friends',
    'Stranger Messages',
    'Unread',
    'Calls',
  ];

  List<InboxConversation> get visibleConversations {
    final base = unlockedConversations
        .where((chat) => !chat.isArchived)
        .toList();
    switch (selectedFilter) {
      case 'Friends':
        return base.where((chat) => chat.isMutualFollowChat).toList();
      case 'Stranger Messages':
      case 'Strangers':
        return base
            .where((chat) => chat.type == InboxConversationType.stranger)
            .toList();
      case 'Unread':
        return base.where((chat) => chat.unreadCount > 0).toList();
      case 'Calls':
        return base
            .where(
              (chat) =>
                  chat.isCallLog ||
                  chat.messages.any(
                    (message) => message.type == InboxMessageType.callLog,
                  ),
            )
            .toList();
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
      case 'Blocked':
        return base.where((chat) => chat.isBlocked).toList();
      default:
        return base;
    }
  }

  void _safeNotify() {}

  Future<void> ensureRealtimeConnected() {
    return _socketService.connect(onEvent: _handleRealtimeEvent);
  }

  Future<void> loadFromBackend() async {
    isLoading = true;
    errorMessage = null;
    _safeNotify();
    try {
      lockStatus = await _apiService.loadLockStatus();
      backupStatus = await _backupApiService.loadStatus();
      preferenceSettings = await _preferencesApiService.loadPreferences();
      await _apiService.bootstrapInbox();
      final conversationPage = await _apiService.loadConversationPage();
      _conversations = conversationPage.items;
      _conversationNextCursor = conversationPage.nextCursor;
      _reportTasks = await _apiService.loadReportTasks();
      await _socketService.connect(onEvent: _handleRealtimeEvent);
    } catch (error) {
      errorMessage = error.toString();
      _conversations = <InboxConversation>[];
    } finally {
      isLoading = false;
      _safeNotify();
    }
  }

  Future<void> loadMoreConversations() async {
    final cursor = _conversationNextCursor;
    if (cursor == null || _loadingMoreConversations || isLoading) return;
    _loadingMoreConversations = true;
    _safeNotify();
    try {
      final page = await _apiService.loadConversationPage(cursor: cursor);
      final existingIds = _conversations.map((item) => item.id).toSet();
      _conversations = [
        ..._conversations,
        ...page.items.where((item) => existingIds.add(item.id)),
      ];
      _conversationNextCursor = page.nextCursor;
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      _loadingMoreConversations = false;
      _safeNotify();
    }
  }

  Future<void> _savePreferences(InboxPreferenceSettings settings) async {
    final previous = preferenceSettings;
    preferenceSettings = settings;
    _safeNotify();
    try {
      preferenceSettings = await _preferencesApiService.updatePreferences(
        settings,
      );
      _safeNotify();
    } catch (error) {
      preferenceSettings = previous;
      errorMessage = error.toString();
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
    lastSecurityCode = await _apiService.startLockSetup(
      mobileNumber: mobileNumber,
    );
    _safeNotify();
    return lastSecurityCode;
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
    lastSecurityCode = await _apiService.startLockRecovery(
      mobileNumber: mobileNumber,
    );
    lockStatus = lockStatus.copyWith(recoveryRequested: true);
    _safeNotify();
    return lastSecurityCode;
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
    if (_handleCallRealtimeEvent(event)) return;

    final name = event['event']?.toString();
    switch (name) {
      case 'inbox_message_created':
        final conversationId = event['conversation_id']?.toString();
        final rawMessage = event['message'];
        if (conversationId != null && rawMessage is Map<String, dynamic>) {
          final message = _apiService.messageFromJson(rawMessage);
          _appendOrReconcileMessage(conversationId, message);
          if (!message.isMine && _activeConversationId == conversationId) {
            Future<void>.microtask(
              () => openConversationFromBackend(conversationId),
            );
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
      case 'inbox_secret_drift_cleared':
        final conversationId = event['conversation_id']?.toString();
        if (conversationId != null) {
          final activity = Map<String, String>.of(
            state.remoteActivityByConversationId,
          )..remove(conversationId);
          state = state.copyWith(remoteActivityByConversationId: activity);
          loadFromBackend();
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
        if (rawTask is Map<String, dynamic>) {
          _upsertReportTask(_apiService.reportFromJson(rawTask));
        }
        break;
      default:
        break;
    }
  }

  bool _handleCallRealtimeEvent(Map<String, dynamic> event) {
    final name = event['event']?.toString();
    const callEvents = <String>{
      'inbox_call_started',
      'inbox_call_accepted',
      'inbox_call_declined',
      'inbox_call_ended',
      'inbox_call_missed',
    };
    if (!callEvents.contains(name)) return false;

    var conversationId = event['conversation_id']?.toString();
    final rawCall = event['call'];
    if ((conversationId == null ||
            conversationId.isEmpty ||
            conversationId == 'null') &&
        rawCall is Map<String, dynamic>) {
      conversationId = rawCall['conversation_id']?.toString();
    }
    if (conversationId == null ||
        conversationId.isEmpty ||
        conversationId == 'null')
      return true;

    final conversation = conversationById(conversationId);
    if (conversation == null) return true;

    callController.handleRealtimeEvent(
      event: event,
      conversation: conversation,
    );
    return true;
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
    final next = Map<String, String>.of(
      state.remoteActivityByConversationId,
    );
    if (activity == 'idle') {
      next.remove(conversationId);
    } else {
      next[conversationId] = activity;
      Future<void>.delayed(const Duration(seconds: 5), () {
        if (state.remoteActivityByConversationId[conversationId] == activity) {
          final expired = Map<String, String>.of(
            state.remoteActivityByConversationId,
          )..remove(conversationId);
          state = state.copyWith(
            remoteActivityByConversationId: expired,
          );
        }
      });
    }
    state = state.copyWith(remoteActivityByConversationId: next);
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
      if (updated.secretDriftEnabled) {
        await _apiService.openSecretDriftSession(conversationId);
      }
      _upsertConversation(updated);
      markConversationRead(conversationId);
    } catch (error) {
      errorMessage = error.toString();
      _safeNotify();
    }
  }

  Future<int> loadOlderMessages(String conversationId) async {
    final conversation = conversationById(conversationId);
    final cursor = conversation?.messagesNextCursor;
    if (conversation == null ||
        !conversation.hasOlderMessages ||
        cursor == null ||
        cursor.isEmpty) {
      return 0;
    }

    try {
      final page = await _apiService.loadOlderMessages(
        conversationId: conversationId,
        before: cursor,
      );
      final existingIds = conversation.messages
          .map((item) => item.id)
          .whereType<String>()
          .toSet();
      final older = page.messages
          .where((item) => item.id == null || existingIds.add(item.id!))
          .toList();
      _replaceConversation(
        conversationId,
        (chat) => chat.copyWith(
          messages: [...older, ...chat.messages],
          messagesNextCursor: page.nextCursor,
          clearMessagesNextCursor: page.nextCursor == null,
          hasOlderMessages: page.hasMore,
        ),
      );
      return older.length;
    } catch (error) {
      errorMessage = error.toString();
      _safeNotify();
      return 0;
    }
  }

  Future<void> toggleSecretDrift({
    required InboxConversation conversation,
  }) async {
    try {
      final updated = await _apiService.updateSecretDrift(
        conversationId: conversation.id,
        enabled: !conversation.secretDriftEnabled,
      );
      _upsertConversation(updated);
      _safeNotify();
    } catch (error) {
      errorMessage = error.toString();
      _safeNotify();
    }
  }

  Future<void> closeSecretDriftSession({
    required InboxConversation conversation,
  }) async {
    if (!conversation.secretDriftEnabled) return;
    try {
      await _apiService.closeSecretDriftSession(conversation.id);
    } catch (_) {
      // Best-effort close. Do not block page disposal/navigation.
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
    _savePreferences(preferenceSettings.copyWith(strangersCanMessage: value));
  }

  void setStrangersCanMentionInVibes(bool value) {
    _savePreferences(
      preferenceSettings.copyWith(strangersCanMentionInVibes: value),
    );
  }

  void setReadReceiptsEnabled(bool value) {
    _savePreferences(preferenceSettings.copyWith(readReceiptsEnabled: value));
  }

  void setDeviceUnlockEnabled(bool value) {
    _savePreferences(preferenceSettings.copyWith(deviceUnlockEnabled: value));
  }

  void setOnlineVisibility(String value) {
    _savePreferences(preferenceSettings.copyWith(onlineVisibility: value));
  }

  void setLastSeenVisibility(String value) {
    _savePreferences(preferenceSettings.copyWith(lastSeenVisibility: value));
  }

  void setTypingActivityVisibility(String value) {
    _savePreferences(
      preferenceSettings.copyWith(typingActivityVisibility: value),
    );
  }

  void setStoryVisibility(String value) {
    _savePreferences(preferenceSettings.copyWith(storyVisibility: value));
  }

  Future<void> updateConversationTheme({
    required InboxConversation conversation,
    required String chatTheme,
    required String wallpaperKey,
    String? wallpaperUrl,
  }) async {
    try {
      await _preferencesApiService.updateConversationTheme(
        conversationId: conversation.id,
        chatTheme: chatTheme,
        wallpaperKey: wallpaperKey,
        wallpaperUrl: wallpaperUrl,
      );
      await openConversationFromBackend(conversation.id);
    } catch (error) {
      errorMessage = error.toString();
      _safeNotify();
    }
  }

  Future<void> toggleBackendLock(InboxConversation conversation) =>
      _updateState(conversation, isLocked: !conversation.isLockedByBackend);
  Future<void> toggleBlock(InboxConversation conversation) =>
      _updateState(conversation, isBlocked: !conversation.isBlocked);
  Future<void> toggleMute(InboxConversation conversation) =>
      _updateState(conversation, isMuted: !conversation.isMuted);
  Future<void> togglePin(InboxConversation conversation) =>
      _updateState(conversation, isPinned: !conversation.isPinned);
  Future<void> toggleArchive(InboxConversation conversation) =>
      _updateState(conversation, isArchived: !conversation.isArchived);

  Future<void> _updateState(
    InboxConversation conversation, {
    bool? isMuted,
    bool? isPinned,
    bool? isArchived,
    bool? isLocked,
    bool? isBlocked,
  }) async {
    if (conversation.isOfficial &&
        (isLocked != null || isBlocked != null || isMuted != null)) {
      return;
    }
    _replaceConversation(
      conversation.id,
      (chat) => chat.copyWith(
        isMuted: isMuted,
        isPinned: isPinned,
        isArchived: isArchived,
        isLockedByBackend: isLocked,
        isBlocked: isBlocked,
      ),
    );
    try {
      final updated = await _apiService.updateConversationState(
        conversationId: conversation.id,
        isMuted: isMuted,
        isPinned: isPinned,
        isArchived: isArchived,
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

    final retrying = message.copyWith(
      status: InboxMessageStatus.sending,
      time: 'Now',
    );

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

  void addGeneratedAttachment({
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
    _reportTasks = <InboxReportTask>[local, ..._reportTasks];
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

  Future<void> editTextMessage({
    required String conversationId,
    required InboxMessage message,
    required String text,
  }) async {
    if (message.id == null || !message.isMine) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final previous = message;
    _updateMessage(
      conversationId: conversationId,
      message: message,
      mapper: (item) => item.copyWith(text: trimmed),
    );
    try {
      final updated = await _messageToolsApiService.editTextMessage(
        conversationId: conversationId,
        messageId: message.id!,
        text: trimmed,
      );
      _updateMessage(
        conversationId: conversationId,
        message: message,
        mapper: (_) => updated,
      );
    } catch (error) {
      errorMessage = error.toString();
      _updateMessage(
        conversationId: conversationId,
        message: message.copyWith(text: trimmed),
        mapper: (_) => previous,
      );
    }
  }

  Future<void> deleteMessageForMe({
    required String conversationId,
    required InboxMessage message,
  }) async {
    if (message.id == null) return;
    _removeMessageById(conversationId, message.id!);
    try {
      await _messageToolsApiService.deleteForMe(
        conversationId: conversationId,
        messageId: message.id!,
      );
    } catch (error) {
      errorMessage = error.toString();
      _appendMessage(conversationId, message);
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
        .toList(growable: false);
  }

  void _setConversationUnread(String conversationId, int unreadCount) =>
      _replaceConversation(
        conversationId,
        (chat) => chat.copyWith(unreadCount: unreadCount),
      );
  void _upsertConversation(InboxConversation conversation) {
    final next = List<InboxConversation>.of(_conversations);
    final index = next.indexWhere((item) => item.id == conversation.id);
    if (index == -1) {
      next.insert(0, conversation);
    } else {
      next[index] = conversation;
    }
    _conversations = next;
  }

  void _replaceReportTask(String taskId, InboxReportTask replacement) {
    final next = List<InboxReportTask>.of(_reportTasks);
    for (var index = 0; index < next.length; index++) {
      if (next[index].id == taskId) {
        next[index] = replacement;
        _reportTasks = next;
        return;
      }
    }
  }

  void _upsertReportTask(InboxReportTask task) {
    final next = List<InboxReportTask>.of(_reportTasks);
    final index = next.indexWhere((item) => item.id == task.id);
    if (index == -1) {
      next.insert(0, task);
    } else {
      next[index] = task;
    }
    _reportTasks = next;
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
    if (!localId.startsWith('local_') && !localId.startsWith('doc_')) {
      return false;
    }
    if (!local.isMine || !remote.isMine) return false;
    return local.text.trim() == remote.text.trim() &&
        local.type == remote.type &&
        local.replyToText == remote.replyToText;
  }
}


final inboxControllerProvider =
    NotifierProvider.autoDispose<InboxController, InboxState>(
      InboxController.new,
    );
