import 'package:flutter/material.dart';

import '../data/profile_visitor_repository.dart';

class ProfileVisitorsPage extends StatefulWidget {
  const ProfileVisitorsPage({
    super.key,
    required this.profileOwnerUserId,
  });

  final int profileOwnerUserId;

  @override
  State<ProfileVisitorsPage> createState() => _ProfileVisitorsPageState();
}

class _ProfileVisitorsPageState extends State<ProfileVisitorsPage> {
  List<ProfileVisitorRecord> get _visitors {
    return ProfileVisitorRepository.instance.visitorsForUser(widget.profileOwnerUserId);
  }

  void _showAction(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF251538),
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(
                children: [
                  _RoundButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Visitors',
                          style: TextStyle(
                            color: Color(0xFF251538),
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'People who opened your public profile',
                          style: TextStyle(
                            color: Color(0xFF7B6A86),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _CountPill(count: _visitors.length),
                ],
              ),
            ),
            Expanded(
              child: _visitors.isEmpty
                  ? const _EmptyVisitors()
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
                      itemCount: _visitors.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final visitor = _visitors[index];
                        return _VisitorCard(
                          visitor: visitor,
                          onProfileTap: () => _showAction('${visitor.displayName} public profile will open.'),
                          onMessageTap: () => _showAction('Message ${visitor.displayName} will open.'),
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

class _VisitorCard extends StatelessWidget {
  const _VisitorCard({
    required this.visitor,
    required this.onProfileTap,
    required this.onMessageTap,
  });

  final ProfileVisitorRecord visitor;
  final VoidCallback onProfileTap;
  final VoidCallback onMessageTap;

  @override
  Widget build(BuildContext context) {
    final initial = visitor.displayName.trim().isEmpty ? 'V' : visitor.displayName.trim()[0].toUpperCase();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onProfileTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFECE2D8)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF251538).withValues(alpha: 0.045),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF6D5DF6), Color(0xFFE84C72), Color(0xFFFFD36A)],
                  ),
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visitor.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF251538), fontSize: 15, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID ${visitor.visibleId} • ${visitor.roleLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _timeAgo(visitor.visitedAt),
                      style: const TextStyle(color: Color(0xFF12A99E), fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onMessageTap,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF251538),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF251538).withValues(alpha: 0.16),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
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
      decoration: BoxDecoration(
        color: const Color(0xFFE84C72).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE84C72).withValues(alpha: 0.18)),
      ),
      child: Text(
        '$count',
        style: const TextStyle(color: Color(0xFFE84C72), fontSize: 12, fontWeight: FontWeight.w900),
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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFECE2D8)),
        ),
        child: Icon(icon, color: const Color(0xFF251538), size: 20),
      ),
    );
  }
}

class _EmptyVisitors extends StatelessWidget {
  const _EmptyVisitors();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFECE2D8)),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_rounded, color: Color(0xFFE84C72), size: 42),
            SizedBox(height: 10),
            Text(
              'No visitors yet',
              style: TextStyle(color: Color(0xFF251538), fontSize: 18, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 5),
            Text(
              'When someone opens your public profile, they will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF7B6A86), fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

String _timeAgo(DateTime value) {
  final diff = DateTime.now().difference(value);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hr ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return '${value.day}/${value.month}/${value.year}';
}
