import 'package:flutter/material.dart';

import '../../controllers/inbox_controller.dart';
import '../../models/inbox_models.dart';

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
  static const _bg = Color(0xFFFAFAFA);
  static const _ink = Color(0xFF111114);
  static const _muted = Color(0xFF71717A);
  static const _line = Color(0xFFEDEDEF);
  static const _blue = Color(0xFF3797F0);

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
      ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: _ink, content: Text(message, style: const TextStyle(fontWeight: FontWeight.w700))));
  }

  void _openActionSheet(InboxReportTask task) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskActionSheet(
        task: task,
        onAction: (action) {
          Navigator.pop(context);
          widget.controller.applyMonitorAction(task, action);
          _toast('Action saved.');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = widget.controller.reportTasks;
    final pendingCount = widget.controller.pendingReportTaskCount;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
                child: Row(children: [
                  IconButton(visualDensity: VisualDensity.compact, onPressed: widget.onBackTap, icon: const Icon(Icons.arrow_back_rounded, color: _ink, size: 22)),
                  const SizedBox(width: 4),
                  const Expanded(child: Text('Support tasks', style: TextStyle(color: _ink, fontSize: 23, fontWeight: FontWeight.w800, letterSpacing: -0.5))),
                  _CountPill(count: pendingCount),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)),
                child: const Row(children: [
                  Icon(Icons.support_agent_rounded, color: _blue, size: 18),
                  SizedBox(width: 10),
                  Expanded(child: Text('Review incoming tasks and choose the right next step.', style: TextStyle(color: _muted, fontSize: 12.2, height: 1.35, fontWeight: FontWeight.w500))),
                ]),
              ),
            ),
            if (tasks.isEmpty)
              const SliverFillRemaining(hasScrollBody: false, child: _EmptyTasks())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 26),
                sliver: SliverList.separated(
                  itemCount: tasks.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return _ReportTaskCard(
                      task: task,
                      onClose: task.isPending
                          ? () {
                              widget.controller.rejectReportTask(task);
                              _toast('Task closed.');
                            }
                          : null,
                      onForward: task.isPending
                          ? () {
                              widget.controller.acceptReportTask(task);
                              _toast('Task forwarded.');
                            }
                          : null,
                      onAction: task.status == InboxReportStatus.acceptedEscalated ? () => _openActionSheet(task) : null,
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
    required this.onClose,
    required this.onForward,
    required this.onAction,
  });

  final InboxReportTask task;
  final VoidCallback? onClose;
  final VoidCallback? onForward;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(task.status);

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _CsReportTasksPageState._line),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.035), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.10), shape: BoxShape.circle), child: Icon(_statusIcon(task.status), color: statusColor, size: 20)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(task.reportedUserName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _CsReportTasksPageState._ink, fontSize: 14.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(task.status.label, style: TextStyle(color: statusColor, fontSize: 11.2, fontWeight: FontWeight.w800)),
          ])),
        ]),
        const SizedBox(height: 10),
        Text(task.reason, style: const TextStyle(color: _CsReportTasksPageState._muted, fontSize: 12.2, fontWeight: FontWeight.w600, height: 1.3)),
        if (task.snapshot.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFF7F7F8), borderRadius: BorderRadius.circular(16), border: Border.all(color: _CsReportTasksPageState._line)),
            child: Column(children: task.snapshot.take(4).map((message) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 58, child: Text(message.sender, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _CsReportTasksPageState._ink, fontSize: 10.5, fontWeight: FontWeight.w800))),
                  Expanded(child: Text(message.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _CsReportTasksPageState._muted, fontSize: 10.5, height: 1.25, fontWeight: FontWeight.w500))),
                ]),
              );
            }).toList()),
          ),
        ],
        if (task.csNote != null || task.monitorAction != null) ...[
          const SizedBox(height: 9),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFBFDBFE))),
            child: Text(task.monitorAction ?? task.csNote!, style: const TextStyle(color: Color(0xFF1E3A8A), fontSize: 11.5, height: 1.3, fontWeight: FontWeight.w700)),
          ),
        ],
        const SizedBox(height: 12),
        if (onClose != null || onForward != null)
          Row(children: [
            Expanded(child: _TaskButton(label: 'Close', icon: Icons.close_rounded, color: const Color(0xFF71717A), onTap: onClose)),
            const SizedBox(width: 8),
            Expanded(child: _TaskButton(label: 'Forward', icon: Icons.arrow_forward_rounded, color: _CsReportTasksPageState._blue, onTap: onForward)),
          ])
        else if (onAction != null)
          _TaskButton(label: 'Take action', icon: Icons.task_alt_rounded, color: _CsReportTasksPageState._blue, onTap: onAction),
      ]),
    );
  }
}

class _TaskActionSheet extends StatelessWidget {
  const _TaskActionSheet({required this.task, required this.onAction});

  final InboxReportTask task;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    const actions = ['Warning issued', '1 hour mute', '1 day ban', '1 week ban', 'Escalated for permanent ban'];

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: EdgeInsets.fromLTRB(16, 10, 16, 14 + MediaQuery.paddingOf(context).bottom),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 28, offset: const Offset(0, 14))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: const Color(0xFFD4D4D8), borderRadius: BorderRadius.circular(999)))),
          const SizedBox(height: 14),
          Text(task.reportedUserName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _CsReportTasksPageState._ink, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ...actions.map((action) => InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onAction(action),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(color: const Color(0xFFF7F7F8), borderRadius: BorderRadius.circular(16), border: Border.all(color: _CsReportTasksPageState._line)),
                  child: Text(action, style: const TextStyle(color: _CsReportTasksPageState._ink, fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              )),
        ]),
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
          decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.18))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
          ]),
        ),
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
      decoration: BoxDecoration(color: _CsReportTasksPageState._blue.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999), border: Border.all(color: _CsReportTasksPageState._blue.withValues(alpha: 0.18))),
      child: Text('$count', style: const TextStyle(color: _CsReportTasksPageState._blue, fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.support_agent_rounded, color: _CsReportTasksPageState._muted, size: 34),
        SizedBox(height: 10),
        Text('No support tasks', style: TextStyle(color: _CsReportTasksPageState._ink, fontSize: 16, fontWeight: FontWeight.w800)),
        SizedBox(height: 4),
        Text('New tasks will appear here.', style: TextStyle(color: _CsReportTasksPageState._muted, fontSize: 12.5, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

Color _statusColor(InboxReportStatus status) {
  switch (status) {
    case InboxReportStatus.pendingCsReview:
      return const Color(0xFFF59E0B);
    case InboxReportStatus.rejectedByCs:
      return const Color(0xFF71717A);
    case InboxReportStatus.acceptedEscalated:
      return const Color(0xFF3797F0);
    case InboxReportStatus.monitorActionTaken:
      return const Color(0xFF22C55E);
  }
}

IconData _statusIcon(InboxReportStatus status) {
  switch (status) {
    case InboxReportStatus.pendingCsReview:
      return Icons.support_agent_rounded;
    case InboxReportStatus.rejectedByCs:
      return Icons.cancel_rounded;
    case InboxReportStatus.acceptedEscalated:
      return Icons.arrow_forward_rounded;
    case InboxReportStatus.monitorActionTaken:
      return Icons.task_alt_rounded;
  }
}
