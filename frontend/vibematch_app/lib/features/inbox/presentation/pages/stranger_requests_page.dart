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

  static const _bg = Color(0xFFFAFAFA);
  static const _ink = Color(0xFF111114);
  static const _muted = Color(0xFF71717A);
  static const _line = Color(0xFFEDEDEF);
  static const _amber = Color(0xFFF59E0B);

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
                      onPressed: onBackTap ?? () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded, color: _ink, size: 22),
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text(
                        'Message requests',
                        style: TextStyle(color: _ink, fontSize: 23, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                      ),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(color: Color(0xFFFFF7E6), shape: BoxShape.circle),
                      child: const Icon(Icons.shield_outlined, color: _amber, size: 18),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: _muted, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Requests from people you don’t follow back stay here until you open or manage them.',
                        style: TextStyle(color: _muted, fontSize: 12.2, height: 1.35, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (requests.isEmpty)
              const SliverFillRemaining(hasScrollBody: false, child: _RequestsEmptyState())
            else
              SliverList.builder(
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final request = requests[index];
                  return InboxConversationCard(
                    conversation: request,
                    onTap: () => onOpenConversation(request),
                    onLongPress: () => onShowOptions(request),
                  );
                },
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        ),
      ),
    );
  }
}

class _RequestsEmptyState extends StatelessWidget {
  const _RequestsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(color: Color(0xFFFFF7E6), shape: BoxShape.circle),
            child: const Icon(Icons.mark_chat_unread_outlined, color: StrangerRequestsPage._amber, size: 30),
          ),
          const SizedBox(height: 14),
          const Text('No requests', style: TextStyle(color: StrangerRequestsPage._ink, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('New message requests will appear here.', style: TextStyle(color: StrangerRequestsPage._muted, fontSize: 12.5, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
