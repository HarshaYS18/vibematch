import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../media/data/media_upload_api_service.dart';
import '../controllers/inbox_controller.dart';
import '../data/inbox_ai_api_service.dart';
import '../data/inbox_stories_api_service.dart';
import '../models/inbox_models.dart';
import 'pages/cs_report_tasks_page.dart';
import 'pages/inbox_chat_info_page.dart';
import 'pages/inbox_chat_page.dart';
import 'pages/inbox_search_page.dart';
import 'pages/inbox_settings_page.dart';
import 'pages/locked_chats_page.dart';
import 'pages/stranger_requests_page.dart';
import 'widgets/inbox_active_users_strip.dart';
import 'widgets/inbox_ai_helper_sheet.dart';
import 'widgets/inbox_chat_theme_picker_sheet.dart';
import 'widgets/inbox_conversation_list.dart';
import 'widgets/inbox_empty_state.dart';
import 'widgets/inbox_error_retry_state.dart';
import 'widgets/inbox_filter_bar.dart';
import 'widgets/inbox_header.dart';
import 'widgets/inbox_lock_flow_sheets.dart';
import 'widgets/inbox_motion.dart';
import 'widgets/inbox_passcode_sheet.dart';
import 'widgets/inbox_search_bar.dart';
import 'widgets/report_conversation_sheet.dart';

class InboxPage extends StatefulWidget {
  const InboxPage({
    super.key,
    this.openPagesInOverlay = false,
    this.controller,
    this.openConversationId,
    this.openConversationRequestNonce = 0,
    this.onActiveConversationChanged,
  });

