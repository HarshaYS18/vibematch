import 'package:flutter/material.dart';

import 'room_theme.dart';

class LiveRoomEventCarousel extends StatelessWidget {
  const LiveRoomEventCarousel({super.key});

  static const List<_RoomEventItem> _events = [
    _RoomEventItem(
      title: 'Love Rocket Week',
      subtitle: 'Send gifts • win badge rewards',
      icon: Icons.rocket_launch_rounded,
      colors: [Color(0xFFE84C72), Color(0xFFFFC857)],
    ),
    _RoomEventItem(
      title: 'VIP Recharge Bonus',
      subtitle: 'Extra sparkle rewards live now',
      icon: Icons.workspace_premium_rounded,
      colors: [Color(0xFFFFD166), Color(0xFF7A5CFF)],
    ),
    _RoomEventItem(
      title: 'Room Star Race',
      subtitle: 'Top rooms unlock frames',
      icon: Icons.emoji_events_rounded,
      colors: [Color(0xFF18C7B7), Color(0xFF5E6DFF)],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: _events.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final event = _events[index];
          return _MiniEventCard(
            event: event,
            onTap: () => _openEventMock(context, event),
          );
        },
      ),
    );
  }

  void _openEventMock(BuildContext context, _RoomEventItem event) {
    RoomToast.show(context, '${event.title} event page will open here');
  }
}

class _MiniEventCard extends StatelessWidget {
  const _MiniEventCard({required this.event, required this.onTap});

  final _RoomEventItem event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 176,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                event.colors.first.withValues(alpha: 0.72),
                event.colors.last.withValues(alpha: 0.54),
                Colors.white.withValues(alpha: 0.10),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
            boxShadow: [
              BoxShadow(
                color: event.colors.first.withValues(alpha: 0.18),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
                ),
                child: Icon(event.icon, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.3,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      event.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 9.2,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomEventItem {
  const _RoomEventItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
}
