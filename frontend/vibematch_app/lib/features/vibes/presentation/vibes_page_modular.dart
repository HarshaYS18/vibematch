import 'dart:async';

import 'package:flutter/material.dart';

import '../../social/widgets/friends_invite_sheet.dart';
import '../controllers/vibes_controller.dart';
import '../models/vibe_models.dart';
import 'pages/create_vibe_page_modular.dart';
import 'pages/vibe_detail_backend_page.dart';
import 'pages/vibes_settings_page.dart';
import 'widgets/vibe_card_modular.dart';

class VibesPage extends StatefulWidget {
  const VibesPage({super.key});

  @override
  State<VibesPage> createState() => _VibesPageState();
}

class _VibesPageState extends State<VibesPage> {
  static const String _mockCurrentUserId = '6922022';

  final VibesController _controller = VibesController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    unawaited(_controller.loadFeed());
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _showAction(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)), behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF251538)));
  }

  bool _isSelfVibe(VibeItem vibe) => vibe.authorId == _mockCurrentUserId;

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VibesSettingsPage(
          whoCanMention: _controller.whoCanMention,
          whoCanComment: _controller.whoCanComment,
          onMentionChanged: (value) => _controller.setWhoCanMention(value),
          onCommentChanged: (value) => _controller.setWhoCanComment(value),
        ),
      ),
    );
  }

  void _openCreateVibe() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateVibePageModular(
          canUseMentionAllToday: _controller.canUseMentionAllToday,
          onPublish: (newVibe) async {
            try {
              await _controller.publishVibe(newVibe);
              if (mounted) _showAction('Vibe published.');
            } catch (error) {
              if (mounted) _showAction(error.toString().replaceFirst('Exception: ', ''));
            }
          },
        ),
      ),
    );
  }

  void _openVibeDetail(VibeItem vibe) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VibeDetailBackendPage(
          vibe: vibe,
          onCommentAdded: () => _controller.incrementCommentCount(vibe),
          onDeleteVibe: () => _controller.deleteVibe(vibe),
        ),
      ),
    );
  }

  void _openShareSheet(VibeItem vibe) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (_) => FriendsInviteSheet(
        title: 'Share ${vibe.authorName}\'s Vibe',
        actionLabel: 'Send',
        completedLabel: 'Sent',
        onInvite: (friend) async {
          try {
            final publicUserId = int.tryParse(friend.id);
            await _controller.shareVibe(vibe, targetPublicUserId: publicUserId);
            if (mounted) _showAction('Vibe sent to ${friend.displayName}');
          } catch (error) {
            if (mounted) _showAction(error.toString().replaceFirst('Exception: ', ''));
          }
        },
      ),
    );
  }

  void _openVibeActions(VibeItem vibe) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _VibeActionsSheet(
        isSelfVibe: _isSelfVibe(vibe),
        onDelete: () {
          Navigator.pop(context);
          _openVibeDetail(vibe);
        },
        onReport: () async {
          Navigator.pop(context);
          final reason = await _openReportReasonSheet(vibe);
          if (reason == null || reason.trim().isEmpty) return;
          try {
            await _controller.reportVibe(vibe, reason: reason);
            if (mounted) _showAction('Report submitted to CS CP for review.');
          } catch (error) {
            if (mounted) _showAction(error.toString().replaceFirst('Exception: ', ''));
          }
        },
      ),
    );
  }

  Future<String?> _openReportReasonSheet(VibeItem vibe) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReportReasonSheet(vibe: vibe),
    );
  }

  Future<void> _toggleLike(VibeItem vibe) async {
    try {
      await _controller.toggleLike(vibe);
    } catch (error) {
      if (mounted) _showAction(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleVibes = _controller.visibleVibes;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF251538),
          onRefresh: () => _controller.loadFeed(),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                  child: Row(
                    children: [
                      const Expanded(child: Text('Vibes', style: TextStyle(color: Color(0xFF251538), fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -0.7))),
                      _RoundIconButton(icon: Icons.refresh_rounded, onTap: () => _controller.loadFeed()),
                      const SizedBox(width: 9),
                      _RoundIconButton(icon: Icons.settings_rounded, onTap: _openSettings),
                    ],
                  ),
                ),
              ),
              if (_controller.isLoading) const SliverToBoxAdapter(child: LinearProgressIndicator(minHeight: 3, color: Color(0xFF12C7B7), backgroundColor: Color(0xFFECE2D8))),
              if (_controller.loadErrorMessage != null) SliverToBoxAdapter(child: _BackendErrorCard(message: _controller.loadErrorMessage!, onRetry: () => _controller.loadFeed())),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 44,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    scrollDirection: Axis.horizontal,
                    itemCount: _controller.filters.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 9),
                    itemBuilder: (context, index) {
                      final filter = _controller.filters[index];
                      final selected = filter == _controller.selectedFilter;
                      return InkWell(
                        onTap: () => _controller.selectFilter(filter),
                        borderRadius: BorderRadius.circular(99),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          decoration: BoxDecoration(color: selected ? const Color(0xFF251538) : Colors.white, borderRadius: BorderRadius.circular(99), border: Border.all(color: selected ? const Color(0xFF251538) : const Color(0xFFECE2D8)), boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: selected ? 0.10 : 0.04), blurRadius: 14, offset: const Offset(0, 7))]),
                          child: Center(child: Text(filter, style: TextStyle(color: selected ? Colors.white : const Color(0xFF7A6B86), fontSize: 13, fontWeight: FontWeight.w900))),
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (visibleVibes.isEmpty && !_controller.isLoading)
                const SliverFillRemaining(hasScrollBody: false, child: _EmptyVibesState())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 116),
                  sliver: SliverList.separated(
                    itemCount: visibleVibes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final vibe = visibleVibes[index];
                      return VibeCardModular(
                        vibe: vibe,
                        onProfileTap: () => _showAction('${vibe.authorName} profile will open.'),
                        onLikeTap: () => _toggleLike(vibe),
                        onCommentTap: () => _openVibeDetail(vibe),
                        onShareTap: () => _openShareSheet(vibe),
                        onMoreTap: () => _openVibeActions(vibe),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: _openCreateVibe, backgroundColor: const Color(0xFF251538), foregroundColor: Colors.white, icon: const Icon(Icons.auto_awesome_rounded), label: const Text('Create Vibe', style: TextStyle(fontWeight: FontWeight.w900))),
    );
  }
}

