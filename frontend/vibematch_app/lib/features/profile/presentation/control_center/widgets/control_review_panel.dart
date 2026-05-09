import 'package:flutter/material.dart';

import '../control_center_models.dart';
import 'control_deck_widgets.dart';
import 'super_power_design.dart';

class ControlReviewPanel extends StatelessWidget {
  const ControlReviewPanel({
    super.key,
    required this.items,
    required this.onApprove,
    required this.onReject,
  });

  final List<ReviewQueueItem> items;
  final ValueChanged<ReviewQueueItem> onApprove;
  final ValueChanged<ReviewQueueItem> onReject;

  @override
  Widget build(BuildContext context) {
    final pending = items.where((item) => item.status == 'Pending').toList();
    final completed = items.where((item) => item.status != 'Pending').toList();

    return ControlDeckShell(
      title: 'Mapped Review Panel',
      subtitle: 'Each issue shows mapped official, mapping time, issue details, evidence and final action controls.',
      trailing: ControlDeckPill(label: '${pending.length} pending', color: SuperPowerDesign.rose),
      children: [
        if (pending.isEmpty)
          const _ReviewEmpty(label: 'No pending mapped reviews.')
        else
          ...pending.map((item) => _ReviewTaskCard(item: item, onApprove: () => onApprove(item), onReject: () => onReject(item))),
        if (completed.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Completed', style: TextStyle(color: SuperPowerDesign.muted, fontSize: 11, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          ...completed.take(5).map((item) => _CompletedReviewRow(item: item)),
        ],
      ],
    );
  }
}

class _ReviewTaskCard extends StatelessWidget {
  const _ReviewTaskCard({required this.item, required this.onApprove, required this.onReject});

  final ReviewQueueItem item;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final priorityColor = switch (item.priority.toLowerCase()) {
      'urgent' => SuperPowerDesign.rose,
      'high' => SuperPowerDesign.gold,
      'medium' => SuperPowerDesign.aqua,
      _ => SuperPowerDesign.muted,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SuperPowerDesign.obsidian,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: priorityColor.withValues(alpha: 0.42)),
        boxShadow: [BoxShadow(color: priorityColor.withValues(alpha: 0.05), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: priorityColor.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(13), border: Border.all(color: priorityColor.withValues(alpha: 0.36))),
            child: Icon(_iconForType(item.type), color: priorityColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SuperPowerDesign.text, fontSize: 13, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text('${item.type} • user ${item.userId} • room ${item.roomId}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SuperPowerDesign.muted, fontSize: 10.5, fontWeight: FontWeight.w700)),
          ])),
          ControlDeckPill(label: item.priority.toUpperCase(), color: priorityColor),
        ]),
        const SizedBox(height: 10),
        _MappedOfficialLine(item: item),
        const SizedBox(height: 8),
        Text(item.issueDetails, style: const TextStyle(color: SuperPowerDesign.text, fontSize: 11.6, height: 1.32, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: SuperPowerDesign.panelSoft, borderRadius: BorderRadius.circular(14), border: Border.all(color: SuperPowerDesign.stroke)),
          child: Row(children: [
            const Icon(Icons.attachment_rounded, color: SuperPowerDesign.aqua, size: 16),
            const SizedBox(width: 7),
            Expanded(child: Text(item.evidenceLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SuperPowerDesign.muted, fontSize: 10.8, fontWeight: FontWeight.w800))),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _ActionButton(label: 'Reject', icon: Icons.close_rounded, color: SuperPowerDesign.rose, onTap: onReject)),
          const SizedBox(width: 8),
          Expanded(child: _ActionButton(label: 'Accept', icon: Icons.check_rounded, color: SuperPowerDesign.mint, onTap: onApprove)),
        ]),
      ]),
    );
  }

  IconData _iconForType(String type) {
    return switch (type) {
      'custom_theme' => Icons.wallpaper_rounded,
      'dp_review' => Icons.account_circle_rounded,
      'report' => Icons.report_rounded,
      _ => Icons.fact_check_rounded,
    };
  }
}

class _MappedOfficialLine extends StatelessWidget {
  const _MappedOfficialLine({required this.item});

  final ReviewQueueItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: SuperPowerDesign.panelSoft, borderRadius: BorderRadius.circular(14), border: Border.all(color: SuperPowerDesign.stroke)),
      child: Row(children: [
        const Icon(Icons.assignment_ind_rounded, color: SuperPowerDesign.gold, size: 16),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            'Mapped to ${item.mappedOfficialName} • ${item.mappedOfficialRole} • ${_timeAgo(item.mappedAt)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: SuperPowerDesign.text, fontSize: 10.8, fontWeight: FontWeight.w800),
          ),
        ),
      ]),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.icon, required this.color, required this.onTap});

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.45))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900)),
        ]),
      ),
    );
  }
}

class _CompletedReviewRow extends StatelessWidget {
  const _CompletedReviewRow({required this.item});
  final ReviewQueueItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: SuperPowerDesign.obsidian, borderRadius: BorderRadius.circular(15), border: Border.all(color: SuperPowerDesign.stroke)),
      child: Row(children: [
        Expanded(child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SuperPowerDesign.text, fontSize: 11.5, fontWeight: FontWeight.w900))),
        ControlDeckPill(label: item.status.toUpperCase(), color: item.status == 'Approved' ? SuperPowerDesign.mint : SuperPowerDesign.rose),
      ]),
    );
  }
}

class _ReviewEmpty extends StatelessWidget {
  const _ReviewEmpty({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: SuperPowerDesign.obsidian, borderRadius: BorderRadius.circular(16), border: Border.all(color: SuperPowerDesign.stroke)),
      child: Text(label, style: const TextStyle(color: SuperPowerDesign.muted, fontSize: 11.5, fontWeight: FontWeight.w800)),
    );
  }
}
