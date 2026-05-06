import 'package:flutter/material.dart';

import '../../models/family_ui_models.dart';
import 'family_redesign_shared.dart';

class FamilyChatSection extends StatelessWidget {
  const FamilyChatSection({
    super.key,
    required this.messages,
    required this.controller,
    required this.onSend,
  });

  final List<FamilyChatUiModel> messages;
  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      decoration: FamilyRedesignDecor.panel(24),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 14, 14, 4),
            child: Row(
              children: [
                Icon(Icons.forum_rounded, color: FamilyRedesignColors.aqua),
                SizedBox(width: 8),
                Text('Family Chat', style: TextStyle(color: FamilyRedesignColors.ink, fontSize: 18, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            reverse: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(14),
            itemCount: messages.length,
            separatorBuilder: (_, _) => const SizedBox(height: 9),
            itemBuilder: (_, index) => _ChatBubble(message: messages[index]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'Message family...',
                      filled: true,
                      fillColor: FamilyRedesignColors.page,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: onSend,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(width: 48, height: 48, decoration: BoxDecoration(color: FamilyRedesignColors.ink, borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.send_rounded, color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final FamilyChatUiModel message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: message.isMine ? FamilyRedesignColors.ink : FamilyRedesignColors.page, borderRadius: BorderRadius.circular(18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.senderName, style: TextStyle(color: message.isMine ? Colors.white : FamilyRedesignColors.ink, fontSize: 12, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(message.message, style: TextStyle(color: message.isMine ? Colors.white.withValues(alpha: 0.88) : FamilyRedesignColors.soft, height: 1.25, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(message.timeLabel, style: TextStyle(color: message.isMine ? Colors.white.withValues(alpha: 0.55) : FamilyRedesignColors.soft, fontSize: 10, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
