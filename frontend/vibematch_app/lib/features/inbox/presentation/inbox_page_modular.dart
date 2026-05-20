import 'package:flutter/material.dart';

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
import 'widgets/inbox_lock_flow_sheets.dart';
import 'widgets/inbox_passcode_sheet.dart';
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
  final InboxStoriesApiService _storiesApi = const InboxStoriesApiService();
  Widget? _panelOverlay;
  Future<List<InboxStoryItem>>? _storiesFuture;
  int _lastHandledOpenConversationRequestNonce = 0;
  String? _activeConversationId;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? InboxController();
    _ownsController = widget.controller == null;
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
    _controller.removeListener(_handleControllerChanged);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _handleRequestedConversationOpen() {
    final conversationId = widget.openConversationId;
    if (conversationId == null || conversationId.isEmpty) return;
    if (widget.openConversationRequestNonce == _lastHandledOpenConversationRequestNonce) return;
    _lastHandledOpenConversationRequestNonce = widget.openConversationRequestNonce;
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
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      );
  }

  void _refreshStories() {
    setState(() => _storiesFuture = _storiesApi.loadStories());
  }

  List<InboxConversation> get _strangerRequests => _controller.conversations.where((item) => item.isStranger && !item.isArchived).toList();

  InboxConversation? get _strangerHub {
    final requests = _strangerRequests;
    if (requests.isEmpty) return null;
    final unread = requests.fold<int>(0, (sum, item) => sum + item.unreadCount);
    return InboxConversation(
      id: '__stranger_hub__',
      title: 'Stranger Messages',
      subtitle: '${requests.length} request${requests.length == 1 ? '' : 's'} waiting',
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
    final base = _controller.visibleConversations.where((item) => !item.isStranger).toList();
    if (_controller.selectedFilter == 'Strangers') {
      final hub = _strangerHub;
      return hub == null ? const <InboxConversation>[] : <InboxConversation>[hub];
    }
    if (_controller.selectedFilter == 'All') {
      final hub = _strangerHub;
      if (hub != null) base.insert(0, hub);
    }
    return base;
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
        onVerifySetup: (mobile, otp, lock) => _controller.verifyLockSetup(mobileNumber: mobile, otp: otp, lockCode: lock),
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
        onVerifyRecovery: (mobile, otp, newLock) => _controller.verifyLockRecovery(mobileNumber: mobile, otp: otp, newLockCode: newLock),
        onRequestCs: _controller.requestCsLockRecovery,
      ),
    );
  }

  Future<void> _showPasscodeGate({required String title, required String subtitle, required VoidCallback onUnlocked}) async {
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
        subtitle: 'This chat is locked for your account. Enter your Inbox lock to open it.',
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
      Navigator.push(context, MaterialPageRoute(builder: (_) => page)).then((_) => _clearActiveConversationForShell());
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
          onThemeTap: () => _toast('Chat themes are being connected to Store inventory next.'),
        ),
      );
    });
  }

  void _clearActiveConversationForShell() {
    if (_activeConversationId == null) return;
    _activeConversationId = null;
    widget.onActiveConversationChanged?.call(null);
  }

  void _openSearch() => _openInboxSubPage(InboxSearchPage(controller: _controller, onOpenConversation: _openConversation, onBackTap: _closePanelOverlay));

  void _openSettings() {
    _openInboxSubPage(
      InboxSettingsPage(
        lockStatus: _controller.lockStatus,
        backupStatus: _controller.backupStatus,
        strangersCanMessage: _controller.strangersCanMessage,
        strangersCanMentionInVibes: _controller.strangersCanMentionInVibes,
        onStartLockSetup: _controller.startLockSetup,
        onVerifyLockSetup: (mobile, otp, lock) => _controller.verifyLockSetup(mobileNumber: mobile, otp: otp, lockCode: lock),
        onChangeLock: (currentLock, newLock) => _controller.changeLock(currentLockCode: currentLock, newLockCode: newLock),
        onStartLockRecovery: _controller.startLockRecovery,
        onVerifyLockRecovery: (mobile, otp, newLock) => _controller.verifyLockRecovery(mobileNumber: mobile, otp: otp, newLockCode: newLock),
        onRequestCsLockRecovery: _controller.requestCsLockRecovery,
        onStartGoogleDriveSetup: _controller.startGoogleDriveAuthorization,
        onConnectGoogleDrive: (email, code) => _controller.connectGoogleDrive(googleDriveEmail: email, setupCode: code),
        onBackupEnabledChanged: _controller.setBackupEnabled,
        onFrequencyChanged: _controller.setBackupFrequency,
        onStrangersCanMessageChanged: _controller.setStrangersCanMessage,
        onStrangersCanMentionInVibesChanged: _controller.setStrangersCanMentionInVibes,
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
    _showPasscodeGate(title: 'Locked chats', subtitle: 'Enter your Inbox lock before viewing locked conversations.', onUnlocked: _openLockedVaultPage);
  }

  void _openLockedVaultPage() {
    _openInboxSubPage(LockedChatsPage(conversations: _controller.lockedConversations, onOpenConversation: _openConversation, onShowOptions: _showChatOptions, onBackTap: _closePanelOverlay));
  }

  void _openStrangerRequests() {
    _openInboxSubPage(StrangerRequestsPage(requests: _strangerRequests, onOpenConversation: _openConversation, onShowOptions: _showChatOptions, onBackTap: _closePanelOverlay));
  }

  void _openCsReportTasks() {
    _openInboxSubPage(CsReportTasksPage(controller: _controller, onBackTap: _closePanelOverlay));
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
            _controller.submitConversationReport(conversation: conversation, reason: reason);
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
        if (!_controller.lockStatus.isEnabled && !conversation.isLockedByBackend) {
          _closeChatOptions();
          _toast('Set up Inbox lock before locking chats.');
          _openLockSetupSheet();
          return;
        }
        _controller.toggleBackendLock(conversation);
        _closeChatOptions();
        _toast(conversation.isLockedByBackend ? 'Chat unlocked.' : 'Chat locked.');
      },
      onToggleBlock: () {
        _controller.toggleBlock(conversation);
        _closeChatOptions();
        _toast(conversation.isBlocked ? 'Profile unblocked.' : 'Profile blocked.');
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
      setState(() => _panelOverlay = Align(alignment: Alignment.bottomCenter, child: sheet));
      return;
    }
    showModalBottomSheet<void>(context: context, isDismissible: true, enableDrag: true, backgroundColor: Colors.transparent, isScrollControlled: true, builder: (_) => sheet);
  }

  Future<void> _createStory() async {
    final result = await showModalBottomSheet<_StoryDraft>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _CreateStorySheet(),
    );
    if (result == null) return;
    try {
      await _storiesApi.createStory(mediaUrl: result.mediaUrl, mediaType: result.mediaType, caption: result.caption, visibility: result.visibility);
      _toast('Story posted.');
      _refreshStories();
    } catch (error) {
      _toast(error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleConversations = _premiumVisibleConversations;
    final page = Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFFAF7F1),
          floatingActionButton: FloatingActionButton(
            onPressed: _openSearch,
            backgroundColor: const Color(0xFF251538),
            foregroundColor: Colors.white,
            elevation: 3,
            child: const Icon(Icons.edit_rounded),
          ),
          body: SafeArea(
            child: RefreshIndicator(
              color: const Color(0xFF7C3AED),
              onRefresh: () async {
                await _controller.loadFromBackend();
                _refreshStories();
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  SliverToBoxAdapter(
                    child: _InstagramInboxHeader(
                      unreadCount: _controller.unreadCount,
                      lockedCount: _controller.lockedCount,
                      requestCount: _strangerRequests.length,
                      reportTaskCount: _controller.pendingReportTaskCount,
                      onSearchTap: _openSearch,
                      onSettingsTap: _openSettings,
                      onLockedTap: _openLockedVault,
                      onReportsTap: _openCsReportTasks,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: FutureBuilder<List<InboxStoryItem>>(
                      future: _storiesFuture,
                      builder: (context, snapshot) => _PremiumStoryRail(
                        stories: snapshot.data ?? const <InboxStoryItem>[],
                        onCreateStory: _createStory,
                        onStoryTap: (story) async {
                          await _storiesApi.markViewed(story.id);
                          if (!mounted) return;
                          _toast('${story.ownerName}: ${story.caption ?? 'Story opened'}');
                          _refreshStories();
                        },
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(child: _PremiumFilterRail(filters: _controller.filters, selectedFilter: _controller.selectedFilter, onChanged: _controller.selectFilter)),
                  if (_controller.isLoading && visibleConversations.isEmpty)
                    const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED))))
                  else if (visibleConversations.isEmpty)
                    const SliverFillRemaining(hasScrollBody: false, child: _EmptyInboxState())
                  else
                    SliverList.builder(
                      itemCount: visibleConversations.length,
                      itemBuilder: (context, index) {
                        final conversation = visibleConversations[index];
                        return InboxConversationCard(conversation: conversation, onTap: () => _openConversation(conversation), onLongPress: () => _showChatOptions(conversation));
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
                  Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => setState(() => _panelOverlay = null))),
                  Positioned.fill(child: _panelOverlay!),
                ],
              ),
            ),
          ),
      ],
    );
    if (!widget.openPagesInOverlay) return page;
    return PopScope<void>(canPop: _panelOverlay == null, onPopInvokedWithResult: (didPop, result) { if (didPop) return; _handleBackInsideOverlay(); }, child: page);
  }
}

