import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/inbox_controller.dart';
import '../../models/inbox_models.dart';
import '../widgets/inbox_call_action_sheet.dart';
import '../widgets/inbox_light_premium_tokens.dart';
import '../widgets/inbox_time_formatters.dart';

class InboxChatInfoPage extends StatefulWidget {
  const InboxChatInfoPage({
    super.key,
    required this.conversation,
    required this.controller,
    required this.onBackTap,
    required this.onSearchTap,
    required this.onThemeTap,
  });

  final InboxConversation conversation;
  final InboxController controller;
  final VoidCallback onBackTap;
  final VoidCallback onSearchTap;
  final VoidCallback onThemeTap;

  @override
  State<InboxChatInfoPage> createState() => _InboxChatInfoPageState();
}

class _InboxChatInfoPageState extends State<InboxChatInfoPage> {
  String _selected = 'Media';

  InboxConversation get _conversation =>
      widget.controller.conversationById(widget.conversation.id) ??
      widget.conversation;

  List<InboxMessage> get _media => _conversation.messages
      .where(
        (message) =>
            message.type == InboxMessageType.image ||
            message.type == InboxMessageType.voice ||
            message.type == InboxMessageType.document,
      )
      .toList()
      .reversed
      .toList();

  List<InboxMessage> get _starred => _conversation.messages
      .where((message) => message.isStarred)
      .toList()
      .reversed
      .toList();

  void _openCallSheet() {
    final conversation = _conversation;
    if (conversation.isOfficial) {
      _toast('Official team chats cannot be called.');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => InboxCallActionSheet(
        conversation: conversation,
        callController: widget.controller.callController,
      ),
    );
  }

  Future<void> _toggleMute() async {
    final conversation = _conversation;
    if (conversation.isOfficial) return;
    await widget.controller.toggleMute(conversation);
    if (!mounted) return;
    final latest = _conversation;
    _toast(latest.isMuted ? 'Chat muted.' : 'Chat unmuted.');
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: InboxLightPremiumTokens.ink,
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final conversation = _conversation;
        final items = _selected == 'Starred' ? _starred : _media;
        return Scaffold(
          backgroundColor: InboxLightPremiumTokens.page,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 26),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: widget.onBackTap,
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: InboxLightPremiumTokens.ink,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: widget.onSearchTap,
                      icon: const Icon(
                        Icons.search_rounded,
                        color: InboxLightPremiumTokens.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: conversation.colors),
                      boxShadow: [
                        BoxShadow(
                          color: conversation.colors.first.withValues(
                            alpha: 0.28,
                          ),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        conversation.avatarText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  conversation.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: InboxLightPremiumTokens.ink,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  conversation.safePresenceText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: InboxLightPremiumTokens.muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _InfoAction(
                        icon: Icons.search_rounded,
                        label: 'Search',
                        onTap: widget.onSearchTap,
                      ),
                    ),
                    if (!conversation.isOfficial) ...[
                      const SizedBox(width: 9),
                      Expanded(
                        child: _InfoAction(
                          icon: Icons.call_rounded,
                          label: 'Call',
                          onTap: _openCallSheet,
                        ),
                      ),
                    ],
                    const SizedBox(width: 9),
                    Expanded(
                      child: _InfoAction(
                        icon: Icons.wallpaper_rounded,
                        label: 'Theme',
                        onTap: widget.onThemeTap,
                      ),
                    ),
                    if (!conversation.isOfficial) ...[
                      const SizedBox(width: 9),
                      Expanded(
                        child: _InfoAction(
                          icon: conversation.isMuted
                              ? Icons.notifications_active_rounded
                              : Icons.notifications_off_rounded,
                          label: conversation.isMuted ? 'Unmute' : 'Mute',
                          onTap: () => unawaited(_toggleMute()),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                _InfoCard(
                  child: Column(
                    children: [
                      _InfoRow(
                        label: 'Chat lock',
                        value: conversation.isLockedByBackend
                            ? 'Enabled'
                            : 'Off',
                        icon: Icons.lock_rounded,
                      ),
                      const Divider(color: InboxLightPremiumTokens.warmBorder),
                      _InfoRow(
                        label: 'Secret Drift',
                        value: conversation.secretDriftEnabled ? 'On' : 'Off',
                        icon: Icons.auto_awesome_rounded,
                      ),
                      const Divider(color: InboxLightPremiumTokens.warmBorder),
                      _InfoRow(
                        label: 'Chat streak',
                        value: conversation.hasChatStreak
                            ? '${conversation.chatStreakCount} day${conversation.chatStreakCount == 1 ? '' : 's'}'
                            : 'No streak yet',
                        icon: Icons.local_fire_department_rounded,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: ['Media', 'Starred'].map((label) {
                    final selected = _selected == label;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          selected: selected,
                          selectedColor: InboxLightPremiumTokens.ink,
                          backgroundColor: Colors.white,
                          side: BorderSide(
                            color: selected
                                ? InboxLightPremiumTokens.ink
                                : InboxLightPremiumTokens.warmBorder,
                          ),
                          label: Center(
                            child: Text(
                              label,
                              style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFF5E4B6F),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          onSelected: (_) => setState(() => _selected = label),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  const _InfoCard(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Text(
                          'Nothing here yet',
                          style: TextStyle(
                            color: InboxLightPremiumTokens.muted,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  ...items.map((message) => _MessageInfoTile(message: message)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InfoAction extends StatelessWidget {
  const _InfoAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: InboxLightPremiumTokens.warmBorder),
      ),
      child: Column(
        children: [
          Icon(icon, color: InboxLightPremiumTokens.violet),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: InboxLightPremiumTokens.ink,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: InboxLightPremiumTokens.warmBorder),
    ),
    child: child,
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Icon(icon, color: InboxLightPremiumTokens.violet, size: 19),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: InboxLightPremiumTokens.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: InboxLightPremiumTokens.muted,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _MessageInfoTile extends StatelessWidget {
  const _MessageInfoTile({required this.message});
  final InboxMessage message;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: InboxLightPremiumTokens.warmBorder),
    ),
    child: Row(
      children: [
        Icon(_icon, color: InboxLightPremiumTokens.violet),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: InboxLightPremiumTokens.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          inboxLocalTimeLabel(message.time),
          style: const TextStyle(
            color: InboxLightPremiumTokens.softMuted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
  IconData get _icon => switch (message.type) {
    InboxMessageType.image => Icons.image_rounded,
    InboxMessageType.voice => Icons.graphic_eq_rounded,
    InboxMessageType.document => Icons.description_rounded,
    _ => Icons.star_rounded,
  };
}
