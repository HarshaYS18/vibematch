import 'package:flutter/material.dart';

import '../../../../app/app_routes.dart';

class LiveRoomEventCarousel extends StatefulWidget {
  const LiveRoomEventCarousel({super.key});

  @override
  State<LiveRoomEventCarousel> createState() => _LiveRoomEventCarouselState();
}

class _LiveRoomEventCarouselState extends State<LiveRoomEventCarousel> {
  late final PageController _pageController;
  int _page = 0;

  static const List<_RoomEventItem> _events = [
    _RoomEventItem(
      title: 'Love Rocket Week',
      assetPath: 'assets/images/events/love_rocket_week.png',
      icon: Icons.rocket_launch_rounded,
      colors: [Color(0xFFE84C72), Color(0xFFFFC857)],
    ),
    _RoomEventItem(
      title: 'VIP Recharge Bonus',
      assetPath: 'assets/images/events/vip_recharge_bonus.png',
      icon: Icons.workspace_premium_rounded,
      colors: [Color(0xFFFFD166), Color(0xFF7A5CFF)],
    ),
    _RoomEventItem(
      title: 'Room Star Race',
      assetPath: 'assets/images/events/room_star_race.png',
      icon: Icons.emoji_events_rounded,
      colors: [Color(0xFF18C7B7), Color(0xFF5E6DFF)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openEventsPage() {
    Navigator.pushNamed(context, VmRoutes.events);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (value) => setState(() => _page = value),
            itemCount: _events.length,
            itemBuilder: (context, index) {
              final event = _events[index];
              return _MiniEventPng(
                event: event,
                onTap: _openEventsPage,
              );
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: -5,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _events.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: _page == index ? 9 : 4,
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: _page == index ? 0.95 : 0.42),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: _page == index
                        ? [BoxShadow(color: Colors.white.withValues(alpha: 0.34), blurRadius: 6)]
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniEventPng extends StatelessWidget {
  const _MiniEventPng({required this.event, required this.onTap});

  final _RoomEventItem event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: event.colors),
          border: Border.all(color: Colors.white.withValues(alpha: 0.34), width: 1.1),
          boxShadow: [
            BoxShadow(
              color: event.colors.first.withValues(alpha: 0.34),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.16),
              blurRadius: 10,
              spreadRadius: 0.8,
            ),
          ],
        ),
        child: ClipOval(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.24),
                        Colors.white.withValues(alpha: 0.04),
                        Colors.black.withValues(alpha: 0.10),
                      ],
                    ),
                  ),
                ),
              ),
              Image.asset(
                event.assetPath,
                width: 54,
                height: 54,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) => Icon(event.icon, color: Colors.white, size: 28),
              ),
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
    required this.assetPath,
    required this.icon,
    required this.colors,
  });

  final String title;
  final String assetPath;
  final IconData icon;
  final List<Color> colors;
}
