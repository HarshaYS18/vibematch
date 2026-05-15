import 'package:flutter/material.dart';

import '../../models/vibe_models.dart';

class VibeActionsPillMenu extends StatelessWidget {
  const VibeActionsPillMenu({
    super.key,
    required this.isSelfVibe,
    required this.onDelete,
    required this.onReport,
  });

  final bool isSelfVibe;
  final VoidCallback onDelete;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                behavior: HitTestBehavior.translucent,
              ),
            ),
            Positioned(
              top: 148,
              right: 18,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFECE2D8)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 22, offset: const Offset(0, 10))],
                ),
                child: isSelfVibe
                    ? _PillAction(icon: Icons.delete_outline_rounded, label: 'Delete Vibe', color: const Color(0xFFE84C72), onTap: onDelete)
                    : _PillAction(icon: Icons.report_gmailerrorred_rounded, label: 'Report Vibe', color: const Color(0xFFC99A3B), onTap: onReport),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillAction extends StatelessWidget {
  const _PillAction({required this.icon, required this.label, required this.color, required this.onTap});

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 19),
            const SizedBox(width: 7),
            Text(label, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class ConfirmDeleteVibeSheet extends StatelessWidget {
  const ConfirmDeleteVibeSheet({super.key});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.all(14),
        padding: EdgeInsets.fromLTRB(18, 16, 18, 18 + MediaQuery.paddingOf(context).bottom),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Delete this Vibe?', style: TextStyle(color: Color(0xFF111015), fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('This removes the Vibe from the feed.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF8C8198), fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel'))),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE84C72), foregroundColor: Colors.white), onPressed: () => Navigator.pop(context, true), child: const Text('Delete'))),
              ],
            ),
          ],
        ),
      );
}

class VibeActionsSheet extends StatelessWidget {
  const VibeActionsSheet({
    super.key,
    required this.isSelfVibe,
    required this.onDelete,
    required this.onReport,
  });

  final bool isSelfVibe;
  final VoidCallback onDelete;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(14),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 42, height: 5, decoration: BoxDecoration(color: const Color(0xFFE0D5CB), borderRadius: BorderRadius.circular(999))),
          const SizedBox(height: 14),
          isSelfVibe
              ? _VibeActionTile(icon: Icons.delete_rounded, title: 'Delete Vibe', subtitle: 'Open delete confirmation for your own Vibe.', color: const Color(0xFFE84C72), onTap: onDelete)
              : _VibeActionTile(icon: Icons.report_rounded, title: 'Report Vibe', subtitle: 'Report this Vibe to CS CP for review.', color: const Color(0xFFC99A3B), onTap: onReport),
        ],
      ),
    );
  }
}

class _VibeActionTile extends StatelessWidget {
  const _VibeActionTile({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: const Color(0xFFFAF7F1), borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: color)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Color(0xFF251538), fontSize: 15, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 12, height: 1.25, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF7B6A86)),
          ],
        ),
      ),
    );
  }
}

class ReportReasonSheet extends StatefulWidget {
  const ReportReasonSheet({super.key, required this.vibe});

  final VibeItem vibe;

  @override
  State<ReportReasonSheet> createState() => _ReportReasonSheetState();
}

class _ReportReasonSheetState extends State<ReportReasonSheet> {
  static const List<String> _reasons = [
    'Nudity or sexual content',
    'Harassment or bullying',
    'Hate or abusive content',
    'Violence or dangerous behavior',
    'Spam or scam',
    'Fake identity or impersonation',
    'Other safety issue',
  ];

  String? _selectedReason;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(14),
      padding: EdgeInsets.fromLTRB(18, 12, 18, 18 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 28, offset: const Offset(0, 12))]),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: const Color(0xFFE0D5CB), borderRadius: BorderRadius.circular(999)))),
            const SizedBox(height: 16),
            const Text('Report Vibe', style: TextStyle(color: Color(0xFF251538), fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('Choose a reason for ${widget.vibe.authorName}\'s Vibe.', style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: _reasons.map((reason) {
                    final selected = reason == _selectedReason;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () => setState(() => _selectedReason = reason),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: selected ? const Color(0xFF251538) : const Color(0xFFFAF7F1), borderRadius: BorderRadius.circular(18), border: Border.all(color: selected ? const Color(0xFF251538) : const Color(0xFFECE2D8))),
                          child: Row(
                            children: [
                              Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: selected ? Colors.white : const Color(0xFF8C8198), size: 19),
                              const SizedBox(width: 9),
                              Expanded(child: Text(reason, style: TextStyle(color: selected ? Colors.white : const Color(0xFF251538), fontSize: 12.5, fontWeight: FontWeight.w900))),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(onPressed: _selectedReason == null ? null : () => Navigator.pop(context, _selectedReason), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF251538), foregroundColor: Colors.white), child: const Text('Submit'))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
