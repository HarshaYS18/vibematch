import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/inbox_controller.dart';
import '../controllers/inbox_call_controller.dart';
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
import 'widgets/inbox_chat_theme_picker_sheet.dart';
import 'widgets/inbox_conversation_card.dart';
import 'widgets/inbox_ai_helper_sheet.dart';
import 'widgets/inbox_lock_flow_sheets.dart';
import 'widgets/inbox_passcode_sheet.dart';
import 'widgets/inbox_v3_locked_pull_reveal.dart';
import 'widgets/report_conversation_sheet.dart';

class InboxPage extends ConsumerStatefulWidget {
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
  ConsumerState<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends ConsumerState<InboxPage> {
  static const _bg = Color(0xFFFAFAFA);
  static const _ink = Color(0xFF111114);
  static const _muted = Color(0xFF71717A);
  static const _blue = Color(0xFF3797F0);

  InboxController get _controller =>
      widget.controller ?? ref.read(inboxControllerProvider.notifier);
  final InboxAiApiService _inboxAiApi = const InboxAiApiService();
  final InboxStoriesApiService _storiesApi = const InboxStoriesApiService();
  final ScrollController _scrollController = ScrollController();
  Widget? _panelOverlay;
  Future<List<InboxStoryItem>>? _storiesFuture;
  int _lastHandledOpenConversationRequestNonce = 0;
  String? _activeConversationId;
  double _lockedPullExtent = 0;
  bool _lockedPullOpening = false;

  @override
  void initState() {
    super.initState();
    _storiesFuture = _storiesApi.loadStories();
    if (widget.controller == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(inboxControllerProvider.notifier).loadFromBackend();
        }
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
    _scrollController.dispose();
    super.dispose();
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
      if (conversation != null) _openConversation(conversation);
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _ink,
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
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
      colors: const [Color(0xFFF59E0B), Color(0xFFF59E0B)],
      messages: const <InboxMessage>[],
      isStrangerHub: true,
      requestCount: requests.length,
    );
  }

