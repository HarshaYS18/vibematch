import 'package:flutter/material.dart';

import '../../models/inbox_models.dart';

class InboxMessageActionResult {
  const InboxMessageActionResult._(this.action, {this.reaction, this.editedText});

  final InboxMessageAction action;
  final String? reaction;
  final String? editedText;

  static const reply = InboxMessageActionResult._(InboxMessageAction.reply);
  static const copy = InboxMessageActionResult._(InboxMessageAction.copy);
  static const star = InboxMessageActionResult._(InboxMessageAction.star);
  static const forward = InboxMessageActionResult._(InboxMessageAction.forward);
  static const unsend = InboxMessageActionResult._(InboxMessageAction.unsend);
  static const removeForMe = InboxMessageActionResult._(InboxMessageAction.removeForMe);
  static const cancel = InboxMessageActionResult._(InboxMessageAction.cancel);

  static InboxMessageActionResult react(String reaction) => InboxMessageActionResult._(InboxMessageAction.react, reaction: reaction);
  static InboxMessageActionResult edit(String text) => InboxMessageActionResult._(InboxMessageAction.edit, editedText: text);
}

enum InboxMessageAction { reply, copy, star, forward, edit, unsend, removeForMe, react, cancel }

Future<InboxMessageActionResult?> showInboxMessageActionSheetV2({
  required BuildContext context,
  required InboxMessage message,
}) {
  return showModalBottomSheet<InboxMessageActionResult>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => InboxMessageActionSheetV2(message: message),
  );
}

class InboxMessageActionSheetV2 extends StatefulWidget {
  const InboxMessageActionSheetV2({super.key, required this.message});

  final InboxMessage message;

  @override
  State<InboxMessageActionSheetV2> createState() => _InboxMessageActionSheetV2State();
}

class _InboxMessageActionSheetV2State extends State<InboxMessageActionSheetV2> {
  static const _ink = Color(0xFF111114);
  static const _muted = Color(0xFF71717A);
  static const _line = Color(0xFFEDEDEF);
  static const _blue = Color(0xFF3797F0);
  static const _red = Color(0xFFEF4444);

  late final TextEditingController _editController;
  bool _editing = false;

  bool get _canEdit => widget.message.isMine && widget.message.type == InboxMessageType.text && widget.message.id != null;
  bool get _canUnsend => widget.message.canUnsend;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.message.text);
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  void _submitEdit() {
    final text = _editController.text.trim();
    if (text.isEmpty || text == widget.message.text.trim()) return;
    Navigator.pop(context, InboxMessageActionResult.edit(text));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: EdgeInsets.fromLTRB(14, 10, 14, 12 + bottom),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 28, offset: const Offset(0, 14))],
        ),
        child: AnimatedSize(duration: const Duration(milliseconds: 180), curve: Curves.easeOutCubic, child: _editing ? _editBody() : _actionBody()),
      ),
    );
  }

  Widget _actionBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: const Color(0xFFD4D4D8), borderRadius: BorderRadius.circular(999)))),
        const SizedBox(height: 12),
        const Text('Message options', style: TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(color: const Color(0xFFF7F7F8), borderRadius: BorderRadius.circular(18)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['❤️', '😂', '😮', '🙏', '🔥', '✨'].map((reaction) {
              return InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => Navigator.pop(context, InboxMessageActionResult.react(reaction)),
                child: Padding(padding: const EdgeInsets.all(8), child: Text(reaction, style: const TextStyle(fontSize: 23))),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        _ActionTile(icon: Icons.reply_rounded, title: 'Reply', onTap: () => Navigator.pop(context, InboxMessageActionResult.reply)),
        _ActionTile(icon: Icons.copy_rounded, title: 'Copy', onTap: () => Navigator.pop(context, InboxMessageActionResult.copy)),
        _ActionTile(icon: widget.message.isStarred ? Icons.star_rounded : Icons.star_border_rounded, title: widget.message.isStarred ? 'Unstar' : 'Star', onTap: () => Navigator.pop(context, InboxMessageActionResult.star)),
        _ActionTile(icon: Icons.shortcut_rounded, title: 'Forward', onTap: () => Navigator.pop(context, InboxMessageActionResult.forward)),
        if (_canEdit) _ActionTile(icon: Icons.edit_rounded, title: 'Edit', onTap: () => setState(() => _editing = true)),
        const Divider(height: 16, color: _line),
        _ActionTile(icon: Icons.remove_circle_outline_rounded, title: 'Remove for me', danger: true, onTap: () => Navigator.pop(context, InboxMessageActionResult.removeForMe)),
        if (_canUnsend) _ActionTile(icon: Icons.undo_rounded, title: 'Unsend for everyone', danger: true, onTap: () => Navigator.pop(context, InboxMessageActionResult.unsend)),
      ],
    );
  }

  Widget _editBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          IconButton(onPressed: () => setState(() => _editing = false), icon: const Icon(Icons.arrow_back_rounded, color: _ink)),
          const Expanded(child: Text('Edit message', style: TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w800))),
          TextButton(onPressed: _submitEdit, child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 8),
        TextField(
          controller: _editController,
          minLines: 1,
          maxLines: 5,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Edit message',
            filled: true,
            fillColor: const Color(0xFFF7F7F8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _blue, width: 1.3)),
          ),
        ),
        const SizedBox(height: 10),
        const Text('Edited messages may show as edited in chat.', style: TextStyle(color: _muted, fontSize: 11.5, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, required this.onTap, this.danger = false});

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? _InboxMessageActionSheetV2State._red : _InboxMessageActionSheetV2State._ink;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        margin: const EdgeInsets.only(bottom: 2),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 13),
          Expanded(child: Text(title, style: TextStyle(color: color, fontSize: 14.2, fontWeight: FontWeight.w700))),
          Icon(Icons.chevron_right_rounded, color: danger ? color.withValues(alpha: 0.72) : _InboxMessageActionSheetV2State._muted, size: 20),
        ]),
      ),
    );
  }
}
