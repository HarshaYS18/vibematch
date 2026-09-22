import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../watch_party/data/watch_party_repository.dart';
import '../../../../../watch_party/providers/web/ott_provider_definition.dart';
import '../../live_room_models.dart';
import '../../widgets/room_theme.dart';
import 'live_room_ott_watch_party_sheet.dart';
import 'live_room_youtube_watch_party_sheet.dart';

class LiveRoomWatchPartyRouterSheet extends ConsumerStatefulWidget {
  const LiveRoomWatchPartyRouterSheet({
    super.key,
    required this.roomId,
    required this.canManageRoom,
    required this.privacyMode,
  });

  final String roomId;
  final bool canManageRoom;
  final RoomPrivacyMode privacyMode;

  @override
  ConsumerState<LiveRoomWatchPartyRouterSheet> createState() =>
      _LiveRoomWatchPartyRouterSheetState();
}

class _LiveRoomWatchPartyRouterSheetState
    extends ConsumerState<LiveRoomWatchPartyRouterSheet> {
  String? _selectedProviderId;

  @override
  Widget build(BuildContext context) {
    final watchState = ref.watch(watchPartyRepositoryProvider(widget.roomId));
    final session = watchState.session;
    final activeProvider = watchState.active
        ? session?.provider.trim().toLowerCase()
        : null;
    final providerId = activeProvider ?? _selectedProviderId;

    if (providerId == 'youtube') {
      return LiveRoomYoutubeWatchPartySheet(
        roomId: widget.roomId,
        canManageRoom: widget.canManageRoom,
      );
    }

    final ottProvider = providerId == null
        ? null
        : OttProviderCatalog.byId(providerId);
    if (ottProvider != null) {
      return LiveRoomOttWatchPartySheet(
        roomId: widget.roomId,
        canManageRoom: widget.canManageRoom,
        privacyMode: widget.privacyMode,
        provider: ottProvider,
        onBackToProviders: watchState.active
            ? null
            : () => setState(() => _selectedProviderId = null),
      );
    }

    return _ProviderChooser(
      canManageRoom: widget.canManageRoom,
      privateRoom: widget.privacyMode == RoomPrivacyMode.privateVibe,
      activeUnknownProvider: activeProvider,
      onSelectProvider: (providerId) {
        setState(() => _selectedProviderId = providerId);
      },
    );
  }
}

class _ProviderChooser extends StatelessWidget {
  const _ProviderChooser({
    required this.canManageRoom,
    required this.privateRoom,
    required this.activeUnknownProvider,
    required this.onSelectProvider,
  });

  final bool canManageRoom;
  final bool privateRoom;
  final String? activeUnknownProvider;
  final ValueChanged<String> onSelectProvider;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      padding: EdgeInsets.fromLTRB(
        18,
        12,
        18,
        MediaQuery.paddingOf(context).bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            const SizedBox(height: 16),
            const Text(
              'Watch Party',
              style: TextStyle(
                color: RoomColors.plum,
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              activeUnknownProvider == null
                  ? 'Choose what the room should watch together'
                  : 'This Watch Party provider is not available on this build.',
              style: const TextStyle(
                color: Color(0xFF7B6A86),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            if (activeUnknownProvider != null) ...[
              const SizedBox(height: 10),
              Text(
                activeUnknownProvider!,
                style: const TextStyle(
                  color: RoomColors.coral,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
            const SizedBox(height: 18),
            _ProviderChoice(
              icon: Icons.smart_display_rounded,
              title: 'YouTube',
              subtitle: 'Integrated player with room synchronization',
              onTap: () => onSelectProvider('youtube'),
            ),
            const SizedBox(height: 10),
            _ProviderChoice(
              icon: Icons.movie_filter_rounded,
              title: 'Netflix',
              subtitle: privateRoom
                  ? 'Try embedded playback, then companion fallback'
                  : 'Requires a Private Vibe room',
              onTap: () => onSelectProvider('netflix'),
            ),
            const SizedBox(height: 10),
            _ProviderChoice(
              icon: Icons.ondemand_video_rounded,
              title: 'Prime Video',
              subtitle: privateRoom
                  ? 'Try embedded playback, then companion fallback'
                  : 'Requires a Private Vibe room',
              onTap: () => onSelectProvider('prime_video'),
            ),
            const SizedBox(height: 10),
            _ProviderChoice(
              icon: Icons.live_tv_rounded,
              title: 'JioHotstar',
              subtitle: privateRoom
                  ? 'VOD and live timeline synchronization when supported'
                  : 'Requires a Private Vibe room',
              onTap: () => onSelectProvider('jiohotstar'),
            ),
            if (!canManageRoom) ...[
              const SizedBox(height: 16),
              const Text(
                'Only the room host or admin can start a Watch Party. You can join once it starts.',
                style: TextStyle(
                  color: Color(0xFF7B6A86),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ],
            if (!privateRoom) ...[
              const SizedBox(height: 12),
              const _PrivacyNotice(),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProviderChoice extends StatelessWidget {
  const _ProviderChoice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RoomColors.pearl,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: RoomColors.softLine),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: RoomColors.plum.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: RoomColors.plum, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: RoomColors.plum,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF7B6A86),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF8B7C96),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RoomColors.gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: RoomColors.gold.withValues(alpha: 0.30),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_rounded, color: RoomColors.plum, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'OTT Watch Party is server-restricted to Private Vibe invite-only rooms. Each participant signs in with their own provider account.',
              style: TextStyle(
                color: RoomColors.plum,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
