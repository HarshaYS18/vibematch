import 'package:flutter/material.dart';

import '../../../vibes/data/vibes_report_api_service.dart';
import 'widgets/control_deck_widgets.dart';
import 'widgets/super_power_design.dart';

class VibesReportsReviewPage extends StatefulWidget {
  const VibesReportsReviewPage({super.key});

  @override
  State<VibesReportsReviewPage> createState() => _VibesReportsReviewPageState();
}

class _VibesReportsReviewPageState extends State<VibesReportsReviewPage> {
  final VibesReportApiService _api = const VibesReportApiService();

  static const List<String> _filters = ['PENDING', 'UNDER_REVIEW', 'ACTION_TAKEN', 'REJECTED', 'CLOSED', 'ALL'];

  String _selectedStatus = 'PENDING';
  List<VibeReportQueueItem> _reports = const <VibeReportQueueItem>[];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final reports = await _api.loadReports(status: _selectedStatus, limit: 100);
      if (!mounted) return;
      setState(() => _reports = reports);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reviewReport(VibeReportQueueItem report, {required String status, required bool deletePost}) async {
    final confirmed = await _confirmAction(report, status: status, deletePost: deletePost);
    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    try {
      final result = await _api.reviewReport(
        reportId: report.id,
        status: status,
        deletePost: deletePost,
        note: deletePost ? 'Deleted reported Vibe from control panel.' : 'Reviewed from control panel.',
      );
      if (!mounted) return;
      _toast('Report #${result.id} updated to ${result.status}.');
      await _loadReportsAfterAction();
    } catch (error) {
      if (mounted) _toast(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadReportsAfterAction() async {
    try {
      final reports = await _api.loadReports(status: _selectedStatus, limit: 100);
      if (mounted) setState(() => _reports = reports);
    } catch (_) {}
  }

  Future<bool?> _confirmAction(VibeReportQueueItem report, {required String status, required bool deletePost}) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmReportActionSheet(report: report, status: status, deletePost: deletePost),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: SuperPowerDesign.obsidian, content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SuperPowerDesign.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: SuperPowerDesign.gold,
          onRefresh: _loadReports,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: SuperPowerDesign.glowShell(radius: 24),
                    child: Row(
                      children: [
                        _RoundIcon(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Vibes Reports Queue', style: TextStyle(color: SuperPowerDesign.text, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                              Text('CS / Monitor / Owner report review and action panel', style: TextStyle(color: SuperPowerDesign.muted, fontSize: 11, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                        if (_loading) const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(color: SuperPowerDesign.gold, strokeWidth: 2)) else _RoundIcon(icon: Icons.refresh_rounded, onTap: _loadReports),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 47,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      final item = _filters[index];
                      final selected = item == _selectedStatus;
                      return InkWell(
                        onTap: () {
                          if (selected) return;
                          setState(() => _selectedStatus = item);
                          _loadReports();
                        },
                        borderRadius: BorderRadius.circular(999),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: selected ? SuperPowerDesign.gold : SuperPowerDesign.panel,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: selected ? SuperPowerDesign.gold : SuperPowerDesign.stroke),
                          ),
                          child: Center(child: Text(item, style: TextStyle(color: selected ? SuperPowerDesign.obsidian : SuperPowerDesign.text, fontSize: 11, fontWeight: FontWeight.w900))),
                        ),
                      );
                    },
                    separatorBuilder: (_, _) => const SizedBox(width: 7),
                    itemCount: _filters.length,
                  ),
                ),
              ),
              if (_error != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: _ErrorCard(message: _error!, onRetry: _loadReports),
                  ),
                ),
              if (_reports.isEmpty && !_loading)
                const SliverFillRemaining(hasScrollBody: false, child: _EmptyReports())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  sliver: SliverList.separated(
                    itemCount: _reports.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final report = _reports[index];
                      return _ReportCard(
                        report: report,
                        onUnderReview: () => _reviewReport(report, status: 'UNDER_REVIEW', deletePost: false),
                        onReject: () => _reviewReport(report, status: 'REJECTED', deletePost: false),
                        onClose: () => _reviewReport(report, status: 'CLOSED', deletePost: false),
                        onDeletePost: () => _reviewReport(report, status: 'ACTION_TAKEN', deletePost: true),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.onUnderReview, required this.onReject, required this.onClose, required this.onDeletePost});

  final VibeReportQueueItem report;
  final VoidCallback onUnderReview;
  final VoidCallback onReject;
  final VoidCallback onClose;
  final VoidCallback onDeletePost;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (report.status) {
      'PENDING' => SuperPowerDesign.gold,
      'UNDER_REVIEW' => SuperPowerDesign.aqua,
      'ACTION_TAKEN' => SuperPowerDesign.mint,
      'REJECTED' => SuperPowerDesign.rose,
      _ => SuperPowerDesign.muted,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: SuperPowerDesign.panel, borderRadius: BorderRadius.circular(22), border: Border.all(color: statusColor.withValues(alpha: 0.42)), boxShadow: [BoxShadow(color: statusColor.withValues(alpha: 0.05), blurRadius: 18, offset: const Offset(0, 8))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(15), border: Border.all(color: statusColor.withValues(alpha: 0.32))), child: Icon(Icons.report_rounded, color: statusColor, size: 23)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Report #${report.id} • Post #${report.postId}', style: const TextStyle(color: SuperPowerDesign.text, fontSize: 13.2, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(_timeLabel(report.createdAt), style: const TextStyle(color: SuperPowerDesign.muted, fontSize: 10.5, fontWeight: FontWeight.w700)),
          ])),
          ControlDeckPill(label: report.status, color: statusColor),
        ]),
        const SizedBox(height: 10),
        _UserLine(label: 'Reporter', user: report.reporter, color: SuperPowerDesign.aqua),
        const SizedBox(height: 7),
        _UserLine(label: 'Post Author', user: report.postAuthor, color: SuperPowerDesign.gold),
        const SizedBox(height: 10),
        _InfoBox(icon: Icons.warning_rounded, title: report.reason, body: report.details?.trim().isNotEmpty == true ? report.details! : 'No extra details submitted.'),
        const SizedBox(height: 8),
        _InfoBox(icon: Icons.article_rounded, title: '${report.postMediaType.toUpperCase()} Vibe', body: report.postCaption),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ActionChipButton(label: 'Review', icon: Icons.visibility_rounded, color: SuperPowerDesign.aqua, onTap: onUnderReview),
            _ActionChipButton(label: 'Reject', icon: Icons.close_rounded, color: SuperPowerDesign.rose, onTap: onReject),
            _ActionChipButton(label: 'Close', icon: Icons.check_circle_rounded, color: SuperPowerDesign.mint, onTap: onClose),
            _ActionChipButton(label: 'Delete Vibe', icon: Icons.delete_rounded, color: SuperPowerDesign.rose, onTap: onDeletePost),
          ],
        ),
      ]),
    );
  }

  String _timeLabel(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _UserLine extends StatelessWidget {
  const _UserLine({required this.label, required this.user, required this.color});

  final String label;
  final VibeReportUser user;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: SuperPowerDesign.obsidian, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.30))),
      child: Row(children: [
        CircleAvatar(radius: 16, backgroundColor: color.withValues(alpha: 0.20), child: Text(user.visibleName.isEmpty ? 'U' : user.visibleName[0].toUpperCase(), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900))),
        const SizedBox(width: 9),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: SuperPowerDesign.muted, fontSize: 10, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text('${user.visibleName} • ${user.publicUserId}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SuperPowerDesign.text, fontSize: 12, fontWeight: FontWeight.w900)),
        ])),
      ]),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: SuperPowerDesign.obsidian, borderRadius: BorderRadius.circular(16), border: Border.all(color: SuperPowerDesign.stroke)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: SuperPowerDesign.gold, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: SuperPowerDesign.text, fontSize: 12, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(body.isEmpty ? 'No content.' : body, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SuperPowerDesign.muted, fontSize: 11, height: 1.25, fontWeight: FontWeight.w700)),
        ])),
      ]),
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  const _ActionChipButton({required this.label, required this.icon, required this.color, required this.onTap});

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withValues(alpha: 0.42))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w900)),
        ]),
      ),
    );
  }
}

