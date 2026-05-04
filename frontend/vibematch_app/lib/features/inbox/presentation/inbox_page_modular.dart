import 'package:flutter/material.dart';

import '../controllers/inbox_controller.dart';
import '../models/inbox_models.dart';
import 'pages/inbox_chat_page.dart';
import 'pages/inbox_search_page.dart';
import 'pages/inbox_settings_page.dart';
import 'pages/locked_chats_page.dart';
import 'widgets/inbox_conversation_card.dart';
import 'widgets/inbox_filter_bar.dart';
import 'widgets/inbox_header.dart';
import 'widgets/inbox_passcode_sheet.dart';

class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  final InboxController _controller = InboxController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    super.dispose();
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

  Future<void> _showPasscodeGate({
    required String title,
    required String subtitle,
    required VoidCallback onUnlocked,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => InboxPasscodeSheet(
        title: title,
        subtitle: subtitle,
        onValidate: _controller.validatePasscode,
        onUnlocked: () {
          Navigator.pop(context);
          onUnlocked();
        },
      ),
    );
  }

  void _openConversation(InboxConversation conversation) {
    if (conversation.isLockedByBackend && !_controller.lockedVaultUnlocked) {
      _showPasscodeGate(
        title: 'Unlock chat',
        subtitle: 'This chat is backend-locked for your account. Enter passcode to open it on this device.',
        onUnlocked: () {
          _controller.unlockLockedVault();
          _pushChat(conversation);
        },
      );
      return;
    }

    _pushChat(conversation);
  }

  void _openLockedVault() {
    if (_controller.lockedVaultUnlocked) {
      _pushLockedVault();
      return;
    }

    _showPasscodeGate(
      title: 'Locked chats',
      subtitle: 'Locked chats are hidden from Inbox and require account passcode before viewing.',
      onUnlocked: () {
        _controller.unlockLockedVault();
        _pushLockedVault();
      },
    );
  }

  void _pushLockedVault() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LockedChatsPage(
          conversations: _controller.lockedConversations,
          onOpenConversation: _openConversation,
          onShowOptions: _showChatOptions,
          onBackTap: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _pushChat(InboxConversation conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InboxChatPage(
          conversation: conversation,
          onMoreTap: () => _showChatOptions(conversation),
        ),
      ),
    );
  }

  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InboxSearchPage(
          controller: _controller,
          onOpenConversation: _openConversation,
        ),
      ),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InboxSettingsPage(
          backupEnabled: _controller.backupEnabled,
          frequency: _controller.backupFrequency,
          onBackupEnabledChanged: _controller.setBackupEnabled,
          onFrequencyChanged: _controller.setBackupFrequency,
          onBackupNow: () => _toast('Encrypted backup flow will connect to backend/Drive later.'),
          onRestoreTap: () => _toast('Restore from backup flow will connect later.'),
          onBackTap: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _showChatOptions(InboxConversation conversation) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _InboxChatOptionsSheet(
        conversation: conversation,
        onToggleLock: () {
          Navigator.pop(context);
          _controller.toggleBackendLock(conversation);
          _toast('Backend chat lock state updated locally for now.');
        },
        onToggleBlock: () {
          Navigator.pop(context);
          _controller.toggleBlock(conversation);
          _toast('Block state updated locally. Backend will own this later.');
        },
        onReport: () {
          Navigator.pop(context);
          _toast('Report flow will connect to CS/Monitor workflow later.');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleConversations = _controller.visibleConversations;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: InboxHeader(
                lockedCount: _controller.lockedCount,
                onLockTap: _openLockedVault,
                onSettingsTap: _openSettings,
                onSearchTap: _openSearch,
              ),
            ),
            SliverToBoxAdapter(
              child: InboxFilterBar(
                filters: _controller.filters,
                selectedFilter: _controller.selectedFilter,
                onChanged: _controller.selectFilter,
              ),
            ),
            if (visibleConversations.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyInboxState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 104),
                sliver: SliverList.separated(
                  itemCount: visibleConversations.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final conversation = visibleConversations[index];
                    return InboxConversationCard(
                      conversation: conversation,
                      onTap: () => _openConversation(conversation),
                      onLongPress: () => _showChatOptions(conversation),
                    );
                  },
                ),
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
    required this.onToggleLock,
    required this.onToggleBlock,
    required this.onReport,
  });

  final InboxConversation conversation;
  final VoidCallback onToggleLock;
  final VoidCallback onToggleBlock;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(14),
      padding: EdgeInsets.fromLTRB(18, 10, 18, 18 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 30,
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
          Text(
            conversation.title,
            style: const TextStyle(
              color: Color(0xFF251538),
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          _OptionTile(
            icon: conversation.isLockedByBackend ? Icons.lock_open_rounded : Icons.lock_rounded,
            title: conversation.isLockedByBackend ? 'Unlock chat' : 'Lock chat',
            subtitle: 'Backend account-level lock, not local device lock.',
            onTap: conversation.isOfficial ? null : onToggleLock,
          ),
          _OptionTile(
            icon: conversation.isBlocked ? Icons.undo_rounded : Icons.block_rounded,
            title: conversation.isBlocked ? 'Unblock profile' : 'Block profile',
            subtitle: 'Blocks are synced by backend later.',
            onTap: conversation.isOfficial ? null : onToggleBlock,
          ),
          _OptionTile(
            icon: Icons.report_rounded,
            title: 'Report profile',
            subtitle: 'Sends to CS/Monitor workflow later.',
            onTap: conversation.isOfficial ? null : onReport,
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Opacity(
        opacity: disabled ? 0.45 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          margin: const EdgeInsets.only(bottom: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF7F1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFECE2D8)),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF4A2A63), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Color(0xFF251538), fontSize: 13, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11, fontWeight: FontWeight.w700)),
                  ],
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
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFECE2D8)),
        ),
        child: const Text(
          'No chats here',
          style: TextStyle(
            color: Color(0xFF7B6A86),
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
