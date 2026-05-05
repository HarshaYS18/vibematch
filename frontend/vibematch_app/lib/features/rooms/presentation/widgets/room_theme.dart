import 'package:flutter/material.dart';

import '../../../../core/icons/vm_icons.dart';

class RoomColors {
  static const deep = Color(0xFF070414);
  static const plum = Color(0xFF251538);
  static const violet = Color(0xFF7A5CFF);
  static const aqua = Color(0xFF12C7B7);
  static const coral = Color(0xFFE84C72);
  static const gold = Color(0xFFFFC857);
  static const pearl = Color(0xFFFAF7F1);
  static const line = Color(0x22FFFFFF);
  static const softLine = Color(0xFFEDE3D7);
  static const adminMute = Color(0xFFFF7A45);
  static const selfMute = Color(0xFF7B8794);
}

enum RoomBackgroundSourceType {
  chatRoom,
  vibeSync,
  vip,
  svip,
  store,
  event,
  customUpload,
}

enum RoomBackgroundUnlockType {
  free,
  vipPermanent,
  svipMonthly,
  storePurchase,
  eventLimited,
  customApproved,
}

enum RoomBackgroundOwnershipType {
  free,
  permanent,
  timeLimited,
  rental,
  subscription,
  eventLimited,
  customApproved,
}

enum RoomBackgroundLockReason {
  none,
  inactive,
  vipLevelRequired,
  vipFrozen,
  svipLevelRequired,
  svipExpired,
  ownershipRequired,
  expired,
  pendingApproval,
  rejected,
}

class RoomBackgroundAccessState {
  const RoomBackgroundAccessState({
    required this.available,
    required this.reason,
    required this.label,
  });

  final bool available;
  final RoomBackgroundLockReason reason;
  final String label;
}

class RoomBackgroundViewerState {
  const RoomBackgroundViewerState({
    this.vipLevel = 0,
    this.vipActive = false,
    this.vipFrozen = false,
    this.svipLevel = 0,
    this.svipActive = false,
    this.ownedThemeIds = const <String>{},
    this.now,
  });

  final int vipLevel;
  final bool vipActive;
  final bool vipFrozen;
  final int svipLevel;
  final bool svipActive;
  final Set<String> ownedThemeIds;
  final DateTime? now;

  DateTime get effectiveNow => now ?? DateTime.now();
}

class RoomBackgroundTheme {
  const RoomBackgroundTheme({
    required this.id,
    required this.name,
    required this.accent,
    this.assetPath,
    this.imageUrl,
    this.thumbnailUrl,
    this.sourceType = RoomBackgroundSourceType.chatRoom,
    this.unlockType = RoomBackgroundUnlockType.free,
    this.ownershipType = RoomBackgroundOwnershipType.free,
    this.requiredVipLevel,
    this.requiredSvipLevel,
    this.requiresActiveVip = false,
    this.requiresActiveSvip = false,
    this.isPermanentUnlock = false,
    this.isRenewable = false,
    this.isDefault = false,
    this.isActive = true,
    this.ownedAt,
    this.expiresAt,
    this.approvalStatus,
    this.overlayOpacity = 0.42,
    this.fallbackColors = const [RoomColors.deep, RoomColors.plum],
  });

  final String id;
  final String name;
  final String? assetPath;
  final String? imageUrl;
  final String? thumbnailUrl;
  final Color accent;
  final RoomBackgroundSourceType sourceType;
  final RoomBackgroundUnlockType unlockType;
  final RoomBackgroundOwnershipType ownershipType;
  final int? requiredVipLevel;
  final int? requiredSvipLevel;
  final bool requiresActiveVip;
  final bool requiresActiveSvip;
  final bool isPermanentUnlock;
  final bool isRenewable;
  final bool isDefault;
  final bool isActive;
  final DateTime? ownedAt;
  final DateTime? expiresAt;
  final String? approvalStatus;
  final double overlayOpacity;
  final List<Color> fallbackColors;

  List<Color> get colors => fallbackColors;

