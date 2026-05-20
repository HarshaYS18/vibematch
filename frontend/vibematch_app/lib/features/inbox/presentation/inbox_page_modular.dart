import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/inbox_controller.dart';
import '../data/inbox_stories_api_service.dart';
import '../models/inbox_models.dart';
import 'pages/cs_report_tasks_page.dart';
import 'pages/inbox_chat_info_page.dart';
import 'pages/inbox_chat_page.dart';
import 'pages/inbox_search_page.dart';
import 'pages/inbox_settings_page.dart';
import 'pages/locked_chats_page.dart';
import 'pages/stranger_requests_page.dart';
import 'widgets/inbox_conversation_card.dart';
import 'widgets/inbox_light_premium_tokens.dart';
import 'widgets/inbox_lock_flow_sheets.dart';
import 'widgets/inbox_passcode_sheet.dart';
import 'widgets/inbox_chat_theme_picker_sheet.dart';
import 'widgets/inbox_story_widgets.dart';
import 'widgets/report_conversation_sheet.dart';

const String _lockedChatsCoachSeenKey =
    'funkey_inbox_locked_chats_coach_seen_v1';

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
  final InboxStoriesApiService _storiesApi = const InboxStoriesApiService();
  Widget? _panelOverlay;
  Future<List<InboxStoryItem>>? _storiesFuture;
  int _lastHandledOpenConversationRequestNonce = 0;
  String? _activeConversationId;
  bool _showLockedChatsCoach = false;
  String _selectedLandingSection = 'All';

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? InboxController();
    _ownsController = widget.controller == null;
    _controller.addListener(_handleControllerChanged);
    _storiesFuture = _storiesApi.loadStories();
    unawaited(_loadLockedChatsCoachState());
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
    _controller.removeListener(_handleControllerChanged);
    if (_ownsController) _controller.dispose();
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
      if (conversation == null) return;
      _openConversation(conversation);
    });
  }

  void _handleControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadLockedChatsCoachState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _showLockedChatsCoach =
          !(prefs.getBool(_lockedChatsCoachSeenKey) ?? false);
    });
  }

  Future<void> _markLockedChatsCoachSeen() async {
    if (_showLockedChatsCoach && mounted) {
      setState(() => _showLockedChatsCoach = false);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lockedChatsCoachSeenKey, true);
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
    final base = _controller.unlockedConversations
        .where((item) => !item.isArchived && !item.isStranger)
        .toList();
    switch (_selectedLandingSection) {
      case 'Groups':
        return base
            .where((item) => item.type == InboxConversationType.group)
            .toList();
      case 'Calls':
        return base
            .where((item) => item.type == InboxConversationType.callLog)
            .toList();
      case 'Requests':
        final hub = _strangerHub;
        return hub == null
            ? const <InboxConversation>[]
            : <InboxConversation>[hub];
      default:
        final hub = _strangerHub;
        if (hub != null) base.insert(0, hub);
        return base;
    }
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
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
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
          controller: _controller,
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
    unawaited(_markLockedChatsCoachSeen());
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
    final result = await showModalBottomSheet<InboxStoryDraft>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const InboxCreateStorySheet(),
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

  void _openStoryViewer(InboxStoryItem story) {
    unawaited(_markStoryViewed(story));
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: false,
      enableDrag: false,
      builder: (_) => InboxStoryViewerSheet(story: story),
    );
  }

  Future<void> _markStoryViewed(InboxStoryItem story) async {
    try {
      await _storiesApi.markViewed(story.id);
      if (mounted) _refreshStories();
    } catch (_) {
      if (mounted) _toast('Could not update story view. Try again later.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleConversations = _premiumVisibleConversations;
    final page = Stack(
      children: [
        Scaffold(
          backgroundColor: InboxLightPremiumTokens.page,
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
                    child: _InstagramInboxHeader(
                      lockedCount: _controller.lockedCount,
                      reportTaskCount: _controller.pendingReportTaskCount,
                      showLockedCoach: _showLockedChatsCoach,
                      onSearchTap: _openSearch,
                      onSettingsTap: _openSettings,
                      onLockedTap: _openLockedVault,
                      onReportsTap: _openCsReportTasks,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: FutureBuilder<List<InboxStoryItem>>(
                      future: _storiesFuture,
                      builder: (context, snapshot) {
                        final stories =
                            snapshot.data ?? const <InboxStoryItem>[];
                        final loading =
                            snapshot.connectionState ==
                                ConnectionState.waiting &&
                            stories.isEmpty;
                        final error = snapshot.hasError
                            ? friendlyInboxStoryLoadError(snapshot.error)
                            : null;
                        return InboxStoryRail(
                          stories: stories,
                          loading: loading,
                          errorMessage: error,
                          onCreateStory: _createStory,
                          onStoryTap: _openStoryViewer,
                          onRetry: _refreshStories,
                        );
                      },
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _PremiumFilterRail(
                      selectedFilter: _selectedLandingSection,
                      onChanged: (section) =>
                          setState(() => _selectedLandingSection = section),
                    ),
                  ),
                  if (_controller.isLoading && visibleConversations.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF7C3AED),
                        ),
                      ),
                    )
                  else if (visibleConversations.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyInboxState(),
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
                  const SliverToBoxAdapter(child: SizedBox(height: 104)),
                ],
              ),
            ),
          ),
        ),
        if (_panelOverlay != null)
          Positioned.fill(
            child: Material(
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

class _InstagramInboxHeader extends StatelessWidget {
  const _InstagramInboxHeader({
    required this.lockedCount,
    required this.reportTaskCount,
    required this.showLockedCoach,
    required this.onSearchTap,
    required this.onSettingsTap,
    required this.onLockedTap,
    required this.onReportsTap,
  });

  final int lockedCount;
  final int reportTaskCount;
  final bool showLockedCoach;
  final VoidCallback onSearchTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onLockedTap;
  final VoidCallback onReportsTap;

  @override
  Widget build(BuildContext context) {
    final showVaultHint = showLockedCoach || lockedCount > 0;
    return Container(
      decoration: const BoxDecoration(
        gradient: InboxLightPremiumTokens.pageGradient,
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inbox',
                      style: TextStyle(
                        color: InboxLightPremiumTokens.ink,
                        fontSize: 29,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.9,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Stories and conversations',
                      style: TextStyle(
                        color: InboxLightPremiumTokens.muted,
                        fontSize: 11.8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              _TopIcon(icon: Icons.search_rounded, onTap: onSearchTap),
              _TopIcon(
                icon: Icons.lock_rounded,
                onTap: onLockedTap,
                badge: lockedCount,
              ),
              if (reportTaskCount > 0)
                _TopIcon(
                  icon: Icons.support_agent_rounded,
                  onTap: onReportsTap,
                  badge: reportTaskCount,
                ),
              _TopIcon(icon: Icons.settings_rounded, onTap: onSettingsTap),
            ],
          ),
          if (showVaultHint) ...[
            const SizedBox(height: 9),
            _PullDownHint(
              lockedCount: lockedCount,
              showCoach: showLockedCoach,
              onTap: onLockedTap,
            ),
          ],
        ],
      ),
    );
  }
}

class _PullDownHint extends StatelessWidget {
  const _PullDownHint({
    required this.lockedCount,
    required this.showCoach,
    required this.onTap,
  });

  final int lockedCount;
  final bool showCoach;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: InboxLightPremiumTokens.card.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: InboxLightPremiumTokens.warmBorder),
          boxShadow: [InboxLightPremiumTokens.softShadow(0.035)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 21,
              height: 21,
              decoration: BoxDecoration(
                gradient: InboxLightPremiumTokens.aquaGradient,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Icon(
                Icons.keyboard_double_arrow_down_rounded,
                color: Colors.white,
                size: 15,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              showCoach
                  ? 'New: pull down to open locked chats'
                  : lockedCount == 0
                  ? 'Pull down to open locked chats'
                  : 'Pull down for $lockedCount locked chat${lockedCount == 1 ? '' : 's'}',
              style: const TextStyle(
                color: InboxLightPremiumTokens.muted,
                fontSize: 11.2,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopIcon extends StatelessWidget {
  const _TopIcon({required this.icon, required this.onTap, this.badge = 0});

  final IconData icon;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Container(
        margin: const EdgeInsets.only(left: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.86),
          shape: BoxShape.circle,
          border: Border.all(color: InboxLightPremiumTokens.border),
          boxShadow: [InboxLightPremiumTokens.softShadow(0.045)],
        ),
        child: IconButton(
          onPressed: onTap,
          icon: Icon(icon, color: InboxLightPremiumTokens.ink, size: 22),
        ),
      ),
      if (badge > 0)
        Positioned(
          right: 2,
          top: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              gradient: InboxLightPremiumTokens.primaryGradient,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Text(
              badge > 99 ? '99+' : '$badge',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
    ],
  );
}

class _PremiumFilterRail extends StatelessWidget {
  const _PremiumFilterRail({
    required this.selectedFilter,
    required this.onChanged,
  });

  final String selectedFilter;
  final ValueChanged<String> onChanged;
  static const List<String> _sections = ['All', 'Groups', 'Calls', 'Requests'];

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 46,
    child: ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      scrollDirection: Axis.horizontal,
      itemCount: _sections.length,
      separatorBuilder: (context, index) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final filter = _sections[index];
        final selected = filter == selectedFilter;
        return InkWell(
          onTap: () => onChanged(filter),
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? InboxLightPremiumTokens.ink
                  : Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? InboxLightPremiumTokens.ink
                    : InboxLightPremiumTokens.border,
              ),
              boxShadow: selected
                  ? [InboxLightPremiumTokens.softShadow(0.07)]
                  : null,
            ),
            child: Text(
              filter,
              style: TextStyle(
                color: selected ? Colors.white : InboxLightPremiumTokens.muted,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: -0.05,
              ),
            ),
          ),
        );
      },
    ),
  );
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

class _EmptyInboxState extends StatelessWidget {
  const _EmptyInboxState();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: InboxLightPremiumTokens.cardDecoration(radius: 28),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.forum_rounded,
            color: InboxLightPremiumTokens.violet,
            size: 32,
          ),
          SizedBox(height: 10),
          Text(
            'No chats here',
            style: TextStyle(
              color: InboxLightPremiumTokens.ink,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'New friend chats, room invites and team messages will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: InboxLightPremiumTokens.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
      ),
    ),
  );
}