  final bool openPagesInOverlay;
  final InboxController? controller;
  final String? openConversationId;
  final int openConversationRequestNonce;
  final ValueChanged<String?>? onActiveConversationChanged;

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  late final InboxController _controller;
  late final bool _ownsController;
  final InboxAiApiService _inboxAiApi = const InboxAiApiService();
  final MediaUploadApiService _mediaUploadApi = const MediaUploadApiService();
  final InboxStoriesApiService _storiesApi = const InboxStoriesApiService();
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  Widget? _panelOverlay;
  Future<List<InboxStoryItem>>? _storiesFuture;
  int _lastHandledOpenConversationRequestNonce = 0;
  String? _activeConversationId;
  bool _searchExpanded = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? InboxController();
    _ownsController = widget.controller == null;
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _searchController.addListener(_handleSearchChanged);
    _controller.addListener(_handleControllerChanged);
    _storiesFuture = _storiesApi.loadStories();
    if (_ownsController) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.loadFromBackend();
      });
    }
  }

  @override
  void didUpdateWidget(covariant InboxPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _handleRequestedConversationOpen();
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _controller.removeListener(_handleControllerChanged);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    final next = _searchController.text.trim();
    if (next == _searchQuery) return;
    setState(() => _searchQuery = next);
  }

  void _handleRequestedConversationOpen() {
    final conversationId = widget.openConversationId;
    if (conversationId == null || conversationId.isEmpty) return;
    if (widget.openConversationRequestNonce ==
        _lastHandledOpenConversationRequestNonce)
      return;
    _lastHandledOpenConversationRequestNonce =
        widget.openConversationRequestNonce;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final conversation = _controller.conversationById(conversationId);
      if (conversation == null) return;
      _openConversation(conversation);
    });
  }

  void _handleControllerChanged() {
    if (mounted) setState(() {});
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF251538),
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      );
  }

  void _refreshStories() {
    setState(() => _storiesFuture = _storiesApi.loadStories());
  }

  List<InboxConversation> get _strangerRequests => _controller.conversations
      .where((item) => item.isStranger && !item.isArchived)
      .toList();

  InboxConversation? get _strangerHub {
    final requests = _strangerRequests;
    if (requests.isEmpty) return null;
    final unread = requests.fold<int>(0, (sum, item) => sum + item.unreadCount);
    return InboxConversation(
      id: '__stranger_hub__',
      title: 'Stranger Messages',
      subtitle:
          '${requests.length} request${requests.length == 1 ? '' : 's'} waiting',
      time: requests.first.time,
      avatarText: 'SM',
      type: InboxConversationType.stranger,
      unreadCount: unread,
      isOnline: false,
      lastSeenText: 'Grouped message requests',
      colors: const [Color(0xFFFFB020), Color(0xFFFF5AAA)],
      messages: const <InboxMessage>[],
      isStrangerHub: true,
      requestCount: requests.length,
    );
  }

  List<InboxConversation> get _premiumVisibleConversations {
    final base = _controller.visibleConversations
        .where((item) => !item.isStranger)
        .toList();
    if (_controller.selectedFilter == 'Stranger Messages' ||
        _controller.selectedFilter == 'Strangers') {
      final hub = _strangerHub;
      return hub == null
          ? const <InboxConversation>[]
          : <InboxConversation>[hub];
    }
    if (_controller.selectedFilter == 'All') {
      final hub = _strangerHub;
      if (hub != null) base.insert(0, hub);
    }
    return base;
  }

  List<InboxConversation> get _filteredVisibleConversations {
    final conversations = _premiumVisibleConversations;
    final query = _searchQuery.toLowerCase();
    if (query.isEmpty) return conversations;
    return conversations.where((conversation) {
      if (conversation.title.toLowerCase().contains(query)) return true;
      if (conversation.listPreviewText.toLowerCase().contains(query)) {
        return true;
      }
      if (conversation.safePresenceText.toLowerCase().contains(query)) {
        return true;
      }
      return conversation.messages.any((message) {
        return message.text.toLowerCase().contains(query) ||
            (message.inviteRoomName?.toLowerCase().contains(query) ?? false);
      });
    }).toList();
  }

  Map<String, int> get _filterCounts {
    final unlocked = _controller.unlockedConversations
        .where((chat) => !chat.isArchived)
        .toList();
    return <String, int>{
      'All':
          unlocked.where((chat) => !chat.isStranger).length +
          (_strangerRequests.isEmpty ? 0 : 1),
      'Friends': unlocked.where((chat) => chat.isMutualFollowChat).length,
      'Stranger Messages': _strangerRequests.length,
      'Unread': unlocked.where((chat) => chat.unreadCount > 0).length,
      'Calls': unlocked
          .where(
            (chat) =>
                chat.isCallLog ||
                chat.messages.any(
                  (message) => message.type == InboxMessageType.callLog,
                ),
          )
          .length,
    };
  }

  void _toggleInlineSearch() {
    setState(() => _searchExpanded = !_searchExpanded);
    if (_searchExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocusNode.requestFocus();
      });
    } else {
      _searchFocusNode.unfocus();
      _searchController.clear();
    }
  }

  void _clearInlineSearch() {
    _searchController.clear();
    _searchFocusNode.requestFocus();
  }

  Future<void> _retryInboxLoad() async {
    await _controller.loadFromBackend();
    _refreshStories();
  }

  void _closePanelOverlay() {
    _clearActiveConversationForShell();
    if (!widget.openPagesInOverlay) {
      Navigator.pop(context);
      return;
    }
    setState(() => _panelOverlay = null);
  }

  void _handleBackInsideOverlay() {
    if (_panelOverlay != null) {
      _clearActiveConversationForShell();
      setState(() => _panelOverlay = null);
      return;
    }
    Navigator.pop(context);
  }

  void _openInboxSubPage(Widget page) {
    if (!widget.openPagesInOverlay) {
      Navigator.push(context, InboxMotion.slideRoute<void>(page));
      return;
    }
    setState(() => _panelOverlay = page);
  }

  void _openLockSetupSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => InboxLockSetupSheet(
        onStartOtp: _controller.startLockSetup,
        onVerifySetup: (mobile, otp, lock) => _controller.verifyLockSetup(
          mobileNumber: mobile,
          otp: otp,
          lockCode: lock,
        ),
      ),
    );
  }

  void _openLockRecoverySheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => InboxLockRecoverySheet(
        registeredMobile: _controller.lockStatus.mobileNumber,
        onStartRecovery: _controller.startLockRecovery,
        onVerifyRecovery: (mobile, otp, newLock) =>
            _controller.verifyLockRecovery(
              mobileNumber: mobile,
              otp: otp,
              newLockCode: newLock,
            ),
        onRequestCs: _controller.requestCsLockRecovery,
      ),
    );
  }

  Future<void> _showPasscodeGate({
    required String title,
    required String subtitle,
    required VoidCallback onUnlocked,
  }) async {
    if (!_controller.lockStatus.isEnabled) {
      _toast('Set up Inbox lock first.');
      _openLockSetupSheet();
      return;
    }
    if (widget.openPagesInOverlay) {
      setState(() {
        _panelOverlay = InboxPasscodeSheet(
          title: title,
          subtitle: subtitle,
          onValidate: _controller.verifyLock,
          onRecoverTap: _openLockRecoverySheet,
          onUnlocked: () {
            setState(() => _panelOverlay = null);
            onUnlocked();
          },
        );
      });
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => InboxPasscodeSheet(
        title: title,
        subtitle: subtitle,
        onValidate: _controller.verifyLock,
        onRecoverTap: _openLockRecoverySheet,
        onUnlocked: () {
          Navigator.pop(context);
          onUnlocked();
        },
      ),
    );
  }

  void _openConversation(InboxConversation conversation) {
    if (conversation.isStrangerHub) {
      _openStrangerRequests();
      return;
    }
    if (conversation.isLockedByBackend && !_controller.lockedVaultUnlocked) {
      _showPasscodeGate(
        title: 'Unlock chat',
        subtitle:
            'This chat is locked for your account. Enter your Inbox lock to open it.',
        onUnlocked: () => _openChat(conversation),
      );
      return;
    }
    _openChat(conversation);
  }

  void _openChat(InboxConversation conversation) {
    _activeConversationId = conversation.id;
    widget.onActiveConversationChanged?.call(conversation.id);
    final page = InboxChatPage(
      conversation: conversation,
      controller: _controller,
      onMoreTap: () => _showChatOptions(conversation),
      onBackTap: _closePanelOverlay,
    );
    if (!widget.openPagesInOverlay) {
      Navigator.push(
        context,
        InboxMotion.slideRoute<void>(page),
      ).then((_) => _clearActiveConversationForShell());
      return;
    }
    _openInboxSubPage(page);
  }

  void _openChatInfo(InboxConversation conversation) {
    _closeChatOptions();
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (!mounted) return;
      _openInboxSubPage(
        InboxChatInfoPage(
          conversation: conversation,
          onBackTap: _closePanelOverlay,
          onSearchTap: _openSearch,
          onThemeTap: () => _openThemePicker(conversation),
        ),
      );
    });
  }

  Future<void> _openThemePicker(InboxConversation conversation) async {
    final latest =
        _controller.conversationById(conversation.id) ?? conversation;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => InboxChatThemePickerSheet(
        currentThemeKey: latest.chatTheme ?? _controller.defaultChatTheme,
        currentWallpaperKey:
            latest.wallpaperKey ?? _controller.defaultWallpaperKey,
        onSelected: (choice) async {
          Navigator.pop(context);
          await _controller.updateConversationTheme(
            conversation: latest,
            chatTheme: choice.key,
            wallpaperKey: choice.wallpaperKey,
            wallpaperUrl: choice.wallpaperUrl,
          );
          if (!mounted) return;
          _toast('Theme saved: ${choice.label}');
        },
      ),
    );
  }

  void _clearActiveConversationForShell() {
    if (_activeConversationId == null) return;
    _activeConversationId = null;
    widget.onActiveConversationChanged?.call(null);
  }

  void _openSearch() => _openInboxSubPage(
    InboxSearchPage(
      controller: _controller,
      onOpenConversation: _openConversation,
      onBackTap: _closePanelOverlay,
    ),
  );

  Future<void> _openInboxAiHelper() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InboxAiHelperSheet(
        onSearch: _inboxAiApi.search,
        onOpenResult: _openInboxAiResult,
      ),
    );
  }

  void _openInboxAiResult(InboxAiSearchResult result) {
    Navigator.pop(context);
    if (result.isLocked) {
      _toast('Unlock Inbox to open locked AI results.');
      _openLockedVault();
      return;
    }
    final conversation = _controller.conversationById(result.conversationId);
    if (conversation == null) {
      _toast('Matched ${result.title}; open id ${result.conversationId}.');
      return;
    }
    _openConversation(conversation);
  }

  void _openSettings() {
    _openInboxSubPage(
      InboxSettingsPage(
        lockStatus: _controller.lockStatus,
        backupStatus: _controller.backupStatus,
        strangersCanMessage: _controller.strangersCanMessage,
        strangersCanMentionInVibes: _controller.strangersCanMentionInVibes,
        onStartLockSetup: _controller.startLockSetup,
        onVerifyLockSetup: (mobile, otp, lock) => _controller.verifyLockSetup(
          mobileNumber: mobile,
          otp: otp,
          lockCode: lock,
        ),
        onChangeLock: (currentLock, newLock) => _controller.changeLock(
          currentLockCode: currentLock,
          newLockCode: newLock,
        ),
        onStartLockRecovery: _controller.startLockRecovery,
        onVerifyLockRecovery: (mobile, otp, newLock) =>
            _controller.verifyLockRecovery(
              mobileNumber: mobile,
              otp: otp,
              newLockCode: newLock,
            ),
        onRequestCsLockRecovery: _controller.requestCsLockRecovery,
        onStartGoogleDriveSetup: _controller.startGoogleDriveAuthorization,
        onConnectGoogleDrive: (email, code) => _controller.connectGoogleDrive(
          googleDriveEmail: email,
          setupCode: code,
        ),
        onBackupEnabledChanged: _controller.setBackupEnabled,
        onFrequencyChanged: _controller.setBackupFrequency,
        onStrangersCanMessageChanged: _controller.setStrangersCanMessage,
        onStrangersCanMentionInVibesChanged:
            _controller.setStrangersCanMentionInVibes,
        onBackupNow: _controller.runBackupNow,
        onRestoreTap: _controller.restoreLatestBackup,
        onBackTap: _closePanelOverlay,
      ),
    );
  }

  void _openLockedVault() {
    if (!_controller.lockStatus.isEnabled) {
      _toast('Set up Inbox lock first.');
      _openLockSetupSheet();
      return;
    }
    if (_controller.lockedVaultUnlocked) {
      _openLockedVaultPage();
      return;
    }
    _showPasscodeGate(
      title: 'Locked chats',
      subtitle: 'Enter your Inbox lock before viewing locked conversations.',
      onUnlocked: _openLockedVaultPage,
    );
  }

  Future<void> _handleInboxPullDown() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    _openLockedVault();
  }

  void _openLockedVaultPage() {
    _openInboxSubPage(
      LockedChatsPage(
        conversations: _controller.lockedConversations,
        onOpenConversation: _openConversation,
        onShowOptions: _showChatOptions,
        onBackTap: _closePanelOverlay,
      ),
    );
  }

  void _openStrangerRequests() {
    _openInboxSubPage(
      StrangerRequestsPage(
        requests: _strangerRequests,
        onOpenConversation: _openConversation,
        onShowOptions: _showChatOptions,
        onBackTap: _closePanelOverlay,
      ),
    );
  }

  void _openCsReportTasks() {
    _openInboxSubPage(
      CsReportTasksPage(controller: _controller, onBackTap: _closePanelOverlay),
    );
  }

  void _toggleConversationPin(InboxConversation conversation) {
    _controller.togglePin(conversation);
    _toast(conversation.isPinned ? 'Chat unpinned.' : 'Chat pinned.');
  }

  void _toggleConversationMute(InboxConversation conversation) {
    if (conversation.isOfficial) {
      _toast('Official chats stay active.');
      return;
    }
    _controller.toggleMute(conversation);
    _toast(conversation.isMuted ? 'Chat unmuted.' : 'Chat muted.');
  }

  void _closeChatOptions() {
    if (widget.openPagesInOverlay) {
      setState(() => _panelOverlay = null);
    } else {
      Navigator.pop(context);
    }
  }

  void _openReportSheet(InboxConversation conversation) {
    _closeChatOptions();
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (!mounted) return;
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ReportConversationSheet(
          conversation: conversation,
          onSubmit: (reason) {
            Navigator.pop(context);
            _controller.submitConversationReport(
              conversation: conversation,
              reason: reason,
            );
            _toast('Report sent to CS task list with conversation snapshot.');
          },
        ),
      );
    });
  }

  void _showChatOptions(InboxConversation conversation) {
    if (conversation.isStrangerHub) {
      _openStrangerRequests();
      return;
    }
    final sheet = _InboxChatOptionsSheet(
      conversation: conversation,
      onInfo: () => _openChatInfo(conversation),
      onToggleLock: () {
        if (!_controller.lockStatus.isEnabled &&
            !conversation.isLockedByBackend) {
          _closeChatOptions();
          _toast('Set up Inbox lock before locking chats.');
          _openLockSetupSheet();
          return;
        }
        _controller.toggleBackendLock(conversation);
        _closeChatOptions();
        _toast(
          conversation.isLockedByBackend ? 'Chat unlocked.' : 'Chat locked.',
        );
      },
      onToggleBlock: () {
        _controller.toggleBlock(conversation);
        _closeChatOptions();
        _toast(
          conversation.isBlocked ? 'Profile unblocked.' : 'Profile blocked.',
        );
      },
      onToggleMute: () {
        _controller.toggleMute(conversation);
        _closeChatOptions();
        _toast(conversation.isMuted ? 'Chat unmuted.' : 'Chat muted.');
      },
      onTogglePin: () {
        _controller.togglePin(conversation);
        _closeChatOptions();
        _toast(conversation.isPinned ? 'Chat unpinned.' : 'Chat pinned.');
      },
      onReport: () => _openReportSheet(conversation),
    );
    if (widget.openPagesInOverlay) {
      setState(
        () => _panelOverlay = Align(
          alignment: Alignment.bottomCenter,
          child: sheet,
        ),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => sheet,
    );
  }

  Future<void> _createStory() async {
    final result = await showModalBottomSheet<_StoryDraft>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) =>
          _CreateStorySheet(onUpload: _mediaUploadApi.uploadStoryMediaXFile),
    );
    if (result == null) return;
    try {
      await _storiesApi.createStory(
        mediaUrl: result.mediaUrl,
        mediaType: result.mediaType,
        caption: result.caption,
        visibility: result.visibility,
      );
      _toast('Story posted.');
      _refreshStories();
    } catch (error) {
      _toast(error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleConversations = _filteredVisibleConversations;
    final hasNetworkIssue =
        _controller.errorMessage != null && _controller.conversations.isEmpty;
    final page = Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFFAF7F1),
          floatingActionButton: FloatingActionButton(
            onPressed: _openSearch,
            backgroundColor: const Color(0xFF251538),
            foregroundColor: Colors.white,
            elevation: 6,
            shape: const CircleBorder(),
            child: const Icon(Icons.edit_rounded),
          ),
          body: SafeArea(
            child: RefreshIndicator(
              color: const Color(0xFF251538),
              displacement: 64,
              edgeOffset: 8,
              strokeWidth: 2.7,
              onRefresh: _handleInboxPullDown,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: InboxHeader(
                      unreadCount: _controller.unreadCount,
                      lockedCount: _controller.lockedCount,
                      requestCount: _strangerRequests.length,
                      reportTaskCount: _controller.pendingReportTaskCount,
                      totalCount: _controller.conversations.length,
                      isLoading: _controller.isLoading,
                      hasNetworkIssue: hasNetworkIssue,
                      onSearchTap: _toggleInlineSearch,
                      onSettingsTap: _openSettings,
                      onLockedTap: _openLockedVault,
                      onRequestsTap: _openStrangerRequests,
                      onReportsTap: _openCsReportTasks,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: InboxSearchBar(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      expanded: _searchExpanded,
                      onToggle: _toggleInlineSearch,
                      onClear: _clearInlineSearch,
                      onSubmitted: (_) {},
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
                      child: _InboxAiPrompt(onTap: _openInboxAiHelper),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: FutureBuilder<List<InboxStoryItem>>(
                      future: _storiesFuture,
                      builder: (context, snapshot) {
                        return InboxActiveUsersStrip(
                          conversations: _controller.conversations,
                          stories: snapshot.data ?? const <InboxStoryItem>[],
                          storiesLoading:
                              snapshot.connectionState ==
                              ConnectionState.waiting,
                          onCreateStory: _createStory,
                          onStoryTap: (story) async {
                            await _storiesApi.markViewed(story.id);
                            if (!mounted) return;
                            _toast(
                              '${story.ownerName}: ${story.caption ?? 'Story opened'}',
                            );
                            _refreshStories();
                          },
                          onConversationTap: _openConversation,
                        );
                      },
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: InboxFilterBar(
                      filters: _controller.filters,
                      selectedFilter: _controller.selectedFilter,
                      counts: _filterCounts,
                      onChanged: _controller.selectFilter,
                    ),
                  ),
                  if (_controller.isLoading &&
                      _controller.conversations.isEmpty)
                    const InboxConversationSkeletonList()
                  else if (hasNetworkIssue)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: InboxErrorRetryState(onRetry: _retryInboxLoad),
                    )
                  else if (visibleConversations.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: InboxEmptyState(
                        selectedFilter: _controller.selectedFilter,
                        hasSearchQuery: _searchQuery.isNotEmpty,
                        onClearSearch: _searchQuery.isNotEmpty
                            ? _clearInlineSearch
                            : null,
                      ),
                    )
                  else
                    InboxConversationList(
                      conversations: visibleConversations,
                      remoteActivityFor:
                          _controller.remoteActivityForConversation,
                      onOpenConversation: _openConversation,
                      onShowOptions: _showChatOptions,
                      onPin: _toggleConversationPin,
                      onMute: _toggleConversationMute,
                    ),
                  if (_controller.isLoading &&
                      _controller.conversations.isNotEmpty)
                    const SliverToBoxAdapter(child: _InboxRefreshingPill()),
                  const SliverToBoxAdapter(child: SizedBox(height: 104)),
                ],
              ),
            ),
          ),
        ),
        if (_panelOverlay != null)
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: InboxMotion.standard,
              child: Material(
                key: ValueKey<Widget>(_panelOverlay!),
                color: const Color(0x88000000),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _panelOverlay = null),
                      ),
                    ),
                    Positioned.fill(child: _panelOverlay!),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
    if (!widget.openPagesInOverlay) return page;
    return PopScope<void>(
      canPop: _panelOverlay == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackInsideOverlay();
      },
      child: page,
    );
  }
}

