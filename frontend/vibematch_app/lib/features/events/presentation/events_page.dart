import 'package:flutter/material.dart';

import 'dart:async';

import '../data/events_repository.dart';
import '../models/event_item.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  final EventsRepository _repository = EventsRepository();
  int _selectedIndex = 0;
  List<EventItem> _events = const <EventItem>[];
  List<SocialMissionItem> _missions = const <SocialMissionItem>[];
  bool _loading = true;
  String? _error;

  List<EventItem> get _activeEvents =>
      _events.where((event) => event.isActive).toList()
        ..sort((a, b) => a.endsAt.compareTo(b.endsAt));

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _repository.close();
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repository.fetch(force: force);
      if (!mounted) return;
      setState(() {
        _events = data.events;
        _missions = data.missions;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _claimMission(SocialMissionItem mission) async {
    if (!mission.claimable) return;
    try {
      await _repository.claimMission(mission.id);
      await _load(force: true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  void _selectEvent(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final activeEvents = _activeEvents;

    if (_selectedIndex >= activeEvents.length) {
      _selectedIndex = 0;
    }

    final selectedEvent = activeEvents.isEmpty ? null : activeEvents[_selectedIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: Column(
          children: [
            _EventsHeader(onBackTap: () => Navigator.pop(context)),
            if (activeEvents.isNotEmpty)
              _EventIconStrip(
                events: activeEvents,
                selectedIndex: _selectedIndex,
                onSelected: _selectEvent,
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? _EventsLoadError(
                      message: _error!,
                      onRetry: () => unawaited(_load(force: true)),
                    )
                  : selectedEvent == null
                  ? const _EmptyEventsState()
                  : _SelectedEventDetails(
                      event: selectedEvent,
                      missions: _missions,
                      onClaimMission: (mission) => unawaited(_claimMission(mission)),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventsHeader extends StatelessWidget {
  const _EventsHeader({required this.onBackTap});

  final VoidCallback onBackTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.98),
        border: const Border(bottom: BorderSide(color: Color(0xFFECE2D8))),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF251538).withValues(alpha: 0.055),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onBackTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFECE2D8)),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF251538), size: 20),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Events',
                  style: TextStyle(
                    color: Color(0xFF251538),
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Tap an event icon to view details',
                  style: TextStyle(
                    color: Color(0xFF7B6A86),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.celebration_rounded, color: Color(0xFFE84C72), size: 23),
        ],
      ),
    );
  }
}

class _EventIconStrip extends StatelessWidget {
  const _EventIconStrip({
    required this.events,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<EventItem> events;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      decoration: const BoxDecoration(
        color: Color(0xFFFAF7F1),
        border: Border(bottom: BorderSide(color: Color(0xFFECE2D8))),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        scrollDirection: Axis.horizontal,
        itemCount: events.length,
        separatorBuilder: (_, _) => const SizedBox(width: 11),
        itemBuilder: (context, index) {
          final event = events[index];
          final selected = selectedIndex == index;

          return _EventIconButton(
            event: event,
            selected: selected,
            onTap: () => onSelected(index),
          );
        },
      ),
    );
  }
}

class _EventIconButton extends StatelessWidget {
  const _EventIconButton({
    required this.event,
    required this.selected,
    required this.onTap,
  });

  final EventItem event;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 72,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? const Color(0xFF251538) : const Color(0xFFECE2D8),
            width: selected ? 1.3 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF251538).withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 7),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: event.gradient),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(event.fallbackIcon, color: Colors.white, size: 21),
            ),
            const SizedBox(height: 6),
            Text(
              event.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? const Color(0xFF251538) : const Color(0xFF7B6A86),
                fontSize: 10.3,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedEventDetails extends StatelessWidget {
  const _SelectedEventDetails({
    required this.event,
    required this.missions,
    required this.onClaimMission,
  });

  final EventItem event;
  final List<SocialMissionItem> missions;
  final ValueChanged<SocialMissionItem> onClaimMission;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      children: [
        _EventHero(event: event),
        const SizedBox(height: 12),
        _EventInfoCard(event: event),
        const SizedBox(height: 12),
        _EventRewardsCard(event: event),
        const SizedBox(height: 12),
        _EventActionCard(event: event),
        if (missions.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final mission in missions) ...[
            _SocialMissionCard(
              mission: mission,
              onClaim: () => onClaimMission(mission),
            ),
            const SizedBox(height: 9),
          ],
        ],
      ],
    );
  }
}

