import 'package:flutter/material.dart';

import 'inbox_motion.dart';

class InboxHeader extends StatelessWidget {
  const InboxHeader({
    super.key,
    required this.unreadCount,
    required this.lockedCount,
    required this.requestCount,
    required this.reportTaskCount,
    required this.totalCount,
    required this.isLoading,
    required this.hasNetworkIssue,
    required this.onSearchTap,
    required this.onSettingsTap,
    required this.onLockedTap,
    required this.onRequestsTap,
    required this.onReportsTap,
  });

  final int unreadCount;
  final int lockedCount;
  final int requestCount;
  final int reportTaskCount;
  final int totalCount;
  final bool isLoading;
  final bool hasNetworkIssue;
  final VoidCallback onSearchTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onLockedTap;
  final VoidCallback onRequestsTap;
  final VoidCallback onReportsTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Inbox',
                      style: TextStyle(
                        color: Color(0xFF21142F),
                        fontSize: 31,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedSwitcher(
                      duration: InboxMotion.quick,
                      child: Text(
                        _summaryText,
                        key: ValueKey<String>(_summaryText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF7B6A86),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _HeaderIconButton(icon: Icons.search_rounded, onTap: onSearchTap),
              const SizedBox(width: 6),
              _HeaderIconButton(
                icon: Icons.lock_rounded,
                onTap: onLockedTap,
                badge: lockedCount,
              ),
              const SizedBox(width: 6),
              _HeaderIconButton(
                icon: Icons.settings_rounded,
                onTap: onSettingsTap,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SignalPill(
                icon: Icons.mark_chat_unread_rounded,
                label: unreadCount == 0
                    ? 'All caught up'
                    : '$unreadCount unread',
                accent: const Color(0xFF7C3AED),
                onTap: onSearchTap,
              ),
              _SignalPill(
                icon: Icons.shield_rounded,
                label: requestCount == 0
                    ? 'No stranger messages'
                    : '$requestCount stranger ${requestCount == 1 ? 'message' : 'messages'}',
                accent: const Color(0xFFFF6F61),
                onTap: onRequestsTap,
              ),
              if (reportTaskCount > 0)
                _SignalPill(
                  icon: Icons.support_agent_rounded,
                  label:
                      '$reportTaskCount support ${reportTaskCount == 1 ? 'case' : 'cases'}',
                  accent: const Color(0xFFC99A3B),
                  onTap: onReportsTap,
                ),
              if (hasNetworkIssue)
                const _StatusPill(
                  icon: Icons.wifi_off_rounded,
                  label: 'Connection needs attention',
                  accent: Color(0xFFE84C72),
                )
              else if (isLoading)
                const _StatusPill(
                  icon: Icons.sync_rounded,
                  label: 'Refreshing',
                  accent: Color(0xFF12C7B7),
                ),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: onLockedTap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFECE2D8)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.keyboard_double_arrow_down_rounded,
                    color: Color(0xFF251538),
                    size: 17,
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      lockedCount == 0
                          ? 'Swipe down for locked chats'
                          : 'Swipe down for $lockedCount locked ${lockedCount == 1 ? 'chat' : 'chats'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF4A2A63),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _summaryText {
    if (totalCount <= 0) return 'Conversations, invites, calls, and updates';
    if (unreadCount <= 0) return '$totalCount conversations in sync';
    return '$totalCount conversations with $unreadCount waiting';
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.white.withValues(alpha: 0.86),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 42,
              height: 42,
              child: Icon(icon, color: const Color(0xFF251538), size: 21),
            ),
          ),
        ),
        if (badge > 0)
          Positioned(right: -1, top: -1, child: _Badge(count: badge)),
      ],
    );
  }
}

class _SignalPill extends StatelessWidget {
  const _SignalPill({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: _PillBody(icon: icon, label: label, accent: accent),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return _PillBody(icon: icon, label: label, accent: accent);
  }
}

class _PillBody extends StatelessWidget {
  const _PillBody({
    required this.icon,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF251538).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent, size: 15),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF251538),
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF4F9A), Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 1.6),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
