import 'package:flutter/material.dart';

import '../../controllers/inbox_call_controller.dart';
import '../../models/inbox_models.dart';
import '../widgets/inbox_call_action_sheet.dart';

class InboxChatInfoPage extends StatefulWidget {
  const InboxChatInfoPage({
    super.key,
    required this.conversation,
    required this.onBackTap,
    required this.onSearchTap,
    required this.onThemeTap,
  });

  final InboxConversation conversation;
  final VoidCallback onBackTap;
  final VoidCallback onSearchTap;
  final VoidCallback onThemeTap;

  @override
  State<InboxChatInfoPage> createState() => _InboxChatInfoPageState();
}

class _InboxChatInfoPageState extends State<InboxChatInfoPage> {
  final InboxCallController _callController = InboxCallController();
  String _selected = 'Media';

  List<InboxMessage> get _media => widget.conversation.messages.where((message) => message.type == InboxMessageType.image || message.type == InboxMessageType.voice || message.type == InboxMessageType.document).toList().reversed.toList();
  List<InboxMessage> get _starred => widget.conversation.messages.where((message) => message.isStarred).toList().reversed.toList();

  @override
  void dispose() {
    _callController.dispose();
    super.dispose();
  }

  void _openCallSheet() {
    if (widget.conversation.isOfficial) {
      _toast('Official team chats cannot be called.');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => InboxCallActionSheet(
        conversation: widget.conversation,
        callController: _callController,
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final conversation = widget.conversation;
    final items = _selected == 'Starred' ? _starred : _media;
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 26),
          children: [
            Row(
              children: [
                IconButton(onPressed: widget.onBackTap, icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF251538))),
                const Spacer(),
                IconButton(onPressed: widget.onSearchTap, icon: const Icon(Icons.search_rounded, color: Color(0xFF251538))),
              ],
            ),
            const SizedBox(height: 4),
            Center(
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: conversation.colors), boxShadow: [BoxShadow(color: conversation.colors.first.withValues(alpha: 0.28), blurRadius: 24, offset: const Offset(0, 12))]),
                child: Center(child: Text(conversation.avatarText, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900))),
              ),
            ),
            const SizedBox(height: 12),
            Text(conversation.title, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF251538), fontSize: 23, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
            const SizedBox(height: 4),
            Text(conversation.safePresenceText, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 12.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: _InfoAction(icon: Icons.search_rounded, label: 'Search', onTap: widget.onSearchTap)),
                const SizedBox(width: 9),
                Expanded(child: _InfoAction(icon: Icons.call_rounded, label: 'Call', onTap: _openCallSheet)),
                const SizedBox(width: 9),
                Expanded(child: _InfoAction(icon: Icons.wallpaper_rounded, label: 'Theme', onTap: widget.onThemeTap)),
                const SizedBox(width: 9),
                Expanded(child: _InfoAction(icon: Icons.notifications_off_rounded, label: conversation.isMuted ? 'Muted' : 'Mute', onTap: () => _toast('Mute is controlled from chat options.'))),
              ],
            ),
            const SizedBox(height: 16),
            _InfoCard(
              child: Column(
                children: [
                  _InfoRow(label: 'Chat lock', value: conversation.isLockedByBackend ? 'Enabled' : 'Off', icon: Icons.lock_rounded),
                  const Divider(color: Color(0xFFECE2D8)),
                  _InfoRow(label: 'Secret Drift', value: conversation.secretDriftEnabled ? 'On' : 'Off', icon: Icons.auto_awesome_rounded),
                  const Divider(color: Color(0xFFECE2D8)),
                  _InfoRow(label: 'Chat streak', value: conversation.hasChatStreak ? '${conversation.chatStreakCount} day${conversation.chatStreakCount == 1 ? '' : 's'}' : 'No streak yet', icon: Icons.local_fire_department_rounded),
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
                      selectedColor: const Color(0xFF251538),
                      backgroundColor: Colors.white,
                      side: BorderSide(color: selected ? const Color(0xFF251538) : const Color(0xFFECE2D8)),
                      label: Center(child: Text(label, style: TextStyle(color: selected ? Colors.white : const Color(0xFF5E4B6F), fontWeight: FontWeight.w900))),
                      onSelected: (_) => setState(() => _selected = label),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const _InfoCard(child: Center(child: Padding(padding: EdgeInsets.all(18), child: Text('Nothing here yet', style: TextStyle(color: Color(0xFF7B6A86), fontWeight: FontWeight.w800)))))
            else
              ...items.map((message) => _MessageInfoTile(message: message)),
          ],
        ),
      ),
    );
  }
}

class _InfoAction extends StatelessWidget {
  const _InfoAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFECE2D8))),
          child: Column(children: [Icon(icon, color: const Color(0xFF7C3AED)), const SizedBox(height: 6), Text(label, style: const TextStyle(color: Color(0xFF251538), fontSize: 11.5, fontWeight: FontWeight.w900))]),
        ),
      );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFECE2D8))), child: child);
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [Icon(icon, color: const Color(0xFF7C3AED), size: 19), const SizedBox(width: 10), Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF251538), fontWeight: FontWeight.w900))), Text(value, style: const TextStyle(color: Color(0xFF7B6A86), fontWeight: FontWeight.w800))]),
      );
}

class _MessageInfoTile extends StatelessWidget {
  const _MessageInfoTile({required this.message});
  final InboxMessage message;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFECE2D8))),
        child: Row(children: [Icon(_icon, color: const Color(0xFF7C3AED)), const SizedBox(width: 10), Expanded(child: Text(message.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF251538), fontWeight: FontWeight.w800))), Text(message.time, style: const TextStyle(color: Color(0xFF9B8CA5), fontSize: 11, fontWeight: FontWeight.w800))]),
      );
  IconData get _icon => switch (message.type) { InboxMessageType.image => Icons.image_rounded, InboxMessageType.voice => Icons.graphic_eq_rounded, InboxMessageType.document => Icons.description_rounded, _ => Icons.star_rounded };
}