class _InstagramInboxHeader extends StatelessWidget {
  const _InstagramInboxHeader({required this.unreadCount, required this.lockedCount, required this.requestCount, required this.reportTaskCount, required this.onSearchTap, required this.onSettingsTap, required this.onLockedTap, required this.onReportsTap});
  final int unreadCount;
  final int lockedCount;
  final int requestCount;
  final int reportTaskCount;
  final VoidCallback onSearchTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onLockedTap;
  final VoidCallback onReportsTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Inbox', style: TextStyle(color: Color(0xFF111111), fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.8))),
              _TopIcon(icon: Icons.search_rounded, onTap: onSearchTap),
              _TopIcon(icon: Icons.lock_rounded, onTap: onLockedTap, badge: lockedCount),
              _TopIcon(icon: Icons.settings_rounded, onTap: onSettingsTap),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _InboxPill(label: unreadCount == 0 ? 'No unread' : '$unreadCount unread', icon: Icons.mark_chat_unread_rounded, onTap: onSearchTap),
              const SizedBox(width: 8),
              _InboxPill(label: requestCount == 0 ? 'Requests' : '$requestCount requests', icon: Icons.shield_rounded, onTap: onSearchTap),
              const SizedBox(width: 8),
              if (reportTaskCount > 0) _InboxPill(label: '$reportTaskCount CS', icon: Icons.support_agent_rounded, onTap: onReportsTap),
            ],
          ),
        ],
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
          IconButton(onPressed: onTap, icon: Icon(icon, color: const Color(0xFF111111), size: 25)),
          if (badge > 0)
            Positioned(right: 6, top: 5, child: Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFFF2D55), borderRadius: BorderRadius.circular(99)), child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)))),
        ],
      );
}

