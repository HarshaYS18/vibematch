import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/vibes_api_service.dart';

class VibeReportReviewPage extends StatefulWidget {
  const VibeReportReviewPage({super.key});

  @override
  State<VibeReportReviewPage> createState() => _VibeReportReviewPageState();
}

class _VibeReportReviewPageState extends State<VibeReportReviewPage> {
  final VibesApiService _api = const VibesApiService();
  final List<VibeReportQueueItem> _reports = <VibeReportQueueItem>[];

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadReports());
  }

  Future<void> _loadReports() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final reports = await _api.loadReportQueue(status: 'PENDING', limit: 50);
      if (!mounted) return;
      setState(() {
        _reports
          ..clear()
          ..addAll(reports);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reviewReport(VibeReportQueueItem report, {required bool deletePost}) async {
    final shouldContinue = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReviewConfirmSheet(deletePost: deletePost),
    );
    if (shouldContinue != true || !mounted) return;
    try {
      await _api.reviewReport(
        report.id,
        status: deletePost ? 'ACTION_TAKEN' : 'REJECTED',
        deletePost: deletePost,
      );
      if (!mounted) return;
      setState(() => _reports.removeWhere((item) => item.id == report.id));
      _toast(deletePost ? 'Report action taken. Vibe removed.' : 'Report rejected and closed.');
    } catch (error) {
      if (mounted) _toast(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF111015),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7F1),
        elevation: 0,
        surfaceTintColor: const Color(0xFFFAF7F1),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111015)),
        ),
        title: const Text('Vibe Reports', style: TextStyle(color: Color(0xFF111015), fontSize: 18, fontWeight: FontWeight.w900)),
        actions: [IconButton(onPressed: _loadReports, icon: const Icon(Icons.refresh_rounded, color: Color(0xFF111015)))],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF111015),
          onRefresh: _loadReports,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 26),
            children: [
              const _OfficialReviewNotice(),
              if (_loading) const _LoadingCard(),
              if (_error != null) _ErrorCard(message: _error!, onRetry: _loadReports),
              if (!_loading && _error == null && _reports.isEmpty) const _EmptyReportsCard(),
              ..._reports.map((report) => _ReportCard(
                    report: report,
                    onTakeAction: () => unawaited(_reviewReport(report, deletePost: true)),
                    onReject: () => unawaited(_reviewReport(report, deletePost: false)),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfficialReviewNotice extends StatelessWidget {
  const _OfficialReviewNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFECE2D8))),
      child: const Row(
        children: [
          Icon(Icons.verified_user_rounded, color: Color(0xFF251538), size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Official review queue for CS, Monitor, Admin, Owner and Super Owner teams.',
              style: TextStyle(color: Color(0xFF251538), fontSize: 12.5, height: 1.3, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.onTakeAction, required this.onReject});

  final VibeReportQueueItem report;
  final VoidCallback onTakeAction;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFECE2D8))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFFFF2E2), borderRadius: BorderRadius.circular(999)),
                child: Text(report.status, style: const TextStyle(color: Color(0xFFC27A18), fontSize: 10.5, fontWeight: FontWeight.w900)),
              ),
              const Spacer(),
              Text(report.createdAtText, style: const TextStyle(color: Color(0xFF8C8198), fontSize: 11, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),
          Text('Reported by ${report.reporterName}', style: const TextStyle(color: Color(0xFF111015), fontSize: 13, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('Vibe owner: ${report.postAuthorName}', style: const TextStyle(color: Color(0xFF8C8198), fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(report.reason, style: const TextStyle(color: Color(0xFFE84C72), fontSize: 13.5, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFAF7F1), borderRadius: BorderRadius.circular(16)),
            child: Text(
              report.postCaption.trim().isEmpty ? '[${report.postMediaType} Vibe]' : report.postCaption,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF251538), fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: onReject, child: const Text('Reject'))),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: onTakeAction,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE84C72), foregroundColor: Colors.white),
                  child: const Text('Remove Vibe'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewConfirmSheet extends StatelessWidget {
  const _ReviewConfirmSheet({required this.deletePost});

  final bool deletePost;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(14),
      padding: EdgeInsets.fromLTRB(18, 16, 18, 18 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(deletePost ? 'Remove reported Vibe?' : 'Reject this report?', style: const TextStyle(color: Color(0xFF111015), fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(
            deletePost ? 'This marks the report as action taken and removes the Vibe from public feed.' : 'This closes the report without removing the Vibe.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF8C8198), fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel'))),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: deletePost ? const Color(0xFFE84C72) : const Color(0xFF111015), foregroundColor: Colors.white), child: Text(deletePost ? 'Remove' : 'Reject'))),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(color: Color(0xFF111015))),
      );
}

class _EmptyReportsCard extends StatelessWidget {
  const _EmptyReportsCard();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFECE2D8))),
        child: const Center(
          child: Text('No pending Vibe reports.', style: TextStyle(color: Color(0xFF8C8198), fontWeight: FontWeight.w900)),
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFFFF8E8), borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFC99A3B)),
            const SizedBox(width: 10),
            Expanded(child: Text(message, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF7B6A86), fontWeight: FontWeight.w800))),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
}
