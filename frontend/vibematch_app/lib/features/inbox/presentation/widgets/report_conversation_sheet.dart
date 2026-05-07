import 'package:flutter/material.dart';

import '../../models/inbox_models.dart';

class ReportConversationSheet extends StatefulWidget {
  const ReportConversationSheet({
    super.key,
    required this.conversation,
    required this.onSubmit,
  });

  final InboxConversation conversation;
  final ValueChanged<String> onSubmit;

  @override
  State<ReportConversationSheet> createState() => _ReportConversationSheetState();
}

class _ReportConversationSheetState extends State<ReportConversationSheet> {
  final TextEditingController _reasonController = TextEditingController();
  String _selectedReason = 'Harassment or abuse';

  static const List<String> _reasons = [
    'Harassment or abuse',
    'Hate or threats',
    'Sexual or vulgar content',
    'Spam or scam',
    'Impersonation',
    'Other safety issue',
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    final note = _reasonController.text.trim();
    final reason = note.isEmpty ? _selectedReason : '$_selectedReason • $note';
    widget.onSubmit(reason);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final snapshot = widget.conversation.messages.length <= 5
        ? widget.conversation.messages
        : widget.conversation.messages.sublist(widget.conversation.messages.length - 5);

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(14),
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.84),
        padding: EdgeInsets.fromLTRB(16, 10, 16, 14 + bottomPadding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0D5CB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Report ${widget.conversation.title}',
                style: const TextStyle(color: Color(0xFF251538), fontSize: 19, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'A snapshot of this conversation will be sent to CS for review. If accepted, CS will escalate it to Monitor team for action.',
                style: TextStyle(color: Color(0xFF7B6A86), fontSize: 12, fontWeight: FontWeight.w700, height: 1.35),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _reasons.map((reason) {
                  final selected = reason == _selectedReason;
                  return InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => setState(() => _selectedReason = reason),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: selected ? const Color(0xFFE84C72) : const Color(0xFFFAF7F1),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: selected ? const Color(0xFFE84C72) : const Color(0xFFECE2D8)),
                      ),
                      child: Text(
                        reason,
                        style: TextStyle(
                          color: selected ? Colors.white : const Color(0xFF251538),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _reasonController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Add note for CS review optional',
                  hintStyle: const TextStyle(color: Color(0xFF9B8CA5), fontWeight: FontWeight.w700),
                  filled: true,
                  fillColor: const Color(0xFFFAF7F1),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFECE2D8))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFECE2D8))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFE84C72))),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Snapshot preview',
                style: TextStyle(color: Color(0xFF251538), fontSize: 14, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F1),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFECE2D8)),
                ),
                child: Column(
                  children: snapshot.map((message) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message.sender,
                            style: const TextStyle(color: Color(0xFF251538), fontSize: 11, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              message.text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE84C72),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.report_rounded),
                  label: const Text('Send report to CS', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