  bool get isAssetBacked => assetPath != null && assetPath!.trim().isNotEmpty;
  bool get isNetworkBacked => imageUrl != null && imageUrl!.trim().isNotEmpty;
  bool get hasThumbnail => thumbnailUrl != null && thumbnailUrl!.trim().isNotEmpty;
  bool get hasExpiry => expiresAt != null;

  bool isExpired([DateTime? now]) {
    final expiry = expiresAt;
    if (expiry == null) return false;
    return (now ?? DateTime.now()).isAfter(expiry);
  }

  RoomBackgroundAccessState accessFor(RoomBackgroundViewerState viewer) {
    final currentNow = viewer.effectiveNow;

    if (!isActive) {
      return const RoomBackgroundAccessState(
        available: false,
        reason: RoomBackgroundLockReason.inactive,
        label: 'Unavailable',
      );
    }

    if (approvalStatus == 'pending') {
      return const RoomBackgroundAccessState(
        available: false,
        reason: RoomBackgroundLockReason.pendingApproval,
        label: 'Pending approval',
      );
    }

    if (approvalStatus == 'rejected') {
      return const RoomBackgroundAccessState(
        available: false,
        reason: RoomBackgroundLockReason.rejected,
        label: 'Rejected',
      );
    }

    if (isExpired(currentNow)) {
      return RoomBackgroundAccessState(
        available: false,
        reason: RoomBackgroundLockReason.expired,
        label: isRenewable ? 'Expired — renew to use' : 'Expired',
      );
    }

    final vipRequired = requiredVipLevel;
    if (vipRequired != null && viewer.vipLevel < vipRequired) {
      return RoomBackgroundAccessState(
        available: false,
        reason: RoomBackgroundLockReason.vipLevelRequired,
        label: 'VIP $vipRequired required',
      );
    }

    if (requiresActiveVip && viewer.vipFrozen) {
      return const RoomBackgroundAccessState(
        available: false,
        reason: RoomBackgroundLockReason.vipFrozen,
        label: 'VIP frozen — reactivate VIP to use',
      );
    }

    if (requiresActiveVip && !viewer.vipActive) {
      return const RoomBackgroundAccessState(
        available: false,
        reason: RoomBackgroundLockReason.vipFrozen,
        label: 'VIP inactive — reactivate VIP to use',
      );
    }

    final svipRequired = requiredSvipLevel;
    if (svipRequired != null && viewer.svipLevel < svipRequired) {
      return RoomBackgroundAccessState(
        available: false,
        reason: RoomBackgroundLockReason.svipLevelRequired,
        label: 'SVIP $svipRequired required',
      );
    }

    if (requiresActiveSvip && !viewer.svipActive) {
      return const RoomBackgroundAccessState(
        available: false,
        reason: RoomBackgroundLockReason.svipExpired,
        label: 'SVIP expired — renew monthly SVIP to use',
      );
    }

    final ownershipRequired = ownershipType != RoomBackgroundOwnershipType.free &&
        unlockType != RoomBackgroundUnlockType.vipPermanent &&
        unlockType != RoomBackgroundUnlockType.svipMonthly &&
        unlockType != RoomBackgroundUnlockType.eventLimited;

    if (ownershipRequired && !viewer.ownedThemeIds.contains(id)) {
      return const RoomBackgroundAccessState(
        available: false,
        reason: RoomBackgroundLockReason.ownershipRequired,
        label: 'Purchase required',
      );
    }

    return const RoomBackgroundAccessState(
      available: true,
      reason: RoomBackgroundLockReason.none,
      label: 'Available',
    );
  }
}

const String roomDefaultBackgroundAssetBase =
    'assets/images/room_backgrounds/chat_room/default';

const RoomBackgroundTheme celestialFallsRoomBackgroundTheme = RoomBackgroundTheme(
  id: 'celestial_falls',
  name: 'Celestial Falls',
  assetPath: '$roomDefaultBackgroundAssetBase/celestial_falls.webp',
  accent: RoomColors.aqua,
  sourceType: RoomBackgroundSourceType.chatRoom,
  unlockType: RoomBackgroundUnlockType.free,
  ownershipType: RoomBackgroundOwnershipType.free,
  isDefault: true,
  overlayOpacity: 0.34,
  fallbackColors: [Color(0xFF07131F), Color(0xFF183953)],
);