class _BackendErrorCard extends StatelessWidget {
  const _BackendErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.fromLTRB(18, 0, 18, 12), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE8C77C))), child: Row(children: [const Icon(Icons.wifi_off_rounded, color: Color(0xFFC99A3B), size: 19), const SizedBox(width: 9), Expanded(child: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w800))), TextButton(onPressed: onRetry, child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w900)))]));
}

class _VibeActionsSheet extends StatelessWidget {
  const _VibeActionsSheet({required this.isSelfVibe, required this.onDelete, required this.onReport});
  final bool isSelfVibe;
  final VoidCallback onDelete;
  final VoidCallback onReport;
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.all(14), padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.paddingOf(context).bottom), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 24, offset: const Offset(0, 10))]), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 42, height: 5, decoration: BoxDecoration(color: const Color(0xFFE0D5CB), borderRadius: BorderRadius.circular(999))), const SizedBox(height: 14), isSelfVibe ? _VibeActionTile(icon: Icons.delete_rounded, title: 'Delete Vibe', subtitle: 'Open delete confirmation for your own Vibe.', color: const Color(0xFFE84C72), onTap: onDelete) : _VibeActionTile(icon: Icons.report_rounded, title: 'Report Vibe', subtitle: 'Report this Vibe to CS CP for review.', color: const Color(0xFFC99A3B), onTap: onReport)]));
}

class _VibeActionTile extends StatelessWidget {
  const _VibeActionTile({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: const Color(0xFFFAF7F1), borderRadius: BorderRadius.circular(20)), child: Row(children: [Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: color)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Color(0xFF251538), fontSize: 15, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 12, height: 1.25, fontWeight: FontWeight.w700))])), const Icon(Icons.chevron_right_rounded, color: Color(0xFF7B6A86))])));
}

class _ReportReasonSheet extends StatefulWidget {
  const _ReportReasonSheet({required this.vibe});

  final VibeItem vibe;

  @override
  State<_ReportReasonSheet> createState() => _ReportReasonSheetState();
}

class _ReportReasonSheetState extends State<_ReportReasonSheet> {
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

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: Container(width: 42, height: 42, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFECE2D8)), boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.05), blurRadius: 14, offset: const Offset(0, 7))]), child: Icon(icon, color: const Color(0xFF251538))));
}

class _EmptyVibesState extends StatelessWidget {
  const _EmptyVibesState();
  @override
  Widget build(BuildContext context) => const Center(child: Text('No Vibes here yet', style: TextStyle(color: Color(0xFF7B6A86), fontWeight: FontWeight.w800)));
}
