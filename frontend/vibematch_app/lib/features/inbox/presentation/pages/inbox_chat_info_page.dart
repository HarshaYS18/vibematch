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
  static const _bg = Color(0xFFFAFAFA);
  static const _ink = Color(0xFF111114);
  static const _muted = Color(0xFF71717A);
  static const _line = Color(0xFFEDEDEF);
  static const _blue = Color(0xFF3797F0);

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
      builder: (_) => InboxCallActionSheet(conversation: widget.conversation, callController: _callController),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _ink,
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final conversation = widget.conversation;
    final items = _selected == 'Starred' ? _starred : _media;
    final avatarUrl = conversation.avatarUrl?.trim();

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 26),
          children: [
            Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.onBackTap,
                  icon: const Icon(Icons.arrow_back_rounded, color: _ink, size: 22),
                ),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.onSearchTap,
                  icon: const Icon(Icons.search_rounded, color: _ink, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: const Color(0xFFF1F1F3),
                    backgroundImage: avatarUrl == null || avatarUrl.isEmpty ? null : NetworkImage(avatarUrl),
                    child: avatarUrl == null || avatarUrl.isEmpty
                        ? Text(conversation.avatarText, style: const TextStyle(color: _ink, fontSize: 24, fontWeight: FontWeight.w800))
                        : null,
                  ),
                  if (conversation.isOnline)
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Container(
                        width: 15,
                        height: 15,
                        decoration: BoxDecoration(color: const Color(0xFF22C55E), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                      ),
                    ),
                  if (conversation.isOfficial)
                    Positioned(
                      right: -2,
                      top: 2,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(color: _blue, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                        child: const Icon(Icons.verified_rounded, color: Colors.white, size: 13),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(conversation.title, textAlign: TextAlign.center, style: const TextStyle(color: _ink, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
            const SizedBox(height: 4),
            Text(conversation.safePresenceText, textAlign: TextAlign.center, style: const TextStyle(color: _muted, fontSize: 12.5, fontWeight: FontWeight.w500)),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: _InfoAction(icon: Icons.search_rounded, label: 'Search', onTap: widget.onSearchTap)),
                const SizedBox(width: 9),
                Expanded(child: _InfoAction(icon: Icons.call_rounded, label: 'Call', onTap: _openCallSheet)),
                const SizedBox(width: 9),
                Expanded(child: _InfoAction(icon: Icons.wallpaper_rounded, label: 'Theme', onTap: widget.onThemeTap)),
                const SizedBox(width: 9),
                Expanded(child: _InfoAction(icon: conversation.isMuted ? Icons.notifications_off_rounded : Icons.notifications_none_rounded, label: conversation.isMuted ? 'Muted' : 'Mute', onTap: () => _toast('Use chat options to change mute.'))),
              ],
            ),
            const SizedBox(height: 16),
            _InfoCard(
              child: Column(
                children: [
                  _InfoRow(label: 'Chat lock', value: conversation.isLockedByBackend ? 'On' : 'Off', icon: Icons.lock_outline_rounded),
                  const Divider(height: 1, color: _line, indent: 30),
                  _InfoRow(label: 'Secret Drift', value: conversation.secretDriftEnabled ? 'On' : 'Off', icon: Icons.timer_outlined),
                  const Divider(height: 1, color: _line, indent: 30),
                  _InfoRow(label: 'Chat streak', value: conversation.hasChatStreak ? '${conversation.chatStreakCount} day${conversation.chatStreakCount == 1 ? '' : 's'}' : 'No streak', icon: Icons.local_fire_department_outlined),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SegmentedTabs(
              selected: _selected,
              onChanged: (value) => setState(() => _selected = value),
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: items.isEmpty
                  ? _InfoCard(key: ValueKey('empty-$_selected'), child: _EmptyInfoState(label: _selected == 'Starred' ? 'No starred messages' : 'No media yet'))
                  : Column(key: ValueKey('items-$_selected'), children: items.map((message) => _MessageInfoTile(message: message)).toList()),
            ),
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
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _InboxChatInfoPageState._line)),
          child: Column(children: [Icon(icon, color: _InboxChatInfoPageState._ink, size: 20), const SizedBox(height: 6), Text(label, style: const TextStyle(color: _InboxChatInfoPageState._ink, fontSize: 11.5, fontWeight: FontWeight.w700))]),
        ),
      );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _InboxChatInfoPageState._line)),
        child: child,
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(children: [
          Icon(icon, color: _InboxChatInfoPageState._muted, size: 19),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(color: _InboxChatInfoPageState._ink, fontSize: 13.5, fontWeight: FontWeight.w700))),
          Text(value, style: const TextStyle(color: _InboxChatInfoPageState._muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ]),
      );
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: const Color(0xFFF1F1F3), borderRadius: BorderRadius.circular(999)),
      child: Row(
        children: ['Media', 'Starred'].map((label) {
          final isSelected = selected == label;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onChanged(label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 170),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(color: isSelected ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(999), boxShadow: isSelected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 4))] : null),
                child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: isSelected ? _InboxChatInfoPageState._ink : _InboxChatInfoPageState._muted, fontSize: 12.5, fontWeight: FontWeight.w800)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _EmptyInfoState extends StatelessWidget {
  const _EmptyInfoState({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Container(width: 54, height: 54, decoration: const BoxDecoration(color: Color(0xFFF1F1F3), shape: BoxShape.circle), child: const Icon(Icons.collections_outlined, color: _InboxChatInfoPageState._muted, size: 24)),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(color: _InboxChatInfoPageState._ink, fontSize: 14, fontWeight: FontWeight.w800)),
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
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _InboxChatInfoPageState._line)),
        child: Row(children: [
          Container(width: 38, height: 38, decoration: const BoxDecoration(color: Color(0xFFF1F1F3), shape: BoxShape.circle), child: Icon(_icon, color: _InboxChatInfoPageState._ink, size: 19)),
          const SizedBox(width: 10),
          Expanded(child: Text(message.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _InboxChatInfoPageState._ink, fontSize: 12.8, fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          Text(message.time, style: const TextStyle(color: _InboxChatInfoPageState._muted, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      );

  IconData get _icon => switch (message.type) { InboxMessageType.image => Icons.image_outlined, InboxMessageType.voice => Icons.graphic_eq_rounded, InboxMessageType.document => Icons.description_outlined, _ => Icons.star_rounded };
}