const RoomBackgroundTheme moonlitBiolumeShoreRoomBackgroundTheme = RoomBackgroundTheme(
  id: 'moonlit_biolume_shore',
  name: 'Moonlit Biolume Shore',
  assetPath: '$roomDefaultBackgroundAssetBase/moonlit_biolume_shore.webp',
  accent: RoomColors.violet,
  sourceType: RoomBackgroundSourceType.chatRoom,
  unlockType: RoomBackgroundUnlockType.free,
  ownershipType: RoomBackgroundOwnershipType.free,
  isDefault: true,
  overlayOpacity: 0.36,
  fallbackColors: [Color(0xFF050A18), Color(0xFF182C4D)],
);

const RoomBackgroundTheme auroraFrostLakeRoomBackgroundTheme = RoomBackgroundTheme(
  id: 'aurora_frost_lake',
  name: 'Aurora Frost Lake',
  assetPath: '$roomDefaultBackgroundAssetBase/aurora_frost_lake.webp',
  accent: RoomColors.aqua,
  sourceType: RoomBackgroundSourceType.chatRoom,
  unlockType: RoomBackgroundUnlockType.free,
  ownershipType: RoomBackgroundOwnershipType.free,
  isDefault: true,
  overlayOpacity: 0.38,
  fallbackColors: [Color(0xFF07121E), Color(0xFF0D4051)],
);

const RoomBackgroundTheme desertDuskOasisRoomBackgroundTheme = RoomBackgroundTheme(
  id: 'desert_dusk_oasis',
  name: 'Desert Dusk Oasis',
  assetPath: '$roomDefaultBackgroundAssetBase/desert_dusk_oasis.webp',
  accent: RoomColors.gold,
  sourceType: RoomBackgroundSourceType.chatRoom,
  unlockType: RoomBackgroundUnlockType.free,
  ownershipType: RoomBackgroundOwnershipType.free,
  isDefault: true,
  overlayOpacity: 0.40,
  fallbackColors: [Color(0xFF180B10), Color(0xFF4A2538)],
);

const RoomBackgroundTheme alpineTwilightMirrorRoomBackgroundTheme = RoomBackgroundTheme(
  id: 'alpine_twilight_mirror',
  name: 'Alpine Twilight Mirror',
  assetPath: '$roomDefaultBackgroundAssetBase/alpine_twilight_mirror.webp',
  accent: RoomColors.violet,
  sourceType: RoomBackgroundSourceType.chatRoom,
  unlockType: RoomBackgroundUnlockType.free,
  ownershipType: RoomBackgroundOwnershipType.free,
  isDefault: true,
  overlayOpacity: 0.36,
  fallbackColors: [Color(0xFF090B17), Color(0xFF2A1C45)],
);

const RoomBackgroundTheme crimsonCoastBeaconRoomBackgroundTheme = RoomBackgroundTheme(
  id: 'crimson_coast_beacon',
  name: 'Crimson Coast Beacon',
  assetPath: '$roomDefaultBackgroundAssetBase/crimson_coast_beacon.webp',
  accent: RoomColors.coral,
  sourceType: RoomBackgroundSourceType.chatRoom,
  unlockType: RoomBackgroundUnlockType.free,
  ownershipType: RoomBackgroundOwnershipType.free,
  isDefault: true,
  overlayOpacity: 0.42,
  fallbackColors: [Color(0xFF160711), Color(0xFF4B1628)],
);

const RoomBackgroundTheme moonlitWhisperGroveRoomBackgroundTheme = RoomBackgroundTheme(
  id: 'moonlit_whisper_grove',
  name: 'Moonlit Whisper Grove',
  assetPath: '$roomDefaultBackgroundAssetBase/moonlit_whisper_grove.webp',
  accent: RoomColors.aqua,
  sourceType: RoomBackgroundSourceType.chatRoom,
  unlockType: RoomBackgroundUnlockType.free,
  ownershipType: RoomBackgroundOwnershipType.free,
  isDefault: true,
  overlayOpacity: 0.40,
  fallbackColors: [Color(0xFF030B12), Color(0xFF0F2937)],
);

