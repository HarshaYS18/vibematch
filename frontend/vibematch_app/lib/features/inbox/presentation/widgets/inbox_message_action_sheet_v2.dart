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
        margin: const EdgeInsets.all(14),
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 30, offset: const Offset(0, 14))],
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
        Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: const Color(0xFFE0D5CB), borderRadius: BorderRadius.circular(999)))),
        const SizedBox(height: 12),
        const Text('Message options', style: TextStyle(color: Color(0xFF251538), fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: ['❤️', '😂', '😮', '🙏', '🔥', '✨'].map((reaction) {
            return InkWell(borderRadius: BorderRadius.circular(999), onTap: () => Navigator.pop(context, InboxMessageActionResult.react(reaction)), child: Padding(padding: const EdgeInsets.all(8), child: Text(reaction, style: const TextStyle(fontSize: 23))));
          }).toList(),
        ),
        const SizedBox(height: 8),
        _ActionTile(icon: Icons.reply_rounded, title: 'Reply', onTap: () => Navigator.pop(context, InboxMessageActionResult.reply)),
        _ActionTile(icon: Icons.copy_rounded, title: 'Copy', onTap: () => Navigator.pop(context, InboxMessageActionResult.copy)),
        _ActionTile(icon: widget.message.isStarred ? Icons.star_rounded : Icons.star_border_rounded, title: widget.message.isStarred ? 'Unstar message' : 'Star message', onTap: () => Navigator.pop(context, InboxMessageActionResult.star)),
        _ActionTile(icon: Icons.shortcut_rounded, title: 'Forward', onTap: () => Navigator.pop(context, InboxMessageActionResult.forward)),
        if (_canEdit) _ActionTile(icon: Icons.edit_rounded, title: 'Edit message', subtitle: 'Allowed only for your text messages within server limit.', onTap: () => setState(() => _editing = true)),
        _ActionTile(icon: Icons.remove_circle_outline_rounded, title: 'Remove for me', subtitle: 'Removes this message only from your Inbox view.', danger: true, onTap: () => Navigator.pop(context, InboxMessageActionResult.removeForMe)),
        if (_canUnsend) _ActionTile(icon: Icons.undo_rounded, title: 'Unsend for everyone', subtitle: 'Uses the server recall window.', danger: true, onTap: () => Navigator.pop(context, InboxMessageActionResult.unsend)),
      ],
    );
  }

  Widget _editBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          IconButton(onPressed: () => setState(() => _editing = false), icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF251538))),
          const Expanded(child: Text('Edit message', style: TextStyle(color: Color(0xFF251538), fontSize: 18, fontWeight: FontWeight.w900))),
          TextButton(onPressed: _submitEdit, child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w900))),
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
            fillColor: const Color(0xFFFAF7F1),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFECE2D8))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFECE2D8))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.4)),
          ),
        ),
        const SizedBox(height: 10),
        const Text('Edits are backend-enforced and may fail if the edit window has expired.', style: TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, required this.onTap, this.subtitle, this.danger = false});

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFE84C72) : const Color(0xFF251538);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(color: danger ? const Color(0xFFFFF1F4) : const Color(0xFFF8F5FF), borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: color, fontSize: 13.5, fontWeight: FontWeight.w900)),
            if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle!, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 10.8, fontWeight: FontWeight.w700))],
          ])),
          Icon(Icons.chevron_right_rounded, color: danger ? color.withValues(alpha: 0.75) : const Color(0xFF9B8CA5)),
        ]),
      ),
    );
  }
}
