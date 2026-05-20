import 'package:flutter/material.dart';

import '../../models/inbox_models.dart';
import '../widgets/inbox_conversation_card.dart';
import '../widgets/inbox_light_premium_tokens.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: InboxLightPremiumTokens.page,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                child: Row(
                  children: [
                    IconButton(onPressed: onBackTap, icon: const Icon(Icons.arrow_back_rounded)),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Locked Chats',
                        style: TextStyle(
                          color: InboxLightPremiumTokens.ink,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Icon(Icons.lock_rounded, color: InboxLightPremiumTokens.ink),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: InboxLightPremiumTokens.warmBorder),
                ),
                child: const Text(
                  'These chats are hidden from the normal Inbox. This is backend account-level lock, so it follows the account on every device.',
                  style: TextStyle(
                    color: InboxLightPremiumTokens.muted,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (conversations.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'No locked chats',
                    style: TextStyle(color: InboxLightPremiumTokens.muted, fontWeight: FontWeight.w800),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
                sliver: SliverList.separated(
                  itemCount: conversations.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
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