class _EventHero extends StatelessWidget {
  const _EventHero({required this.event});

  final EventItem event;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFECE2D8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF251538).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 174,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: event.gradient,
            ),
          ),
          child: event.imageUrl == null
              ? _EventFallbackArt(event: event)
              : Image.network(
                  event.imageUrl!,
                  cacheWidth: (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).round(),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, _, _) => _EventFallbackArt(event: event),
                ),
        ),
      ),
    );
  }
}

class _EventInfoCard extends StatelessWidget {
  const _EventInfoCard({required this.event});

  final EventItem event;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFECE2D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  event.title,
                  style: const TextStyle(
                    color: Color(0xFF251538),
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF12C7B7).withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  event.status,
                  style: const TextStyle(
                    color: Color(0xFF12C7B7),
                    fontSize: 10.8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            event.subtitle,
            style: const TextStyle(
              color: Color(0xFF7B6A86),
              fontSize: 12.8,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventRewardsCard extends StatelessWidget {
  const _EventRewardsCard({required this.event});

  final EventItem event;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFECE2D8)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFC99A3B).withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.card_giftcard_rounded, color: Color(0xFFC99A3B), size: 22),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rewards',
                  style: TextStyle(
                    color: Color(0xFF251538),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  event.rewardText,
                  style: const TextStyle(
                    color: Color(0xFF7B6A86),
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventActionCard extends StatelessWidget {
  const _EventActionCard({required this.event});

  final EventItem event;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF251538),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF251538).withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.white, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${event.title} is live from backend event state. Progress and rewards update without an app release.',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.2,
                height: 1.3,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventFallbackArt extends StatelessWidget {
  const _EventFallbackArt({required this.event});

  final EventItem event;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          right: -20,
          bottom: -32,
          child: Icon(
            event.fallbackIcon,
            size: 128,
            color: Colors.white.withValues(alpha: 0.14),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Text(
              event.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                height: 1.05,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.35,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyEventsState extends StatelessWidget {
  const _EmptyEventsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(22),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFECE2D8)),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy_rounded, color: Color(0xFF8C5CF6), size: 40),
            SizedBox(height: 12),
            Text(
              'No active events',
              style: TextStyle(
                color: Color(0xFF251538),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Active events pushed from the backend will appear here without app updates.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF7B6A86),
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _SocialMissionCard extends StatelessWidget {
  const _SocialMissionCard({required this.mission, required this.onClaim});
  final SocialMissionItem mission;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final denominator = mission.requiredCount <= 0 ? 1 : mission.requiredCount;
    final progress = (mission.progress / denominator).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFECE2D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(mission.title, style: const TextStyle(color: Color(0xFF251538), fontSize: 14, fontWeight: FontWeight.w900))),
            Text('+${mission.rewardCoins} coins', style: const TextStyle(color: Color(0xFFC99A3B), fontSize: 11, fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 5),
          Text(mission.description, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 9),
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 7),
          Row(children: [
            Text('${mission.progress}/${mission.requiredCount}', style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 10.5, fontWeight: FontWeight.w800)),
            const Spacer(),
            TextButton(
              onPressed: mission.claimable ? onClaim : null,
              child: Text(mission.claimed ? 'Claimed' : mission.completed ? 'Claim reward' : 'In progress'),
            ),
          ]),
        ],
      ),
    );
  }
}

class _EventsLoadError extends StatelessWidget {
  const _EventsLoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 38),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
