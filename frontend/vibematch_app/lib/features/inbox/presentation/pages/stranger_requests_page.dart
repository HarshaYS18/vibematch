import 'package:flutter/material.dart';

import '../../models/inbox_models.dart';
import '../widgets/inbox_conversation_card.dart';
import '../widgets/inbox_light_premium_tokens.dart';

class StrangerRequestsPage extends StatelessWidget {
  const StrangerRequestsPage({
    super.key,
    required this.requests,
    required this.onOpenConversation,
    required this.onShowOptions,
    this.onBackTap,
  });

  final List<InboxConversation> requests;
  final ValueChanged<InboxConversation> onOpenConversation;
  final ValueChanged<InboxConversation> onShowOptions;
  final VoidCallback? onBackTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: InboxLightPremiumTokens.page,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: InboxLightPremiumTokens.pageGradient,
              ),
              padding: const EdgeInsets.fromLTRB(8, 10, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: onBackTap ?? () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: InboxLightPremiumTokens.ink,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          InboxLightPremiumTokens.warning,
                          InboxLightPremiumTokens.pink,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(17),
                      boxShadow: [InboxLightPremiumTokens.softShadow(0.05)],
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stranger Messages',
                          style: TextStyle(
                            color: InboxLightPremiumTokens.ink,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Requests from non-mutual users stay separate from friends.',
                          style: TextStyle(
                            color: InboxLightPremiumTokens.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: InboxLightPremiumTokens.warning.withValues(
                    alpha: 0.28,
                  ),
                ),
                boxShadow: [InboxLightPremiumTokens.softShadow(0.035)],
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.shield_rounded,
                    color: InboxLightPremiumTokens.warning,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Safety reminder: keep private codes and account details away from strangers.',
                      style: TextStyle(
                        color: Color(0xFF6A4E18),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: InboxLightPremiumTokens.pearl,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: requests.isEmpty
                    ? const Center(
                        child: Text(
                          'No stranger requests',
                          style: TextStyle(
                            color: InboxLightPremiumTokens.muted,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 28),
                        itemCount: requests.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final request = requests[index];
                          return InboxConversationCard(
                            conversation: request,
                            onTap: () => onOpenConversation(request),
                            onLongPress: () => onShowOptions(request),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