class _ConfirmReportActionSheet extends StatelessWidget {
  const _ConfirmReportActionSheet({required this.report, required this.status, required this.deletePost});

  final VibeReportQueueItem report;
  final String status;
  final bool deletePost;

  @override
  Widget build(BuildContext context) {
    final color = deletePost ? SuperPowerDesign.rose : SuperPowerDesign.gold;
    return Container(
      margin: const EdgeInsets.all(14),
      padding: EdgeInsets.fromLTRB(18, 16, 18, 18 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(color: SuperPowerDesign.panel, borderRadius: BorderRadius.circular(30), border: Border.all(color: color.withValues(alpha: 0.35))),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(deletePost ? Icons.delete_forever_rounded : Icons.fact_check_rounded, color: color, size: 40),
          const SizedBox(height: 12),
          Text(deletePost ? 'Delete reported Vibe?' : 'Update report status?', style: const TextStyle(color: SuperPowerDesign.text, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('Report #${report.id} will be set to $status.${deletePost ? ' The Vibe will be hidden from feed.' : ''}', textAlign: TextAlign.center, style: const TextStyle(color: SuperPowerDesign.muted, fontSize: 12, height: 1.35, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel'))),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: deletePost ? Colors.white : SuperPowerDesign.obsidian), onPressed: () => Navigator.pop(context, true), child: Text(deletePost ? 'Delete' : 'Confirm'))),
          ]),
        ]),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: SuperPowerDesign.panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: SuperPowerDesign.rose.withValues(alpha: 0.40))),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: SuperPowerDesign.rose),
        const SizedBox(width: 9),
        Expanded(child: Text(message, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SuperPowerDesign.text, fontSize: 11.5, fontWeight: FontWeight.w800))),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ]),
    );
  }
}

class _EmptyReports extends StatelessWidget {
  const _EmptyReports();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('No Vibes reports in this queue.', style: TextStyle(color: SuperPowerDesign.muted, fontWeight: FontWeight.w800)));
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(width: 38, height: 38, decoration: BoxDecoration(color: SuperPowerDesign.obsidian, shape: BoxShape.circle, border: Border.all(color: SuperPowerDesign.stroke)), child: Icon(icon, color: SuperPowerDesign.text, size: 21)),
    );
  }
}