const RoomBackgroundTheme cosmicHorizonVeilRoomBackgroundTheme = RoomBackgroundTheme(
  id: 'cosmic_horizon_veil',
  name: 'Cosmic Horizon Veil',
  assetPath: '$roomDefaultBackgroundAssetBase/cosmic_horizon_veil.webp',
  accent: RoomColors.violet,
  sourceType: RoomBackgroundSourceType.chatRoom,
  unlockType: RoomBackgroundUnlockType.free,
  ownershipType: RoomBackgroundOwnershipType.free,
  isDefault: true,
  overlayOpacity: 0.44,
  fallbackColors: [Color(0xFF070414), Color(0xFF251538)],
);

const RoomBackgroundTheme defaultRoomBackgroundTheme =
    celestialFallsRoomBackgroundTheme;

const List<RoomBackgroundTheme> ownedRoomBackgroundThemes = [
  celestialFallsRoomBackgroundTheme,
  moonlitBiolumeShoreRoomBackgroundTheme,
  auroraFrostLakeRoomBackgroundTheme,
  desertDuskOasisRoomBackgroundTheme,
  alpineTwilightMirrorRoomBackgroundTheme,
  crimsonCoastBeaconRoomBackgroundTheme,
  moonlitWhisperGroveRoomBackgroundTheme,
  cosmicHorizonVeilRoomBackgroundTheme,
];

const List<RoomBackgroundTheme> mockRoomBackgroundThemes = ownedRoomBackgroundThemes;

final ValueNotifier<RoomBackgroundTheme> activeRoomBackgroundTheme =
    ValueNotifier<RoomBackgroundTheme>(defaultRoomBackgroundTheme);

class RoomBackground extends StatelessWidget {
  const RoomBackground({super.key, this.theme = defaultRoomBackgroundTheme});

  final RoomBackgroundTheme theme;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    return RepaintBoundary(
      child: OverflowBox(
        alignment: Alignment.topCenter,
        minWidth: screenSize.width,
        maxWidth: screenSize.width,
        minHeight: screenSize.height,
        maxHeight: screenSize.height,
        child: SizedBox(
          width: screenSize.width,
          height: screenSize.height,
          child: _RoomBackgroundImage(theme: theme),
        ),
      ),
    );
  }
}

class _RoomBackgroundImage extends StatelessWidget {
  const _RoomBackgroundImage({required this.theme});

  final RoomBackgroundTheme theme;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _FallbackGradient(colors: theme.fallbackColors),
        if (theme.isNetworkBacked)
          Image.network(
            theme.imageUrl!,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (context, error, stackTrace) {
              return _AssetFallbackImage(theme: theme);
            },
          )
        else
          _AssetFallbackImage(theme: theme),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.05),
                Colors.black.withValues(alpha: theme.overlayOpacity * 0.45),
                Colors.black.withValues(alpha: theme.overlayOpacity),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AssetFallbackImage extends StatelessWidget {
  const _AssetFallbackImage({required this.theme});

  final RoomBackgroundTheme theme;

  @override
  Widget build(BuildContext context) {
    if (!theme.isAssetBacked) return const SizedBox.shrink();

    return Image.asset(
      theme.assetPath!,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      errorBuilder: (context, error, stackTrace) {
        return const SizedBox.shrink();
      },
    );
  }
}

class _FallbackGradient extends StatelessWidget {
  const _FallbackGradient({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors.length >= 2 ? colors : const [RoomColors.deep, RoomColors.plum],
        ),
      ),
    );
  }
}

class RoomBackgroundPickerSheet extends StatelessWidget {
  const RoomBackgroundPickerSheet({
    super.key,
    required this.currentTheme,
    required this.onThemeSelected,
    required this.onStoreTap,
    this.viewerState = const RoomBackgroundViewerState(),
  });