class _InboxRefreshingPill extends StatelessWidget {
  const _InboxRefreshingPill();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE5DDF1)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF12C7B7),
                ),
              ),
              SizedBox(width: 8),
              Text(
                'Refreshing Inbox',
                style: TextStyle(
                  color: Color(0xFF4A2A63),
                  fontSize: 11.5,
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

class _InboxAiPrompt extends StatelessWidget {
  const _InboxAiPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.96),
              const Color(0xFFFFF8EB).withValues(alpha: 0.86),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFEDE7F6)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF251538).withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFFC99A3B),
              size: 18,
            ),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'Ask Vibe Match to find a chat',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF5E4B6F),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_up_rounded,
              color: Color(0xFF9B8CA5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _InboxChatOptionsSheet extends StatelessWidget {
  const _InboxChatOptionsSheet({
    required this.conversation,
    required this.onInfo,
    required this.onToggleLock,
    required this.onToggleBlock,
    required this.onToggleMute,
    required this.onTogglePin,
    required this.onReport,
  });
  final InboxConversation conversation;
  final VoidCallback onInfo;
  final VoidCallback onToggleLock;
  final VoidCallback onToggleBlock;
  final VoidCallback onToggleMute;
  final VoidCallback onTogglePin;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        padding: EdgeInsets.fromLTRB(14, 8, 14, 10 + bottomPadding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D7DB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                conversation.title,
                style: const TextStyle(
                  color: Color(0xFF251538),
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              _OptionTile(
                icon: Icons.info_rounded,
                title: 'Chat info',
                onTap: onInfo,
              ),
              _OptionTile(
                icon: conversation.isPinned
                    ? Icons.push_pin_outlined
                    : Icons.push_pin_rounded,
                title: conversation.isPinned ? 'Unpin chat' : 'Pin chat',
                onTap: onTogglePin,
              ),
              _OptionTile(
                icon: conversation.isMuted
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                title: conversation.isMuted ? 'Unmute chat' : 'Mute chat',
                onTap: conversation.isOfficial ? null : onToggleMute,
              ),
              _OptionTile(
                icon: conversation.isLockedByBackend
                    ? Icons.lock_open_rounded
                    : Icons.lock_rounded,
                title: conversation.isLockedByBackend
                    ? 'Unlock chat'
                    : 'Lock chat',
                onTap: conversation.isOfficial ? null : onToggleLock,
              ),
              _OptionTile(
                icon: conversation.isBlocked
                    ? Icons.undo_rounded
                    : Icons.block_rounded,
                title: conversation.isBlocked
                    ? 'Unblock profile'
                    : 'Block profile',
                onTap: conversation.isOfficial ? null : onToggleBlock,
              ),
              _OptionTile(
                icon: Icons.report_rounded,
                title: 'Report profile',
                onTap: conversation.isOfficial ? null : onReport,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: disabled ? 0.45 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F5FF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF7C3AED), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF251538),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF9B8CA5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryDraft {
  const _StoryDraft({
    required this.mediaUrl,
    required this.mediaType,
    required this.visibility,
    this.caption,
  });
  final String mediaUrl;
  final String mediaType;
  final String visibility;
  final String? caption;
}

class _CreateStorySheet extends StatefulWidget {
  const _CreateStorySheet({required this.onUpload});

  final Future<MediaUploadResult> Function(XFile file) onUpload;

  @override
  State<_CreateStorySheet> createState() => _CreateStorySheetState();
}

class _CreateStorySheetState extends State<_CreateStorySheet> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _caption = TextEditingController();
  String _visibility = 'friends';
  XFile? _file;
  Uint8List? _previewBytes;
  String _mediaType = 'image';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source, {required bool video}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final picked = video
          ? await _picker.pickVideo(source: source)
          : await _picker.pickImage(source: source, imageQuality: 92);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        setState(() => _error = 'Selected media is empty.');
        return;
      }
      if (bytes.length > 20 * 1024 * 1024) {
        setState(() => _error = 'Story media must be 20 MB or smaller.');
        return;
      }
      setState(() {
        _file = picked;
        _previewBytes = video ? null : bytes;
        _mediaType = video ? 'video' : 'image';
      });
    } catch (error) {
      setState(() => _error = _friendlyUploadError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _post() async {
    final file = _file;
    if (file == null || _busy) {
      setState(() => _error = 'Choose a photo or video first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final uploaded = await widget.onUpload(file);
      final mediaUrl = uploaded.url.trim();
      if (mediaUrl.isEmpty)
        throw Exception('Upload completed without a media URL.');
      if (!mounted) return;
      Navigator.pop(
        context,
        _StoryDraft(
          mediaUrl: mediaUrl,
          mediaType: uploaded.mediaType == 'video' ? 'video' : _mediaType,
          visibility: _visibility,
          caption: _caption.text.trim().isEmpty ? null : _caption.text.trim(),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyUploadError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: EdgeInsets.fromLTRB(
          16,
          14,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Create story',
                    style: TextStyle(
                      color: Color(0xFF251538),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF5E4B6F),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 9 / 12,
              child: InkWell(
                onTap: _busy
                    ? null
                    : () => _pick(ImageSource.gallery, video: false),
                borderRadius: BorderRadius.circular(22),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(color: Color(0xFFF7F7F8)),
                    child: file == null
                        ? const _StoryMediaEmpty()
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              if (_mediaType == 'image' &&
                                  _previewBytes != null)
                                Image.memory(_previewBytes!, fit: BoxFit.cover)
                              else
                                _StoryVideoPreview(name: file.name),
                              Positioned(
                                left: 12,
                                bottom: 12,
                                child: _StoryMediaBadge(type: _mediaType),
                              ),
                              Positioned(
                                right: 12,
                                top: 12,
                                child: InkWell(
                                  onTap: _busy
                                      ? null
                                      : () => setState(() {
                                          _file = null;
                                          _previewBytes = null;
                                          _mediaType = 'image';
                                        }),
                                  borderRadius: BorderRadius.circular(999),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.48,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _StoryPickButton(
                    icon: Icons.photo_rounded,
                    label: 'Photo',
                    onTap: _busy
                        ? null
                        : () => _pick(ImageSource.gallery, video: false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StoryPickButton(
                    icon: Icons.play_circle_fill_rounded,
                    label: 'Video',
                    onTap: _busy
                        ? null
                        : () => _pick(ImageSource.gallery, video: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _caption,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Caption',
                border: OutlineInputBorder(),
              ),
            ),
            DropdownButtonFormField<String>(
              initialValue: _visibility,
              items: const [
                DropdownMenuItem(value: 'friends', child: Text('Friends')),
                DropdownMenuItem(value: 'everyone', child: Text('Everyone')),
                DropdownMenuItem(value: 'nobody', child: Text('Only me')),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _visibility = value ?? 'friends'),
              decoration: const InputDecoration(labelText: 'Privacy'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _post,
                child: Text(_busy ? 'Uploading...' : 'Post story'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _friendlyUploadError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    if (raw.contains('413'))
      return 'This file is too large. Choose media under 20 MB.';
    if (raw.contains('401') || raw.toLowerCase().contains('login'))
      return 'Session expired. Login again before posting.';
    if (raw.toLowerCase().contains('unsupported'))
      return 'Unsupported media type. Choose JPG, PNG, WEBP, GIF, MP4, WEBM, or MOV.';
    if (raw.toLowerCase().contains('failed to fetch') ||
        raw.toLowerCase().contains('xmlhttprequest'))
      return 'Upload failed. Check the backend connection and try again.';
    return raw.isEmpty ? 'Could not upload story. Please try again.' : raw;
  }
}

class _StoryMediaEmpty extends StatelessWidget {
  const _StoryMediaEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.add_photo_alternate_rounded,
            color: Color(0xFF3797F0),
            size: 42,
          ),
          SizedBox(height: 10),
          Text(
            'Choose photo or video',
            style: TextStyle(
              color: Color(0xFF111114),
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryVideoPreview extends StatelessWidget {
  const _StoryVideoPreview({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF111114), Color(0xFF25252A)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.play_circle_fill_rounded,
              color: Colors.white,
              size: 56,
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Text(
                name.trim().isEmpty ? 'Selected video' : name.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryMediaBadge extends StatelessWidget {
  const _StoryMediaBadge({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            type == 'video'
                ? Icons.play_circle_fill_rounded
                : Icons.photo_rounded,
            color: Colors.white,
            size: 15,
          ),
          const SizedBox(width: 6),
          Text(
            type == 'video' ? 'Video' : 'Photo',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryPickButton extends StatelessWidget {
  const _StoryPickButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF111114),
        side: const BorderSide(color: Color(0xFFEDEDEF)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