class _InboxPill extends StatelessWidget {
  const _InboxPill({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFFE8DFD5))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: const Color(0xFF7C3AED), size: 15), const SizedBox(width: 6), Text(label, style: const TextStyle(color: Color(0xFF251538), fontSize: 11.5, fontWeight: FontWeight.w900))]),
        ),
      );
}

class _PremiumStoryRail extends StatelessWidget {
  const _PremiumStoryRail({required this.stories, required this.onCreateStory, required this.onStoryTap});
  final List<InboxStoryItem> stories;
  final VoidCallback onCreateStory;
  final ValueChanged<InboxStoryItem> onStoryTap;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        scrollDirection: Axis.horizontal,
        itemCount: stories.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index == 0) return _StoryBubble(label: 'Your story', avatarText: '+', colors: const [Color(0xFF12C7B7), Color(0xFF7C3AED)], onTap: onCreateStory);
          final story = stories[index - 1];
          return _StoryBubble(label: story.ownerName, avatarText: story.ownerName.isEmpty ? 'S' : story.ownerName.characters.first.toUpperCase(), colors: story.isViewed ? const [Color(0xFFB8B1C1), Color(0xFFD8D2DD)] : const [Color(0xFFFF2D55), Color(0xFFFFB020), Color(0xFF7C3AED)], onTap: () => onStoryTap(story));
        },
      ),
    );
  }
}

