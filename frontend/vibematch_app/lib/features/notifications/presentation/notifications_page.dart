import 'dart:async';

import 'package:flutter/material.dart';

import '../../vibes/data/vibes_api_service.dart';
import '../../vibes/presentation/pages/vibe_detail_backend_page.dart';
import '../data/notifications_api_service.dart';
import '../models/notification_item.dart';
import '../models/notification_type.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationsApiService _api = NotificationsApiService();
  final VibesApiService _vibesApi = const VibesApiService();
  NotificationType? _selectedType;
  List<NotificationItem> _items = const <NotificationItem>[];
  bool _loading = true;
  bool _openingTarget = false;
  String? _error;

  List<NotificationItem> get _visibleItems {
    final type = _selectedType;
    if (type == null) return _items;
    return _items.where((item) => item.type == type).toList();
  }

  int _countFor(NotificationType? type) {
    if (type == null) return _items.length;
    return _items.where((item) => item.type == type).length;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadNotifications());
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.loadNotifications(limit: 80);
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _items = const <NotificationItem>[];
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _api.markAllRead();
      await _loadNotifications();
    } catch (error) {
      if (mounted) _toast(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _openNotification(NotificationItem item) async {
    if (_openingTarget) return;
    if (item.isUnread) {
      unawaited(_api.markRead(item.id));
      setState(() {
        _items = _items.map((entry) {
          if (entry.id != item.id) return entry;
          return NotificationItem(
            id: entry.id,
            type: entry.type,
            senderName: entry.senderName,
            targetName: entry.targetName,
            title: entry.title,
            body: entry.body,
            vibeTitle: entry.vibeTitle,
            timeAgo: entry.timeAgo,
            isUnread: false,
            targetType: entry.targetType,
            targetId: entry.targetId,
          );
        }).toList(growable: false);
      });
    }

    if (item.targetType == 'vibe' && item.targetId != null && item.targetId!.trim().isNotEmpty) {
      setState(() => _openingTarget = true);
      try {
        final vibe = await _vibesApi.getVibe(item.targetId!);
        if (!mounted) return;
        await Navigator.push<void>(
          context,
          MaterialPageRoute(builder: (_) => VibeDetailBackendPage(vibe: vibe)),
        );
      } catch (error) {
        if (mounted) _toast(error.toString().replaceFirst('Exception: ', ''));
      } finally {
        if (mounted) setState(() => _openingTarget = false);
      }
      return;
    }
    _toast('Notification opened.');
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF251538), content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800))));
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _visibleItems;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _NotificationsHeader(onBackTap: () => Navigator.pop(context), onMarkAllRead: _items.any((item) => item.isUnread) ? _markAllRead : null),
                _NotificationTypeBar(
                  selectedType: _selectedType,
                  countFor: _countFor,
                  onChanged: (type) => setState(() => _selectedType = type),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadNotifications,
                    color: const Color(0xFF251538),
                    child: _loading
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF251538)))
                        : _error != null
                            ? _NotificationsErrorState(message: _error!, onRetry: _loadNotifications)
                            : visibleItems.isEmpty
                                ? const _EmptyNotificationsState()
                                : ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                                    itemCount: visibleItems.length,
                                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      final item = visibleItems[index];
                                      return _NotificationTile(
                                        item: item,
                                        onTap: () => unawaited(_openNotification(item)),
                                      );
                                    },
                                  ),
                  ),
                ),
              ],
            ),
            if (_openingTarget)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.18),
                  child: const Center(child: CircularProgressIndicator(color: Color(0xFF251538))),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsHeader extends StatelessWidget {
  const _NotificationsHeader({required this.onBackTap, required this.onMarkAllRead});

  final VoidCallback onBackTap;
  final VoidCallback? onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.98),
        border: const Border(bottom: BorderSide(color: Color(0xFFECE2D8))),
        boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.055), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onBackTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: const Color(0xFFECE2D8))),
              child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF251538), size: 20),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Notifications', style: TextStyle(color: Color(0xFF251538), fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
                SizedBox(height: 2),
                Text('Mentions, comments, and room updates', style: TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          if (onMarkAllRead != null)
            TextButton(onPressed: onMarkAllRead, child: const Text('Read all', style: TextStyle(fontWeight: FontWeight.w900)))
          else
            const Icon(Icons.notifications_active_rounded, color: Color(0xFFE84C72), size: 22),
        ],
      ),
    );
  }
}

class _NotificationTypeBar extends StatelessWidget {
  const _NotificationTypeBar({required this.selectedType, required this.countFor, required this.onChanged});

  final NotificationType? selectedType;
  final int Function(NotificationType? type) countFor;
  final ValueChanged<NotificationType?> onChanged;

