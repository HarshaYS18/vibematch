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
  static const _ink = Color(0xFF111114);
  static const _muted = Color(0xFF71717A);
  static const _line = Color(0xFFEDEDEF);
  static const _accent = Color(0xFFEF4444);

  final TextEditingController _detailsController = TextEditingController();

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
    _detailsController.dispose();
    super.dispose();
  }

  void _submit() {
    final details = _detailsController.text.trim();
    final reason = details.isEmpty ? _selectedReason : '$_selectedReason • $details';
    widget.onSubmit(reason);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final messages = widget.conversation.messages;
    final snapshot = messages.length <= 5 ? messages : messages.sublist(messages.length - 5);

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(8),
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.84),
        padding: EdgeInsets.fromLTRB(16, 10, 16, 14 + bottom),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 28,
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
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4D4D8),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.flag_rounded, color: _accent, size: 21),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Report ${widget.conversation.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Choose a reason and add optional details.',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 12.2,
                            height: 1.3,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Reason',
                style: TextStyle(color: _ink, fontSize: 13.5, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _reasons.map((reason) {
                  final selected = reason == _selectedReason;
                  return InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => setState(() => _selectedReason = reason),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 170),
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? _accent : const Color(0xFFF4F4F5),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: selected ? _accent : _line),
                      ),
                      child: Text(
                        reason,
                        style: TextStyle(
                          color: selected ? Colors.white : _ink,
                          fontSize: 11.7,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _detailsController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Add details optional',
                  hintStyle: const TextStyle(color: _muted, fontWeight: FontWeight.w500),
                  filled: true,
                  fillColor: const Color(0xFFF7F7F8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _accent, width: 1.2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Recent messages',
                style: TextStyle(color: _ink, fontSize: 13.5, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _line),
                ),
                child: snapshot.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          'No messages to preview.',
                          style: TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      )
                    : Column(
                        children: snapshot.map((message) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 7),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 64,
                                  child: Text(
                                    message.sender,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _ink,
                                      fontSize: 10.8,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    message.text,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _muted,
                                      fontSize: 10.8,
                                      height: 1.25,
                                      fontWeight: FontWeight.w500,
                                    ),
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
                child: FilledButton.icon(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.flag_rounded, size: 18),
                  label: const Text('Send report', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