class _StoryBubble extends StatelessWidget {
  const _StoryBubble({required this.label, required this.avatarText, required this.colors, required this.onTap});
  final String label;
  final String avatarText;
  final List<Color> colors;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(width: 66, child: Column(children: [Container(width: 58, height: 58, padding: const EdgeInsets.all(2.5), decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: colors)), child: Container(decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Center(child: Text(avatarText, style: const TextStyle(color: Color(0xFF251538), fontWeight: FontWeight.w900))))), const SizedBox(height: 6), Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF5E4B6F), fontSize: 10.5, fontWeight: FontWeight.w800))])),
      );
}

class _PremiumFilterRail extends StatelessWidget {
  const _PremiumFilterRail({required this.filters, required this.selectedFilter, required this.onChanged});
  final List<String> filters;
  final String selectedFilter;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => SizedBox(height: 48, child: ListView.separated(padding: const EdgeInsets.symmetric(horizontal: 14), scrollDirection: Axis.horizontal, itemCount: filters.length, separatorBuilder: (context, index) => const SizedBox(width: 8), itemBuilder: (context, index) { final filter = filters[index]; final selected = filter == selectedFilter; return ChoiceChip(label: Text(filter), selected: selected, onSelected: (selected) => onChanged(filter), selectedColor: const Color(0xFF251538), backgroundColor: Colors.white, labelStyle: TextStyle(color: selected ? Colors.white : const Color(0xFF5E4B6F), fontWeight: FontWeight.w900, fontSize: 12), side: BorderSide(color: selected ? const Color(0xFF251538) : const Color(0xFFE5DDF1))); }));
}