  @override
  Widget build(BuildContext context) {
    final chips = <_NotificationFilterChipData>[
      const _NotificationFilterChipData(label: 'All', type: null),
      const _NotificationFilterChipData(label: 'All-fans Vibes', type: NotificationType.allVibeMention),
      const _NotificationFilterChipData(label: 'Name Vibes', type: NotificationType.targetedVibeMention),
      const _NotificationFilterChipData(label: 'Name Comments', type: NotificationType.targetedCommentMention),
    ];

    return SizedBox(
      height: 56,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final chip = chips[index];
          final selected = chip.type == selectedType;
          return InkWell(
            onTap: () => onChanged(chip.type),
            borderRadius: BorderRadius.circular(999),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: selected ? const Color(0xFF251538) : Colors.white, borderRadius: BorderRadius.circular(999), border: Border.all(color: selected ? const Color(0xFF251538) : const Color(0xFFECE2D8))),
              child: Center(child: Text('${chip.label} ${countFor(chip.type)}', style: TextStyle(color: selected ? Colors.white : const Color(0xFF7A6B86), fontSize: 12, fontWeight: FontWeight.w900))),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});

  final NotificationItem item;
  final VoidCallback onTap;

  Color get _accentColor {
    switch (item.type) {
      case NotificationType.allVibeMention:
        return const Color(0xFFE84C72);
      case NotificationType.targetedVibeMention:
        return const Color(0xFF8C5CF6);
      case NotificationType.targetedCommentMention:
        return const Color(0xFF12C7B7);
    }
  }

  IconData get _icon {
    switch (item.type) {
      case NotificationType.allVibeMention:
        return Icons.campaign_rounded;
      case NotificationType.targetedVibeMention:
        return Icons.alternate_email_rounded;
      case NotificationType.targetedCommentMention:
        return Icons.mode_comment_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), border: Border.all(color: item.isUnread ? _accentColor.withValues(alpha: 0.36) : const Color(0xFFECE2D8)), boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.035), blurRadius: 14, offset: const Offset(0, 7))]),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: _accentColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)), child: Icon(_icon, color: _accentColor, size: 22)),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF251538), fontSize: 14.2, fontWeight: FontWeight.w900))),
                      const SizedBox(width: 8),
                      Text(item.timeAgo, style: const TextStyle(color: Color(0xFF9B8CA5), fontSize: 10.8, fontWeight: FontWeight.w800)),
                    ]),
                    const SizedBox(height: 4),
                    Text(item.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF7A6B86), fontSize: 12, height: 1.25, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFFFAF7F1), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFECE2D8))),
                      child: Row(children: [
                        Icon(Icons.auto_awesome_rounded, color: _accentColor, size: 14),
                        const SizedBox(width: 6),
                        Expanded(child: Text(item.vibeTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF4A2A63), fontSize: 11.5, fontWeight: FontWeight.w900))),
                        const SizedBox(width: 6),
                        Text(item.type.label, style: TextStyle(color: _accentColor, fontSize: 10.4, fontWeight: FontWeight.w900)),
                      ]),
                    ),
                  ],
                ),
              ),
              if (item.isUnread) ...[
                const SizedBox(width: 8),
                Container(width: 9, height: 9, decoration: const BoxDecoration(color: Color(0xFFE84C72), shape: BoxShape.circle)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationsErrorState extends StatelessWidget {
  const _NotificationsErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Container(
          margin: const EdgeInsets.all(22),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), border: Border.all(color: const Color(0xFFE8C77C))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_rounded, color: Color(0xFFC99A3B), size: 40),
            const SizedBox(height: 12),
            const Text('Could not load notifications', style: TextStyle(color: Color(0xFF251538), fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            FilledButton(onPressed: () => unawaited(onRetry()), child: const Text('Retry')),
          ]),
        ),
      ],
    );
  }
}

class _EmptyNotificationsState extends StatelessWidget {
  const _EmptyNotificationsState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Container(
          margin: const EdgeInsets.all(22),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), border: Border.all(color: const Color(0xFFECE2D8))),
          child: const Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.notifications_none_rounded, color: Color(0xFF8C5CF6), size: 40),
            SizedBox(height: 12),
            Text('No notifications here', style: TextStyle(color: Color(0xFF251538), fontSize: 18, fontWeight: FontWeight.w900)),
            SizedBox(height: 6),
            Text('Real mentions, comments, and room updates will appear here.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF7B6A86), fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w700)),
          ]),
        ),
      ],
    );
  }
}

class _NotificationFilterChipData {
  const _NotificationFilterChipData({required this.label, required this.type});

  final String label;
  final NotificationType? type;
}
