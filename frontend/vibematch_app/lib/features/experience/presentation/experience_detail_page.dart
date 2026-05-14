import 'package:flutter/material.dart';

import '../data/experience_api_service.dart';

enum ExperienceDetailKind { sent, received, room }

class ExperienceDetailRouteArgs {
  const ExperienceDetailRouteArgs({
    required this.kind,
    this.publicUserId,
    this.roomId,
    this.roomPublicId,
    this.title,
  });

  final ExperienceDetailKind kind;
  final int? publicUserId;
  final int? roomId;
  final String? roomPublicId;
  final String? title;
}

class ExperienceDetailPage extends StatefulWidget {
  const ExperienceDetailPage({super.key, required this.args});

  final ExperienceDetailRouteArgs args;

  @override
  State<ExperienceDetailPage> createState() => _ExperienceDetailPageState();
}

class _ExperienceDetailPageState extends State<ExperienceDetailPage> {
  final ExperienceApiService _api = const ExperienceApiService();
  ExperienceProfile? _profile;
  RoomExperienceProfile? _roomProfile;
  ExperienceTasks? _tasks;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tasks = await _api.loadTasks();
      if (widget.args.kind == ExperienceDetailKind.room) {
        final roomPublicId = widget.args.roomPublicId?.trim();
        final roomId = widget.args.roomId;
        final room = roomPublicId != null && roomPublicId.isNotEmpty
            ? await _api.loadRoomExperienceByPublicId(roomPublicId)
            : roomId != null
                ? await _api.loadRoomExperience(roomId)
                : throw Exception('Missing room id');
        if (!mounted) return;
        setState(() {
          _roomProfile = room;
          _tasks = tasks;
          _loading = false;
        });
      } else {
        final publicUserId = widget.args.publicUserId;
        final profile = publicUserId == null ? await _api.loadMyExperience() : await _api.loadUserExperienceByPublicId(publicUserId);
        if (!mounted) return;
        setState(() {
          _profile = profile;
          _tasks = tasks;
          _loading = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  ExperienceProgress? get _progress {
    return switch (widget.args.kind) {
      ExperienceDetailKind.sent => _profile?.send,
      ExperienceDetailKind.received => _profile?.receive,
      ExperienceDetailKind.room => _roomProfile?.room,
    };
  }

  List<ExperienceTask> get _visibleTasks {
    final tasks = _tasks;
    if (tasks == null) return const [];
    return switch (widget.args.kind) {
      ExperienceDetailKind.sent => tasks.sendTasks,
      ExperienceDetailKind.received => tasks.receiveTasks,
      ExperienceDetailKind.room => tasks.roomTasks,
    };
  }

  String get _title {
    if (widget.args.title != null) return widget.args.title!;
    return switch (widget.args.kind) {
      ExperienceDetailKind.sent => 'Sent Lv',
      ExperienceDetailKind.received => 'Received Lv',
      ExperienceDetailKind.room => 'Room Lv',
    };
  }

  IconData get _icon {
    return switch (widget.args.kind) {
      ExperienceDetailKind.sent => Icons.north_east_rounded,
      ExperienceDetailKind.received => Icons.favorite_rounded,
      ExperienceDetailKind.room => Icons.auto_awesome_rounded,
    };
  }

  String get _description {
    return switch (widget.args.kind) {
      ExperienceDetailKind.sent => 'Lifetime sender EXP from gifts you send.',
      ExperienceDetailKind.received => 'Lifetime receiver EXP from gifts you receive.',
      ExperienceDetailKind.room => 'Room growth EXP from gifts and room activity.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7F1),
        elevation: 0,
        foregroundColor: const Color(0xFF251538),
        title: Text(_title, style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF12C7B7)))
          : _error != null
              ? _ErrorState(error: _error.toString(), onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  children: [
                    _HeroCard(icon: _icon, title: _title, description: _description, progress: progress),
                    const SizedBox(height: 14),
                    _SectionCard(
                      title: 'EXP details',
                      children: [
                        _MetricRow(label: 'Current level', value: 'Lv ${progress?.level ?? 1}'),
                        _MetricRow(label: 'Total EXP', value: _formatNumber(progress?.totalExp ?? 0)),
                        _MetricRow(label: 'Current level EXP', value: _formatNumber(progress?.expIntoLevel ?? 0)),
                        _MetricRow(label: 'EXP needed next', value: progress?.isMaxLevel == true ? 'Max level' : _formatNumber(progress?.expNeededForNextLevel ?? 0)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _SectionCard(
                      title: 'Tasks',
                      children: [
                        for (final task in _visibleTasks) _TaskTile(task: task),
                      ],
                    ),
                    if ((_tasks?.levelRule ?? '').isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _InfoNote(text: _tasks!.levelRule),
                    ],
                  ],
                ),
    );
  }

  String _formatNumber(int value) {
    if (value >= 1000000000) return '${(value / 1000000000).toStringAsFixed(1)}B';
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return '$value';
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.icon, required this.title, required this.description, required this.progress});

  final IconData icon;
  final String title;
  final String description;
  final ExperienceProgress? progress;

  @override
  Widget build(BuildContext context) {
    final value = progress?.progress ?? 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF251538), Color(0xFF4A2A63)]),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.18), blurRadius: 22, offset: const Offset(0, 12))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: const Color(0xFFFFD166))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(description, style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 12.5, fontWeight: FontWeight.w700)),
          ])),
          Text('Lv ${progress?.level ?? 1}', style: const TextStyle(color: Color(0xFFFFD166), fontSize: 21, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 18),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(value: value, minHeight: 10, backgroundColor: Colors.white.withValues(alpha: 0.12), color: const Color(0xFF12C7B7)),
        ),
        const SizedBox(height: 9),
        Text('${progress?.expIntoLevel ?? 0} / ${progress?.expNeededForNextLevel ?? 1} EXP this level', style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 12, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFECE2D8))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Color(0xFF251538), fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        if (children.isEmpty) const Text('No tasks available yet.', style: TextStyle(color: Color(0xFF7B6A86), fontWeight: FontWeight.w700)) else ...children,
      ]),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 12.5, fontWeight: FontWeight.w800))),
        Text(value, style: const TextStyle(color: Color(0xFF251538), fontSize: 13.5, fontWeight: FontWeight.w900)),
      ]),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task});

  final ExperienceTask task;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFFAF7F1), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFECE2D8))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.task_alt_rounded, color: Color(0xFF12C7B7), size: 20),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(task.title, style: const TextStyle(color: Color(0xFF251538), fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(task.description, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text(task.expRule, style: const TextStyle(color: Color(0xFF4A2A63), fontSize: 11, fontWeight: FontWeight.w900)),
        ])),
      ]),
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF251538).withValues(alpha: 0.06), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: const TextStyle(color: Color(0xFF4A2A63), fontSize: 12, height: 1.35, fontWeight: FontWeight.w800)),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFE84C72), size: 38),
          const SizedBox(height: 10),
          Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF7B6A86), fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ]),
      ),
    );
  }
}
