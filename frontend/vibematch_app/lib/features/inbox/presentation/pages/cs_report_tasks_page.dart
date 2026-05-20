import 'package:flutter/material.dart';

import '../../controllers/inbox_controller.dart';
import '../../models/inbox_models.dart';
import '../widgets/inbox_light_premium_tokens.dart';

class CsReportTasksPage extends StatefulWidget {
  const CsReportTasksPage({
    super.key,
    required this.controller,
    required this.onBackTap,
  });

  final InboxController controller;
  final VoidCallback onBackTap;

  @override
  State<CsReportTasksPage> createState() => _CsReportTasksPageState();
}

class _CsReportTasksPageState extends State<CsReportTasksPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleChanged);
    super.dispose();
  }

  void _handleChanged() {
    if (mounted) setState(() {});
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: InboxLightPremiumTokens.ink,
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      );
  }

  void _openMonitorAction(InboxReportTask task) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MonitorActionSheet(
        task: task,
        onAction: (action) {
          Navigator.pop(context);
          widget.controller.applyMonitorAction(task, action);
          _toast('Monitor action applied: $action');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = widget.controller.reportTasks;

    return Scaffold(
      backgroundColor: InboxLightPremiumTokens.page,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(
                children: [
                  _RoundButton(icon: Icons.arrow_back_rounded, onTap: widget.onBackTap),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CS Report Tasks', style: TextStyle(color: InboxLightPremiumTokens.ink, fontSize: 22, fontWeight: FontWeight.w900)),
                        SizedBox(height: 2),
                        Text('Review reports and escalate valid cases', style: TextStyle(color: InboxLightPremiumTokens.muted, fontSize: 12, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  _CountPill(count: widget.controller.pendingReportTaskCount),
                ],
              ),
            ),
            Expanded(
              child: tasks.isEmpty
                  ? const _EmptyTasks()
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
                      itemCount: tasks.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return _ReportTaskCard(
                          task: task,
                          onReject: task.isPending
                              ? () {
                                  widget.controller.rejectReportTask(task);
                                  _toast('Report rejected. User gets report failed system notification.');
                                }
                              : null,
                          onAccept: task.isPending
                              ? () {
                                  widget.controller.acceptReportTask(task);
                                  _toast('Report accepted and escalated to Monitor team.');
                                }
                              : null,
                          onMonitorAction: task.status == InboxReportStatus.acceptedEscalated
                              ? () => _openMonitorAction(task)
                              : null,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportTaskCard extends StatelessWidget {
  const _ReportTaskCard({
    required this.task,
    required this.onReject,
    required this.onAccept,
    required this.onMonitorAction,
  });

  final InboxReportTask task;
  final VoidCallback? onReject;
  final VoidCallback? onAccept;
  final VoidCallback? onMonitorAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: InboxLightPremiumTokens.warmBorder),
        boxShadow: [BoxShadow(color: InboxLightPremiumTokens.ink.withValues(alpha: 0.045), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _statusColor(task.status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(_statusIcon(task.status), color: _statusColor(task.status), size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Report against ${task.reportedUserName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: InboxLightPremiumTokens.ink, fontSize: 14.5, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(task.status.label, style: TextStyle(color: _statusColor(task.status), fontSize: 11, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Reason: ${task.reason}', style: const TextStyle(color: InboxLightPremiumTokens.muted, fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: InboxLightPremiumTokens.page, borderRadius: BorderRadius.circular(16), border: Border.all(color: InboxLightPremiumTokens.warmBorder)),
            child: Column(
              children: task.snapshot.take(4).map((message) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 58, child: Text(message.sender, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: InboxLightPremiumTokens.ink, fontSize: 10.5, fontWeight: FontWeight.w900))),
                      Expanded(child: Text(message.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: InboxLightPremiumTokens.muted, fontSize: 10.5, fontWeight: FontWeight.w700))),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          if (task.csNote != null || task.monitorAction != null) ...[
            const SizedBox(height: 9),
            Text(task.monitorAction ?? task.csNote!, style: const TextStyle(color: InboxLightPremiumTokens.ink, fontSize: 11.5, fontWeight: FontWeight.w900)),
          ],
          const SizedBox(height: 12),
          if (onReject != null || onAccept != null)
            Row(
              children: [
                Expanded(child: _TaskButton(label: 'Reject', icon: Icons.close_rounded, color: const Color(0xFF8C8198), onTap: onReject)),
                const SizedBox(width: 8),
                Expanded(child: _TaskButton(label: 'Accept', icon: Icons.check_rounded, color: InboxLightPremiumTokens.aqua, onTap: onAccept)),
              ],
            )
          else if (onMonitorAction != null)
            _TaskButton(label: 'Monitor action', icon: Icons.gavel_rounded, color: InboxLightPremiumTokens.danger, onTap: onMonitorAction),
        ],
      ),
    );
  }
}

class _MonitorActionSheet extends StatelessWidget {
  const _MonitorActionSheet({required this.task, required this.onAction});

  final InboxReportTask task;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    const actions = [
      'Warning issued',
      '1 hour mute',
      '1 day ban',
      '1 week ban',
      'Escalated for permanent ban',
    ];

    return Container(
      margin: const EdgeInsets.all(14),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Monitor action for ${task.reportedUserName}', style: const TextStyle(color: InboxLightPremiumTokens.ink, fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          ...actions.map((action) {
            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onAction(action),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(color: InboxLightPremiumTokens.page, borderRadius: BorderRadius.circular(16), border: Border.all(color: InboxLightPremiumTokens.warmBorder)),
                child: Text(action, style: const TextStyle(color: InboxLightPremiumTokens.ink, fontSize: 13, fontWeight: FontWeight.w900)),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TaskButton extends StatelessWidget {
  const _TaskButton({required this.label, required this.icon, required this.color, required this.onTap});

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: Container(
          height: 42,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.22))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: InboxLightPremiumTokens.warmBorder)),
        child: Icon(icon, color: InboxLightPremiumTokens.ink, size: 20),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(color: InboxLightPremiumTokens.danger.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999), border: Border.all(color: InboxLightPremiumTokens.danger.withValues(alpha: 0.18))),
      child: Text('$count', style: const TextStyle(color: InboxLightPremiumTokens.danger, fontSize: 12, fontWeight: FontWeight.w900)),
    );
  }
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('No report tasks yet', style: TextStyle(color: InboxLightPremiumTokens.muted, fontSize: 14, fontWeight: FontWeight.w800)),
    );
  }
}

Color _statusColor(InboxReportStatus status) {
  switch (status) {
    case InboxReportStatus.pendingCsReview:
      return InboxLightPremiumTokens.gold;
    case InboxReportStatus.rejectedByCs:
      return const Color(0xFF8C8198);
    case InboxReportStatus.acceptedEscalated:
      return InboxLightPremiumTokens.aqua;
    case InboxReportStatus.monitorActionTaken:
      return InboxLightPremiumTokens.danger;
  }
}

IconData _statusIcon(InboxReportStatus status) {
  switch (status) {
    case InboxReportStatus.pendingCsReview:
      return Icons.support_agent_rounded;
    case InboxReportStatus.rejectedByCs:
      return Icons.cancel_rounded;
    case InboxReportStatus.acceptedEscalated:
      return Icons.verified_rounded;
    case InboxReportStatus.monitorActionTaken:
      return Icons.gavel_rounded;
  }
}