  final RoomBackgroundTheme currentTheme;
  final ValueChanged<RoomBackgroundTheme> onThemeSelected;
  final VoidCallback onStoreTap;
  final RoomBackgroundViewerState viewerState;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.66,
      padding: EdgeInsets.fromLTRB(
        14,
        10,
        14,
        MediaQuery.paddingOf(context).bottom + 14,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(width: 44),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Room Backgrounds',
                      style: TextStyle(
                        color: RoomColors.plum,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Default themes now, backend/CDN themes later',
                      style: TextStyle(
                        color: Color(0xFF82758E),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              _StorePill(onTap: onStoreTap),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Default Backgrounds',
            style: TextStyle(
              color: RoomColors.plum,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.zero,
              physics: const BouncingScrollPhysics(),
              itemCount: ownedRoomBackgroundThemes.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.18,
              ),
              itemBuilder: (context, index) {
                final theme = ownedRoomBackgroundThemes[index];
                final selected = theme.id == currentTheme.id;
                final access = theme.accessFor(viewerState);
                return _BackgroundThemeTile(
                  theme: theme,
                  selected: selected,
                  access: access,
                  onTap: () {
                    if (!access.available) {
                      RoomToast.show(context, access.label);
                      return;
                    }
                    activeRoomBackgroundTheme.value = theme;
                    onThemeSelected(theme);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundThemeTile extends StatelessWidget {
  const _BackgroundThemeTile({
    required this.theme,
    required this.selected,
    required this.access,
    required this.onTap,
  });

  final RoomBackgroundTheme theme;
  final bool selected;
  final RoomBackgroundAccessState access;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locked = !access.available;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: RoomColors.pearl,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? theme.accent : RoomColors.softLine,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _FallbackGradient(colors: theme.fallbackColors),
                      if (theme.isNetworkBacked)
                        Image.network(
                          theme.thumbnailUrl ?? theme.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _AssetFallbackImage(theme: theme);
                          },
                        )
                      else
                        _AssetFallbackImage(theme: theme),
                      Container(color: Colors.black.withValues(alpha: locked ? 0.45 : 0.12)),
                      if (selected && !locked)
                        const Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: EdgeInsets.all(7),
                            child: Icon(
                              VMIcons.checkCircle,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      if (locked)
                        const Center(
                          child: Icon(
                            VMIcons.lock,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                theme.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: RoomColors.plum,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                access.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: access.available ? const Color(0xFF6E5B7A) : RoomColors.coral,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StorePill extends StatelessWidget {
  const _StorePill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RoomColors.plum,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(VMIcons.store, color: Colors.white, size: 14),
              SizedBox(width: 5),
              Text(
                'Store',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key, this.width = 46, this.color});

  final double width;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: width,
        height: 5,
        decoration: BoxDecoration(
          color: color ?? const Color(0xFFD9D2CC),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class RoundRoomButton extends StatefulWidget {
  const RoundRoomButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color = Colors.white,
    this.background,
    this.size = 38,
    this.iconSize = 20,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final Color? background;
  final double size;
  final double iconSize;

  @override
  State<RoundRoomButton> createState() => _RoundRoomButtonState();
}

class _RoundRoomButtonState extends State<RoundRoomButton> {
  bool _tapLocked = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.background ?? Colors.white.withValues(alpha: 0.075),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          if (_tapLocked) return;
          _tapLocked = true;
          widget.onTap();
          Future<void>.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _tapLocked = false;
          });
        },
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Icon(
            widget.icon,
            color: widget.color,
            size: widget.iconSize,
          ),
        ),
      ),
    );
  }
}

class GradientIconBox extends StatelessWidget {
  const GradientIconBox({super.key, required this.icon, required this.colors, this.size = 48});

  final IconData icon;
  final List<Color> colors;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.30),
        gradient: LinearGradient(colors: colors),
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.44),
    );
  }
}

class RoomToast {
  static void show(BuildContext context, String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: RoomColors.plum,
      ),
    );
  }
}
