import 'package:flutter/material.dart';

class LiveRoomWatchPartyModule extends StatelessWidget {
  const LiveRoomWatchPartyModule({
    super.key,
    required this.active,
    required this.canManage,
    required this.onOpenSettings,
    required this.onEndWatchParty,
  });

  final bool active;
  final bool canManage;
  final VoidCallback onOpenSettings;
  final VoidCallback onEndWatchParty;

  @override
  Widget build(BuildContext context) {
    if (!active) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.smart_display_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Watch Party is active',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton(
              onPressed: onOpenSettings,
              child: const Text('Open'),
            ),
            if (canManage)
              TextButton(
                onPressed: onEndWatchParty,
                child: const Text('End'),
              ),
          ],
        ),
      ),
    );
  }
}