  List<InboxConversation> get _visibleConversations {
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

  void _refreshStories() =>
      setState(() => _storiesFuture = _storiesApi.loadStories());

  void _clearActiveConversationForShell() {
    if (_activeConversationId == null) return;
    _activeConversationId = null;
    widget.onActiveConversationChanged?.call(null);
  }

  void _openInboxSubPage(Widget page) {
    if (!widget.openPagesInOverlay) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      return;
    }
    setState(() => _panelOverlay = page);
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
        onSearch: _searchInboxAi,
        onOpenResult: _openInboxAiResult,
      ),
    );
  }

  Future<InboxAiSearchResponse> _searchInboxAi(String query) async {
    return _inboxAiApi.search(query);
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

  void _openSettings() => _openInboxSubPage(
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
      subtitle: 'Enter your Inbox lock.',
      onUnlocked: _openLockedVaultPage,
    );
  }

  void _openLockedVaultPage() => _openInboxSubPage(
    LockedChatsPage(
      conversations: _controller.lockedConversations,
      onOpenConversation: _openConversation,
      onShowOptions: _showChatOptions,
      onBackTap: _closePanelOverlay,
    ),
  );

  void _openStrangerRequests() => _openInboxSubPage(
    StrangerRequestsPage(
      requests: _strangerRequests,
      onOpenConversation: _openConversation,
      onShowOptions: _showChatOptions,
      onBackTap: _closePanelOverlay,
    ),
  );

  void _openCsReportTasks() => _openInboxSubPage(
    CsReportTasksPage(controller: _controller, onBackTap: _closePanelOverlay),
  );

  void _openConversation(InboxConversation conversation) {
    if (conversation.isStrangerHub) {
      _openStrangerRequests();
      return;
    }
    if (conversation.isLockedByBackend && !_controller.lockedVaultUnlocked) {
      _showPasscodeGate(
        title: 'Unlock chat',
        subtitle: 'This chat is locked.',
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
        MaterialPageRoute(builder: (_) => page),
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
          if (mounted) _toast('Theme saved');
        },
      ),
    );
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
            _toast('Report sent.');
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
    final sheet = _InboxV3OptionsSheet(
      conversation: conversation,
      onInfo: () => _openChatInfo(conversation),
      onTogglePin: () {
        _controller.togglePin(conversation);
        _closeChatOptions();
      },
      onToggleMute: () {
        _controller.toggleMute(conversation);
        _closeChatOptions();
      },
      onToggleLock: () {
        if (!_controller.lockStatus.isEnabled &&
            !conversation.isLockedByBackend) {
          _closeChatOptions();
          _openLockSetupSheet();
          return;
        }
        _controller.toggleBackendLock(conversation);
        _closeChatOptions();
      },
      onToggleBlock: () {
        _controller.toggleBlock(conversation);
        _closeChatOptions();
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
      builder: (_) => const _CreateStorySheetV3(),
    );
    if (result == null) return;
    try {
      await _storiesApi.createStory(
        mediaUrl: result.mediaUrl,
        mediaType: result.mediaType,
        caption: result.caption,
        visibility: result.visibility,
      );
      _refreshStories();
    } catch (error) {
      _toast(error.toString());
    }
  }

  Future<void> _openStory(List<InboxStoryItem> stories, int index) async {
    final story = stories[index];
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 140),
        pageBuilder: (context, animation, child) => FadeTransition(
          opacity: animation,
          child: _StoryViewerPage(
            stories: stories,
            initialIndex: index,
            onViewed: (item) => _storiesApi.markViewed(item.id),
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (!story.isViewed) _refreshStories();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.pixels > 0 &&
        notification.metrics.extentAfter < 600 &&
        _controller.hasMoreConversations &&
        !_controller.isLoadingMoreConversations) {
      _controller.loadMoreConversations();
    }
    if (notification.metrics.pixels > 0) return false;
    if (notification is OverscrollNotification && notification.overscroll < 0) {
      setState(() {
        _lockedPullExtent =
            (_lockedPullExtent + (-notification.overscroll * 0.65)).clamp(
              0,
              92,
            );
      });
      return false;
    }
    if (notification is ScrollEndNotification) {
      final shouldOpen = _lockedPullExtent >= 72;
      setState(() => _lockedPullExtent = 0);
      if (shouldOpen && !_lockedPullOpening) {
        _lockedPullOpening = true;
        Future<void>.delayed(const Duration(milliseconds: 80), () {
          if (mounted) _openLockedVault();
          _lockedPullOpening = false;
        });
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(inboxControllerProvider);
    ref.watch(inboxCallControllerProvider);

    final visibleConversations = _visibleConversations;
    final page = Stack(
      children: [
        Scaffold(
          backgroundColor: _bg,
          body: SafeArea(
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScrollNotification,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: InboxV3LockedPullReveal(
                      extent: _lockedPullExtent,
                      lockedCount: _controller.lockedCount,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _InboxV3Header(
                      unreadCount: _controller.unreadCount,
                      lockedCount: _controller.lockedCount,
                      requestCount: _strangerRequests.length,
                      reportTaskCount: _controller.pendingReportTaskCount,
                      onSearchTap: _openSearch,
                      onSettingsTap: _openSettings,
                      onLockedTap: _openLockedVault,
                      onRequestsTap: _openStrangerRequests,
                      onReportsTap: _openCsReportTasks,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _InboxAiPromptV3(onTap: _openInboxAiHelper),
                  ),
                  SliverToBoxAdapter(
                    child: FutureBuilder<List<InboxStoryItem>>(
                      future: _storiesFuture,
                      builder: (context, snapshot) {
                        final stories =
                            snapshot.data ?? const <InboxStoryItem>[];
                        return _StoryRailV3(
                          stories: stories,
                          onCreateStory: _createStory,
                          onStoryTap: (index) => _openStory(stories, index),
                        );
                      },
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _FilterTabsV3(
                      filters: _controller.filters,
                      selectedFilter: _controller.selectedFilter,
                      onChanged: _controller.selectFilter,
                      lockedCount: _controller.lockedCount,
                      onLockedTap: _openLockedVault,
                    ),
                  ),
                  if (_controller.isLoading && visibleConversations.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _InboxLoadingSkeletonV3(),
                    )
                  else if (visibleConversations.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyInboxStateV3(onSearchTap: _openSearch),
                    )
                  else
                    SliverList.builder(
                      itemCount: visibleConversations.length,
                      itemBuilder: (context, index) {
                        final conversation = visibleConversations[index];
                        return InboxConversationCard(
                          conversation: conversation,
                          onTap: () => _openConversation(conversation),
                          onLongPress: () => _showChatOptions(conversation),
                        );
                      },
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 28)),
                ],
              ),
            ),
          ),
        ),
        if (_panelOverlay != null)
          Positioned.fill(
            child: Material(
              color: Colors.black.withValues(alpha: 0.52),
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

class _InboxV3Header extends StatelessWidget {
  const _InboxV3Header({
    required this.unreadCount,
    required this.lockedCount,
    required this.requestCount,
    required this.reportTaskCount,
    required this.onSearchTap,
    required this.onSettingsTap,
    required this.onLockedTap,
    required this.onRequestsTap,
    required this.onReportsTap,
  });

  final int unreadCount;
  final int lockedCount;
  final int requestCount;
  final int reportTaskCount;
  final VoidCallback onSearchTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onLockedTap;
  final VoidCallback onRequestsTap;
  final VoidCallback onReportsTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFF6FBFA)],
        ),
        border: Border(bottom: BorderSide(color: Color(0xFFE7ECEA))),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Expanded(
                  child: Text(
                    'Inbox',
                    style: TextStyle(
                      color: _InboxPageState._ink,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                if (unreadCount > 0) _UnreadDot(count: unreadCount),
                _HeaderIcon(
                  icon: Icons.search_rounded,
                  onTap: onSearchTap,
                  tooltip: 'Search',
                ),
                _HeaderIcon(
                  icon: Icons.lock_outline_rounded,
                  onTap: onLockedTap,
                  badge: lockedCount,
                  tooltip: 'Locked chats',
                ),
                if (reportTaskCount > 0)
                  _HeaderIcon(
                    icon: Icons.support_agent_rounded,
                    onTap: onReportsTap,
                    badge: reportTaskCount,
                    tooltip: 'Report tasks',
                  ),
                _HeaderIcon(
                  icon: Icons.settings_outlined,
                  onTap: onSettingsTap,
                  tooltip: 'Settings',
                ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: onSearchTap,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE4E8EE)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0B1A24).withValues(alpha: 0.06),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: _InboxPageState._blue,
                      size: 21,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Search messages, rooms, and people',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _InboxPageState._muted,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.tune_rounded,
                      color: Color(0xFF64748B),
                      size: 19,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _HeaderMetricPill(
                    icon: Icons.mark_chat_unread_rounded,
                    label: 'Unread',
                    value: unreadCount,
                    color: _InboxPageState._blue,
                    onTap: onSearchTap,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HeaderMetricPill(
                    icon: Icons.shield_rounded,
                    label: 'Requests',
                    value: requestCount,
                    color: const Color(0xFFF59E0B),
                    onTap: onRequestsTap,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HeaderMetricPill(
                    icon: Icons.lock_outline_rounded,
                    label: 'Locked',
                    value: lockedCount,
                    color: const Color(0xFF14B8A6),
                    onTap: onLockedTap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderMetricPill extends StatelessWidget {
  const _HeaderMetricPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value > 99 ? '99+' : '$value',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _InboxPageState._ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _InboxPageState._muted,
                      fontSize: 10.6,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.badge = 0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Tooltip(
          message: tooltip,
          child: IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            onPressed: onTap,
            icon: Icon(icon, color: _InboxPageState._ink, size: 21),
          ),
        ),
        if (badge > 0)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: _InboxPageState._blue,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Center(
                child: Text(
                  badge > 99 ? '99+' : '$badge',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: _InboxPageState._blue.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: _InboxPageState._blue,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InboxAiPromptV3 extends StatelessWidget {
  const _InboxAiPromptV3({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEDEDEF)),
          ),
          child: Row(
            children: const [
              Icon(
                Icons.auto_awesome_rounded,
                color: _InboxPageState._blue,
                size: 18,
              ),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Find anything in chats...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _InboxPageState._muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_up_rounded,
                color: Color(0xFFB8B8C0),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryRailV3 extends StatelessWidget {
  const _StoryRailV3({
    required this.stories,
    required this.onCreateStory,
    required this.onStoryTap,
  });

  final List<InboxStoryItem> stories;
  final VoidCallback onCreateStory;
  final ValueChanged<int> onStoryTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 98,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        scrollDirection: Axis.horizontal,
        itemCount: stories.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _StoryBubbleV3.create(onTap: onCreateStory);
          }
          final story = stories[index - 1];
          return _StoryBubbleV3.story(
            story: story,
            onTap: () => onStoryTap(index - 1),
          );
        },
      ),
    );
  }
}

class _StoryBubbleV3 extends StatelessWidget {
  const _StoryBubbleV3.create({required this.onTap}) : story = null;
  const _StoryBubbleV3.story({required this.story, required this.onTap});

  final InboxStoryItem? story;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final item = story;
    final isCreate = item == null;
    final viewed = item?.isViewed ?? false;
    final label = isCreate ? 'Your story' : item.ownerName;
    final avatarUrl = item?.ownerAvatarUrl;
    final initial = isCreate ? '+' : _initial(label);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 62,
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              padding: EdgeInsets.all(isCreate ? 0 : 2.4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isCreate || viewed
                    ? null
                    : const LinearGradient(
                        colors: [
                          Color(0xFFFEDA75),
                          Color(0xFFFA7E1E),
                          Color(0xFFD62976),
                          Color(0xFF962FBF),
                        ],
                      ),
                border: isCreate || viewed
                    ? Border.all(color: const Color(0xFFD4D4D8), width: 1.4)
                    : null,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(2),
                child: ClipOval(
                  child: isCreate
                      ? const ColoredBox(
                          color: Color(0xFFF1F1F3),
                          child: Center(
                            child: Icon(
                              Icons.add_rounded,
                              color: _InboxPageState._ink,
                              size: 24,
                            ),
                          ),
                        )
                      : (avatarUrl != null && avatarUrl.trim().isNotEmpty)
                      ? Image.network(
                          avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _StoryInitial(initial: initial),
                        )
                      : _StoryInitial(initial: initial),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _InboxPageState._ink,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initial(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'S';
    return trimmed.substring(0, 1).toUpperCase();
  }
}

class _StoryInitial extends StatelessWidget {
  const _StoryInitial({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFEDEDF0),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: _InboxPageState._ink,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _FilterTabsV3 extends StatelessWidget {
  const _FilterTabsV3({
    required this.filters,
    required this.selectedFilter,
    required this.onChanged,
    required this.lockedCount,
    required this.onLockedTap,
  });

  final List<String> filters;
  final String selectedFilter;
  final ValueChanged<String> onChanged;
  final int lockedCount;
  final VoidCallback onLockedTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 3, 16, 5),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == filters.length) {
            return _FilterChipV3(
              label: lockedCount > 0 ? 'Locked $lockedCount' : 'Locked',
              selected: false,
              onTap: onLockedTap,
            );
          }
          final filter = filters[index];
          final selected = filter == selectedFilter;
          return _FilterChipV3(
            label: _label(filter),
            selected: selected,
            onTap: () => onChanged(filter),
          );
        },
      ),
    );
  }

  String _label(String value) {
    if (value == 'Room Invites') return 'Invites';
    if (value == 'Strangers') return 'Requests';
    return value;
  }
}

class _FilterChipV3 extends StatelessWidget {
  const _FilterChipV3({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? _InboxPageState._blue.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? _InboxPageState._blue.withValues(alpha: 0.22)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? _InboxPageState._blue : _InboxPageState._muted,
            fontSize: 12.7,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _StoryViewerPage extends StatefulWidget {
  const _StoryViewerPage({
    required this.stories,
    required this.initialIndex,
    required this.onViewed,
  });

  final List<InboxStoryItem> stories;
  final int initialIndex;
  final Future<void> Function(InboxStoryItem story) onViewed;

  @override
  State<_StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<_StoryViewerPage> {
  late int _index;
  final TextEditingController _replyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _markViewed();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _markViewed() async {
    final story = widget.stories[_index];
    if (!story.isViewed) {
      try {
        await widget.onViewed(story);
      } catch (_) {}
    }
  }

  void _next() {
    if (_index < widget.stories.length - 1) {
      setState(() => _index++);
      _markViewed();
    } else {
      Navigator.pop(context);
    }
  }

  void _previous() {
    if (_index > 0) {
      setState(() => _index--);
      _markViewed();
    }
  }

  void _sendReply() {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    _replyController.clear();
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF111114),
          content: Text(
            'Story reply service is not available yet.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
  }

  void _sendQuickReaction(String label) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF111114),
          content: Text(
            '$label reaction service is not available yet.',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[_index];
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onVerticalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) > 180) Navigator.pop(context);
          },
          child: Stack(
            children: [
              Positioned.fill(
                child: story.mediaType == 'image'
                    ? Image.network(
                        story.mediaUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: Colors.white70,
                                size: 42,
                              ),
                            ),
                      )
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.play_circle_fill_rounded,
                              color: Colors.white,
                              size: 62,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Video story',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _previous,
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _next,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                top: 8,
                child: Column(
                  children: [
                    Row(
                      children: List.generate(widget.stories.length, (i) {
                        return Expanded(
                          child: Container(
                            height: 2.2,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: i <= _index
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.28),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 17,
                          backgroundColor: Colors.white24,
                          backgroundImage: _avatar(story),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                story.ownerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                _storyAge(story.createdAt),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10.8,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if ((story.caption ?? '').trim().isNotEmpty)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 92,
                  child: Text(
                    story.caption?.trim() ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.30),
                          ),
                        ),
                        child: TextField(
                          controller: _replyController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Reply to story...',
                            hintStyle: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (_) => _sendReply(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StoryReactionButton(
                      icon: Icons.favorite_rounded,
                      label: 'Love',
                      onTap: () => _sendQuickReaction('Love'),
                    ),
                    const SizedBox(width: 6),
                    _StoryReactionButton(
                      icon: Icons.send_rounded,
                      label: 'Send',
                      onTap: _sendReply,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ImageProvider? _avatar(InboxStoryItem story) {
    final url = story.ownerAvatarUrl;
    if (url == null || url.trim().isEmpty) return null;
    return NetworkImage(url);
  }

  String _storyAge(DateTime? createdAt) {
    if (createdAt == null) return 'now';
    final delta = DateTime.now().difference(createdAt);
    if (delta.inMinutes < 1) return 'now';
    if (delta.inHours < 1) return '${delta.inMinutes}m';
    if (delta.inDays < 1) return '${delta.inHours}h';
    return '${delta.inDays}d';
  }
}

class _StoryReactionButton extends StatelessWidget {
  const _StoryReactionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.28),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
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

class _CreateStorySheetV3 extends StatefulWidget {
  const _CreateStorySheetV3();

  @override
  State<_CreateStorySheetV3> createState() => _CreateStorySheetV3State();
}

class _CreateStorySheetV3State extends State<_CreateStorySheetV3> {
  final TextEditingController _mediaUrl = TextEditingController();
  final TextEditingController _caption = TextEditingController();
  String _mediaType = 'image';
  String _visibility = 'friends';

  @override
  void dispose() {
    _mediaUrl.dispose();
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.55,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(
              16,
              10,
              16,
              18 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4D4D8),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'New story',
                style: TextStyle(
                  color: _InboxPageState._ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Preview, caption, then share.',
                style: TextStyle(
                  color: _InboxPageState._muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                height: 260,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F4F5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: _mediaUrl.text.trim().isNotEmpty && _mediaType == 'image'
                    ? Image.network(
                        _mediaUrl.text.trim(),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const _StoryUploadEmptyPreview(),
                      )
                    : const _StoryUploadEmptyPreview(),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _mediaUrl,
                onChanged: (_) => setState(() {}),
                decoration: _inputDecoration(
                  'Media link',
                  'Paste image/video link',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _caption,
                maxLength: 500,
                decoration: _inputDecoration('Caption', 'Write something...'),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _SelectChip(
                    label: 'Image',
                    selected: _mediaType == 'image',
                    onTap: () => setState(() => _mediaType = 'image'),
                  ),
                  const SizedBox(width: 8),
                  _SelectChip(
                    label: 'Video',
                    selected: _mediaType == 'video',
                    onTap: () => setState(() => _mediaType = 'video'),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    onSelected: (value) => setState(() => _visibility = value),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'friends', child: Text('Friends')),
                      PopupMenuItem(value: 'everyone', child: Text('Everyone')),
                      PopupMenuItem(value: 'nobody', child: Text('Only me')),
                    ],
                    child: _SelectChip(
                      label: _visibility == 'friends'
                          ? 'Friends'
                          : _visibility == 'everyone'
                          ? 'Everyone'
                          : 'Only me',
                      selected: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _InboxPageState._blue,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                onPressed: () {
                  final mediaUrl = _mediaUrl.text.trim();
                  if (mediaUrl.isEmpty) return;
                  Navigator.pop(
                    context,
                    _StoryDraft(
                      mediaUrl: mediaUrl,
                      mediaType: _mediaType,
                      visibility: _visibility,
                      caption: _caption.text.trim().isEmpty
                          ? null
                          : _caption.text.trim(),
                    ),
                  );
                },
                child: const Text(
                  'Post story',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  InputDecoration _inputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF7F7F8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _InboxPageState._blue),
      ),
    );
  }
}

class _SelectChip extends StatelessWidget {
  const _SelectChip({required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _InboxPageState._ink : const Color(0xFFF4F4F5),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _InboxPageState._ink,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _InboxV3OptionsSheet extends StatelessWidget {
  const _InboxV3OptionsSheet({
    required this.conversation,
    required this.onInfo,
    required this.onTogglePin,
    required this.onToggleMute,
    required this.onToggleLock,
    required this.onToggleBlock,
    required this.onReport,
  });

  final InboxConversation conversation;
  final VoidCallback onInfo;
  final VoidCallback onTogglePin;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleLock;
  final VoidCallback onToggleBlock;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        padding: EdgeInsets.fromLTRB(
          10,
          8,
          10,
          10 + MediaQuery.paddingOf(context).bottom,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD4D4D8),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 10),
            _SheetRow(
              icon: Icons.info_outline_rounded,
              label: 'Chat info',
              onTap: onInfo,
            ),
            _SheetRow(
              icon: Icons.push_pin_outlined,
              label: conversation.isPinned ? 'Unpin' : 'Pin',
              onTap: onTogglePin,
            ),
            _SheetRow(
              icon: Icons.volume_off_outlined,
              label: conversation.isMuted ? 'Unmute' : 'Mute',
              onTap: conversation.isOfficial ? null : onToggleMute,
            ),
            _SheetRow(
              icon: Icons.lock_outline_rounded,
              label: conversation.isLockedByBackend
                  ? 'Unlock chat'
                  : 'Lock chat',
              onTap: conversation.isOfficial ? null : onToggleLock,
            ),
            _SheetRow(
              icon: Icons.block_rounded,
              label: conversation.isBlocked ? 'Unblock' : 'Block',
              onTap: conversation.isOfficial ? null : onToggleBlock,
            ),
            _SheetRow(
              icon: Icons.report_outlined,
              label: 'Report',
              onTap: conversation.isOfficial ? null : onReport,
              destructive: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.icon,
    required this.label,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? const Color(0xFFEF4444) : _InboxPageState._ink;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyInboxStateV3 extends StatelessWidget {
  const _EmptyInboxStateV3({required this.onSearchTap});

  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F4F5),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFEDEDEF)),
              ),
              child: const Icon(
                Icons.forum_outlined,
                color: _InboxPageState._ink,
                size: 25,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'No chats yet',
              style: TextStyle(
                color: _InboxPageState._ink,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Search for friends or check message requests to start a conversation.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _InboxPageState._muted,
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: onSearchTap,
              style: TextButton.styleFrom(
                foregroundColor: _InboxPageState._blue,
                textStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('Search messages'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryUploadEmptyPreview extends StatelessWidget {
  const _StoryUploadEmptyPreview();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF4F4F5),
              border: Border.all(color: const Color(0xFFEDEDEF)),
            ),
          ),
        ),
        const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_photo_alternate_outlined,
                size: 38,
                color: _InboxPageState._muted,
              ),
              SizedBox(height: 10),
              Text(
                'Add image or video',
                style: TextStyle(
                  color: _InboxPageState._ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Paste a media link below',
                style: TextStyle(
                  color: _InboxPageState._muted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InboxLoadingSkeletonV3 extends StatefulWidget {
  const _InboxLoadingSkeletonV3();

  @override
  State<_InboxLoadingSkeletonV3> createState() =>
      _InboxLoadingSkeletonV3State();
}

class _InboxLoadingSkeletonV3State extends State<_InboxLoadingSkeletonV3>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final alpha = 0.42 + (_controller.value * 0.22);
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 7,
          itemBuilder: (context, index) {
            return Opacity(
              opacity: alpha,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const _SkeletonBox(width: 50, height: 50, radius: 25),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SkeletonBox(
                            width: 132 + (index % 3) * 20,
                            height: 12,
                            radius: 8,
                          ),
                          const SizedBox(height: 9),
                          _SkeletonBox(
                            width: 210 - (index % 3) * 24,
                            height: 10,
                            radius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    const _SkeletonBox(width: 32, height: 10, radius: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.width,
    required this.height,
    required this.radius,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFEDEDEF),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
