import 'package:flutter/material.dart';

import '../../models/inbox_models.dart';
import 'inbox_conversation_tile.dart';
import 'inbox_motion.dart';

class InboxConversationList extends StatelessWidget {
  const InboxConversationList({
    super.key,
    required this.conversations,
    required this.remoteActivityFor,
    required this.onOpenConversation,
    required this.onShowOptions,
    required this.onPin,
    required this.onMute,
  });

  final List<InboxConversation> conversations;
  final String? Function(String conversationId) remoteActivityFor;
  final ValueChanged<InboxConversation> onOpenConversation;
  final ValueChanged<InboxConversation> onShowOptions;
  final ValueChanged<InboxConversation> onPin;
  final ValueChanged<InboxConversation> onMute;

  @override
  Widget build(BuildContext context) {
    return SliverList.builder(
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        final conversation = conversations[index];
        return TweenAnimationBuilder<double>(
          key: ValueKey<String>('premium-row-${conversation.id}'),
          tween: Tween<double>(begin: 0, end: 1),
          duration: Duration(
            milliseconds: 190 + (index.clamp(0, 6).toInt() * 22),
          ),
          curve: InboxMotion.curve,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 10 * (1 - value)),
                child: child,
              ),
            );
          },
          child: InboxConversationTile(
            conversation: conversation,
            remoteActivity: remoteActivityFor(conversation.id),
            onTap: () => onOpenConversation(conversation),
            onLongPress: () => onShowOptions(conversation),
            onPin: () => onPin(conversation),
            onMute: () => onMute(conversation),
          ),
        );
      },
    );
  }
}

class InboxConversationSkeletonList extends StatelessWidget {
  const InboxConversationSkeletonList({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverList.builder(
      itemCount: 6,
      itemBuilder: (context, index) => const _SkeletonTile(),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 7),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEDE7F6)),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFFEDE7F6).withValues(alpha: 0.72),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonLine(widthFactor: 0.52, height: 12),
                const SizedBox(height: 11),
                _SkeletonLine(widthFactor: 0.92, height: 10),
                const SizedBox(height: 11),
                _SkeletonLine(widthFactor: 0.34, height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.widthFactor, required this.height});

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFEDE7F6).withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}