class _InboxChatOptionsSheet extends StatelessWidget {
  const _InboxChatOptionsSheet({required this.conversation, required this.onInfo, required this.onToggleLock, required this.onToggleBlock, required this.onToggleMute, required this.onTogglePin, required this.onReport});
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
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.72),
        padding: EdgeInsets.fromLTRB(14, 8, 14, 10 + bottomPadding),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 30, offset: const Offset(0, 14))]),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 42, height: 5, decoration: BoxDecoration(color: const Color(0xFFD1D7DB), borderRadius: BorderRadius.circular(999))),
            const SizedBox(height: 10),
            Text(conversation.title, style: const TextStyle(color: Color(0xFF251538), fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            _OptionTile(icon: Icons.info_rounded, title: 'Chat info', onTap: onInfo),
            _OptionTile(icon: conversation.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded, title: conversation.isPinned ? 'Unpin chat' : 'Pin chat', onTap: onTogglePin),
            _OptionTile(icon: conversation.isMuted ? Icons.volume_up_rounded : Icons.volume_off_rounded, title: conversation.isMuted ? 'Unmute chat' : 'Mute chat', onTap: conversation.isOfficial ? null : onToggleMute),
            _OptionTile(icon: conversation.isLockedByBackend ? Icons.lock_open_rounded : Icons.lock_rounded, title: conversation.isLockedByBackend ? 'Unlock chat' : 'Lock chat', onTap: conversation.isOfficial ? null : onToggleLock),
            _OptionTile(icon: conversation.isBlocked ? Icons.undo_rounded : Icons.block_rounded, title: conversation.isBlocked ? 'Unblock profile' : 'Block profile', onTap: conversation.isOfficial ? null : onToggleBlock),
            _OptionTile(icon: Icons.report_rounded, title: 'Report profile', onTap: conversation.isOfficial ? null : onReport),
          ]),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.icon, required this.title, required this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: Opacity(opacity: disabled ? 0.45 : 1, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12), margin: const EdgeInsets.only(bottom: 6), decoration: BoxDecoration(color: const Color(0xFFF8F5FF), borderRadius: BorderRadius.circular(16)), child: Row(children: [Icon(icon, color: const Color(0xFF7C3AED), size: 20), const SizedBox(width: 12), Expanded(child: Text(title, style: const TextStyle(color: Color(0xFF251538), fontSize: 14, fontWeight: FontWeight.w800))), const Icon(Icons.chevron_right_rounded, color: Color(0xFF9B8CA5))]))));
  }
}

class _StoryDraft {
  const _StoryDraft({required this.mediaUrl, required this.mediaType, required this.visibility, this.caption});
  final String mediaUrl;
  final String mediaType;
  final String visibility;
  final String? caption;
}

class _CreateStorySheet extends StatefulWidget {
  const _CreateStorySheet();
  @override
  State<_CreateStorySheet> createState() => _CreateStorySheetState();
}

class _CreateStorySheetState extends State<_CreateStorySheet> {
  final TextEditingController _url = TextEditingController();
  final TextEditingController _caption = TextEditingController();
  String _mediaType = 'image';
  String _visibility = 'friends';

  @override
  void dispose() { _url.dispose(); _caption.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + MediaQuery.paddingOf(context).bottom),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Create story', style: TextStyle(color: Color(0xFF251538), fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          TextField(controller: _url, decoration: const InputDecoration(labelText: 'Media URL', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _caption, maxLength: 500, decoration: const InputDecoration(labelText: 'Caption', border: OutlineInputBorder())),
          Row(children: [
            Expanded(child: DropdownButtonFormField<String>(value: _mediaType, items: const [DropdownMenuItem(value: 'image', child: Text('Image')), DropdownMenuItem(value: 'video', child: Text('Video'))], onChanged: (value) => setState(() => _mediaType = value ?? 'image'), decoration: const InputDecoration(labelText: 'Type'))),
            const SizedBox(width: 10),
            Expanded(child: DropdownButtonFormField<String>(value: _visibility, items: const [DropdownMenuItem(value: 'friends', child: Text('Friends')), DropdownMenuItem(value: 'everyone', child: Text('Everyone')), DropdownMenuItem(value: 'nobody', child: Text('Only me'))], onChanged: (value) => setState(() => _visibility = value ?? 'friends'), decoration: const InputDecoration(labelText: 'Privacy'))),
          ]),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: () { final mediaUrl = _url.text.trim(); if (mediaUrl.isEmpty) return; Navigator.pop(context, _StoryDraft(mediaUrl: mediaUrl, mediaType: _mediaType, visibility: _visibility, caption: _caption.text.trim().isEmpty ? null : _caption.text.trim())); }, child: const Text('Post story'))),
        ]),
      ),
    );
  }
}

class _EmptyInboxState extends StatelessWidget {
  const _EmptyInboxState();
  @override
  Widget build(BuildContext context) => Center(child: Container(margin: const EdgeInsets.all(24), padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)), child: const Text('No chats here', style: TextStyle(color: Color(0xFF7B6A86), fontSize: 14, fontWeight: FontWeight.w800))));
}
