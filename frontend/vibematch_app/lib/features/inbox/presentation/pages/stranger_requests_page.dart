import 'package:flutter/material.dart';

import '../../models/inbox_models.dart';
import '../widgets/inbox_conversation_card.dart';

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
      backgroundColor: const Color(0xFF12091F),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: onBackTap ?? () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stranger Messages',
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Requests from non-mutual users stay separate from friends.',
                          style: TextStyle(color: Color(0xFFB8A8CB), fontSize: 12, fontWeight: FontWeight.w700),
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
                color: const Color(0xFFFFB020).withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFFFB020).withValues(alpha: 0.25)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_rounded, color: Color(0xFFFFD166)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Safety reminder: keep private codes and account details away from strangers.',
                      style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800, height: 1.25),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F5FF),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: requests.isEmpty
                    ? const Center(
                        child: Text(
                          'No stranger requests',
                          style: TextStyle(color: Color(0xFF7B6A86), fontWeight: FontWeight.w800),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 28),
                        itemCount: requests.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
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
