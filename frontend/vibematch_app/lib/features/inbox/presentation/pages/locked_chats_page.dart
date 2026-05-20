import 'package:flutter/material.dart';

import '../../models/inbox_models.dart';
import '../widgets/inbox_conversation_card.dart';

class LockedChatsPage extends StatelessWidget {
  const LockedChatsPage({
    super.key,
    required this.conversations,
    required this.onOpenConversation,
    required this.onShowOptions,
    required this.onBackTap,
  });

  final List<InboxConversation> conversations;
  final ValueChanged<InboxConversation> onOpenConversation;
  final ValueChanged<InboxConversation> onShowOptions;
  final VoidCallback onBackTap;

  static const _bg = Color(0xFFFAFAFA);
  static const _ink = Color(0xFF111114);
  static const _muted = Color(0xFF71717A);
  static const _line = Color(0xFFEDEDEF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
                child: Row(
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: onBackTap,
                      icon: const Icon(Icons.arrow_back_rounded, color: _ink, size: 22),
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text(
                        'Locked chats',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(color: Color(0xFFF1F1F3), shape: BoxShape.circle),
                      child: const Icon(Icons.lock_outline_rounded, color: _ink, size: 18),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _line),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.visibility_off_outlined, color: _muted, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Locked chats stay hidden from your main Inbox until you unlock this vault.',
                        style: TextStyle(color: _muted, fontSize: 12.2, height: 1.35, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (conversations.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _LockedEmptyState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 28),
                sliver: SliverList.builder(
                  itemCount: conversations.length,
                  itemBuilder: (context, index) {
                    final chat = conversations[index];
                    return InboxConversationCard(
                      conversation: chat,
                      onTap: () => onOpenConversation(chat),
                      onLongPress: () => onShowOptions(chat),
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

class _LockedEmptyState extends StatelessWidget {
  const _LockedEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(color: Color(0xFFF1F1F3), shape: BoxShape.circle),
            child: const Icon(Icons.lock_open_rounded, color: LockedChatsPage._muted, size: 30),
          ),
          const SizedBox(height: 14),
          const Text('No locked chats', style: TextStyle(color: LockedChatsPage._ink, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Lock a chat to keep it inside this vault.', style: TextStyle(color: LockedChatsPage._muted, fontSize: 12.5, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
