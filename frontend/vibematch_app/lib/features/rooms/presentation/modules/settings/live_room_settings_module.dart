import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/live_room_media_signaling_service.dart';
import '../../../data/room_api_service.dart';
import '../../controllers/live_room_sheet_controller.dart';
import '../../live_room_models.dart';
import '../../widgets/cricket_room_backgrounds.dart';
import '../../widgets/live_room_announcement_sheet.dart';
import '../../widgets/live_room_background_sheet.dart';
import '../../widgets/live_room_info_sheet.dart';
import '../../widgets/live_room_join_requests_sheet.dart';
import '../../widgets/live_room_privacy_sheet.dart';
import '../../widgets/live_room_seat_layout_picker_sheet.dart';
import '../../widgets/live_room_settings_sheet_module.dart';
import '../../widgets/room_theme.dart';
import '../../widgets/vibesync_room_module.dart';
import '../chat/live_room_chat_module.dart';
import '../cricket/live_room_cricket_module.dart';
import '../cricket_room_mode_signal.dart';
import '../games/live_room_games_entry_module.dart';
import '../lifecycle/live_room_lifecycle_module.dart';
import '../live_room_controller_bundle.dart';
import '../seats/live_room_seats_module.dart';
import '../watch_party/live_room_watch_party_entry_module.dart';

class LiveRoomSettingsModule {
  const LiveRoomSettingsModule._();

  static void open(LiveRoomControllerBundle bundle) {
    LiveRoomLifecycleModule.clearFocus(bundle);
    LiveRoomSheetController.showTransparentStatefulSheet<void>(
      context: bundle.context,
      isScrollControlled: true,
      builder: (sheetContext, setSheetState) => LiveRoomSettingsSheetModule(
        roomId: bundle.roomId,
        privacyMode: bundle.privacyMode,
        roomImagesEnabled: bundle.roomImagesEnabled,
        guestMessagesEnabled: bundle.guestMessagesEnabled,
        applyOnlyModeEnabled: bundle.applyOnlyModeEnabled,
        joinRequestCount: bundle.pendingRoomMemberRequests.length,
        cricketModeActive: CricketRoomModeSignal.isActive(bundle.roomId),
        onBackgroundTap: () =>
            openBackgroundPickerFromSettings(bundle, sheetContext),
        onCoverPhotoTap: () =>
            changeRoomCoverPhotoFromSettings(bundle, sheetContext),
        onCustomBackgroundTap: () =>
            submitCustomBackgroundFromSettings(bundle, sheetContext),
        onPrivacyTap: () => openPrivacySheet(bundle),
        onSeatLayoutTap: () => openSeatLayoutSheet(bundle),
        onAnnouncementTap: () => openAnnouncementSheet(bundle),
        onInboxTap: () =>
            LiveRoomChatModule.openInboxPageFromSheet(bundle, sheetContext),
        onJoinRequestsTap: () => openJoinRequestsSheet(bundle),
        onVibeSyncTap: () =>
            openVibeSyncSheetFromSettings(bundle, sheetContext),
        onWatchPartyTap: () => LiveRoomWatchPartyEntryModule.openFromSettings(
          bundle: bundle,
          sheetContext: sheetContext,
        ),
        onCricketModeTap: () => LiveRoomCricketModule.openFromSettings(
          bundle: bundle,
          sheetContext: sheetContext,
        ),
        onClearChatTap: () {
          LiveRoomMediaSignalingService.instance.broadcastChatCleared();
          RoomToast.show(bundle.context, 'Chat clear broadcasted');
        },
        canCloseRoom: bundle.currentUser.isHost,
        onToggleRoomImages: (value) {
          bundle.roomStateController.setRoomImagesEnabled(value);
          setSheetState(() {});
          LiveRoomMediaSignalingService.instance.broadcastRoomSystemMessage(
            bundle.settingsController.roomImagesSystemMessage(value),
          );
        },
        onToggleGuestMessages: (value) {
          bundle.roomStateController.setGuestMessagesEnabled(value);
          setSheetState(() {});
          LiveRoomMediaSignalingService.instance.broadcastRoomSystemMessage(
            bundle.settingsController.guestMessagesSystemMessage(value),
          );
        },
        onToggleApplyOnlyMode: (value) {
          bundle.roomStateController.setApplyOnlyModeEnabled(value);
          setSheetState(() {});
          LiveRoomMediaSignalingService.instance.broadcastRoomSystemMessage(
            bundle.settingsController.applyOnlyModeSystemMessage(value),
          );
        },
        onCloseRoom: () => LiveRoomLifecycleModule.leaveRoomFromSheet(
          bundle: bundle,
          sheetContext: sheetContext,
        ),
      ),
    );
  }

  static Future<void> changeRoomCoverPhotoFromSettings(
    LiveRoomControllerBundle bundle,
    BuildContext sheetContext,
  ) async {
    if (!bundle.viewerCanManageRoom) {
      RoomToast.show(
        bundle.context,
        'Only the host/admin can change the cover photo',
      );
      return;
    }
    Navigator.pop(sheetContext);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
      );
      if (file == null || !bundle.mounted) return;
      RoomToast.show(bundle.context, 'Uploading room cover photo...');
      final api = const RoomApiService();
      final upload = await api.uploadRoomCover(file);
      await api.updateRoomCoverPhoto(
        roomId: bundle.roomId,
        coverPhotoUrl: upload.url,
      );
      if (!bundle.mounted) return;
      RoomToast.show(bundle.context, 'Room cover photo updated');
      LiveRoomChatModule.insertSystemMessage(
        bundle,
        'Room cover photo updated by ${bundle.currentUser.name}.',
      );
    } catch (error) {
      if (!bundle.mounted) return;
      RoomToast.show(
        bundle.context,
        error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  static Future<void> submitCustomBackgroundFromSettings(
    LiveRoomControllerBundle bundle,
    BuildContext sheetContext,
  ) async {
    if (!bundle.viewerCanManageRoom) {
      RoomToast.show(
        bundle.context,
        'Only the host/admin can submit room backgrounds',
      );
      return;
    }
    Navigator.pop(sheetContext);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (file == null || !bundle.mounted) return;
      RoomToast.show(bundle.context, 'Uploading custom background...');
      final api = const RoomApiService();
      final upload = await api.uploadRoomBackground(file);
      final review = await api.submitCustomBackground(
        roomId: bundle.roomId,
        imageUrl: upload.url,
      );
      if (!bundle.mounted) return;
      RoomToast.show(
        bundle.context,
        'Submitted for review: ${review.reviewPublicId}',
      );
      LiveRoomChatModule.insertSystemMessage(
        bundle,
        'Custom room background submitted for review. Current background stays unchanged until approval.',
      );
    } catch (error) {
      if (!bundle.mounted) return;
      RoomToast.show(
        bundle.context,
        error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  static Future<void> openBackgroundPickerFromSettings(
    LiveRoomControllerBundle bundle,
    BuildContext sheetContext,
  ) async {
    if (!bundle.viewerCanManageRoom) {
      RoomToast.show(
        bundle.context,
        'Only the host/admin can change room background',
      );
      return;
    }
    Navigator.pop(sheetContext);

    if (CricketRoomModeSignal.isActive(bundle.roomId)) {
      final currentCricketTheme =
          isCricketRoomBackground(bundle.selectedBackgroundTheme)
          ? bundle.selectedBackgroundTheme
          : cricketFloodlightArenaBackgroundTheme;
      LiveRoomSheetController.showTransparentSheet<void>(
        context: bundle.context,
        isScrollControlled: true,
        builder: (context) => CricketRoomBackgroundPickerSheet(
          currentTheme: currentCricketTheme,
          onThemeSelected: (theme) {
            bundle.roomStateController.setSelectedBackgroundTheme(theme);
            LiveRoomMediaSignalingService.instance.setRoomBackgroundTheme(
              theme.id,
            );
            RoomToast.show(context, '${theme.name} applied');
            LiveRoomChatModule.insertSystemMessage(
              bundle,
              '${theme.name} cricket background applied by ${bundle.currentUser.name}.',
            );
          },
        ),
      );
      return;
    }

    LiveRoomSheetController.showTransparentSheet<void>(
      context: bundle.context,
      isScrollControlled: true,
      builder: (context) => RoomBackgroundPickerSheet(
        currentTheme: isCricketRoomBackground(bundle.selectedBackgroundTheme)
            ? defaultRoomBackgroundTheme
            : bundle.selectedBackgroundTheme,
        onThemeSelected: (theme) {
          if (isCricketRoomBackground(theme)) {
            RoomToast.show(
              context,
              'Cricket backgrounds are available only in Cricket Mode',
            );
            return;
          }
          bundle.roomStateController.setSelectedBackgroundTheme(theme);
          LiveRoomMediaSignalingService.instance.setRoomBackgroundTheme(
            theme.id,
          );
          RoomToast.show(context, '${theme.name} applied');
          LiveRoomChatModule.insertSystemMessage(
            bundle,
            '${theme.name} background applied by ${bundle.currentUser.name}.',
          );
        },
        onStoreTap: () {
          Navigator.pop(context);
          openBackgroundStoreSheet(bundle);
        },
      ),
    );
  }

  static Future<void> openBackgroundStoreSheet(
    LiveRoomControllerBundle bundle,
  ) async {
    RoomToast.show(bundle.context, 'Loading store backgrounds...');
    try {
      final api = const RoomApiService();
      final themes = await api.listRoomThemes();
      if (!bundle.mounted) return;
      final storeThemes = themes
          .where((theme) => !theme.isDefault && theme.mode != 'cricket')
          .toList(growable: false);
      LiveRoomSheetController.showTransparentSheet<void>(
        context: bundle.context,
        isScrollControlled: true,
        builder: (context) => _RoomThemeStoreSheet(
          themes: storeThemes,
          onCustomBackgroundTap: () =>
              submitCustomBackgroundFromSettings(bundle, context),
          onThemePressed: (theme) async {
            try {
              var selectedTheme = theme;
              if (!selectedTheme.isOwned && !selectedTheme.isFree) {
                RoomToast.show(context, 'Purchasing ${selectedTheme.name}...');
                selectedTheme = await api.purchaseRoomTheme(
                  selectedTheme.themeId,
                );
              }
              await api.applyRoomTheme(
                roomId: bundle.roomId,
                themeId: selectedTheme.themeId,
              );
              if (!bundle.mounted) return;
              Navigator.pop(context);
              bundle.roomStateController.setSelectedBackgroundTheme(
                _themeFromDto(selectedTheme),
              );
              RoomToast.show(context, '${selectedTheme.name} applied');
              LiveRoomChatModule.insertSystemMessage(
                bundle,
                '${selectedTheme.name} background applied by ${bundle.currentUser.name}.',
              );
            } catch (error) {
              if (!bundle.mounted) return;
              RoomToast.show(
                context,
                error.toString().replaceFirst('Exception: ', ''),
              );
            }
          },
        ),
      );
    } catch (error) {
      if (!bundle.mounted) return;
      RoomToast.show(
        bundle.context,
        error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  static RoomBackgroundTheme _themeFromDto(RoomThemeDto theme) {
    final isCricket =
        theme.mode == 'cricket' || theme.themeId.startsWith('cricket_');
    return RoomBackgroundTheme(
      id: theme.themeId,
      name: theme.name,
      imageUrl: theme.imageUrl,
      thumbnailUrl: theme.thumbnailUrl,
      assetPath: theme.assetPath,
      accent: isCricket ? const Color(0xFF65FF8F) : RoomColors.aqua,
      sourceType: isCricket
          ? RoomBackgroundSourceType.event
          : (theme.isDefault
                ? RoomBackgroundSourceType.chatRoom
                : RoomBackgroundSourceType.store),
      unlockType: theme.isFree
          ? RoomBackgroundUnlockType.free
          : RoomBackgroundUnlockType.storePurchase,
      ownershipType: theme.isFree
          ? RoomBackgroundOwnershipType.free
          : RoomBackgroundOwnershipType.permanent,
      isDefault: theme.isDefault,
      isActive: theme.isActive,
      overlayOpacity: theme.overlayOpacity,
      fallbackColors: isCricket
          ? const [Color(0xFF04130A), Color(0xFF0B3E1F)]
          : const [RoomColors.deep, RoomColors.plum],
    );
  }

  static void openVibeSyncSheetFromSettings(
    LiveRoomControllerBundle bundle,
    BuildContext sheetContext,
  ) {
    Navigator.pop(sheetContext);
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (bundle.mounted) openVibeSyncSheet(bundle);
    });
  }

  static void openVibeSyncSheet(LiveRoomControllerBundle bundle) {
    LiveRoomLifecycleModule.clearFocus(bundle);
    LiveRoomSheetController.showTransparentSheet<void>(
      context: bundle.context,
      isScrollControlled: true,
      builder: (context) => VibeSyncControlSheet(
        state: bundle.vibeSyncState,
        users: bundle.roomUsers,
        canManage: bundle.viewerCanManageRoom,
        onPickFirst: (user) {
          bundle.roomStateController.setVibeSyncState(
            bundle.vibeSyncController.pickFirstUser(
              state: bundle.vibeSyncState,
              user: user,
            ),
          );
        },
        onPickSecond: (user) {
          bundle.roomStateController.setVibeSyncState(
            bundle.vibeSyncController.pickSecondUser(
              state: bundle.vibeSyncState,
              user: user,
            ),
          );
        },
        onAnnounce: () {
          Navigator.pop(context);
          final announcement = bundle.vibeSyncController.announce(
            bundle.vibeSyncState,
          );
          if (announcement == null) return;
          bundle.roomStateController.setVibeSyncState(announcement.state);
          LiveRoomChatModule.insertSystemMessage(
            bundle,
            announcement.systemMessage,
          );
        },
        onEnd: () {
          Navigator.pop(context);
          bundle.roomStateController.setVibeSyncState(
            bundle.vibeSyncController.end(),
          );
          LiveRoomChatModule.insertSystemMessage(
            bundle,
            bundle.vibeSyncController.endSystemMessage(),
          );
        },
      ),
    );
  }

  static void openJoinRequestsSheet(LiveRoomControllerBundle bundle) {
    LiveRoomLifecycleModule.clearFocus(bundle);
    LiveRoomSheetController.showTransparentSheet<void>(
      context: bundle.context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => LiveRoomJoinRequestsSheet(
          users: bundle.pendingRoomMemberRequests,
          onApprove: (user) {
            resolveJoinRequest(bundle, user, approved: true);
            setSheetState(() {});
          },
          onReject: (user) {
            resolveJoinRequest(bundle, user, approved: false);
            setSheetState(() {});
          },
        ),
      ),
    );
  }

  static void resolveJoinRequest(
    LiveRoomControllerBundle bundle,
    SeatUser user, {
    required bool approved,
  }) {
    if (!bundle.viewerCanManageAdmins) {
      RoomToast.show(
        bundle.context,
        'Only channel host can approve room member requests',
      );
      return;
    }
    bundle.resolveRoomMembership(
      user,
      approved: approved,
    );
    RoomToast.show(
      bundle.context,
      approved
          ? '${user.name} approved as room member'
          : '${user.name} rejected',
    );
  }

  static void openPrivacySheet(LiveRoomControllerBundle bundle) {
    LiveRoomLifecycleModule.clearFocus(bundle);
    LiveRoomSheetController.showTransparentSheet<void>(
      context: bundle.context,
      isScrollControlled: true,
      builder: (context) => LiveRoomPrivacySheet(
        currentMode: bundle.privacyMode,
        onModeChanged: (mode) {
          LiveRoomChatModule.insertSystemMessage(
            bundle,
            bundle.settingsController.privacyModeSystemMessage(mode),
          );
        },
      ),
    );
  }

  static void openGamesSheet(LiveRoomControllerBundle bundle) {
    LiveRoomGamesEntryModule.openGamesSheet(bundle);
  }

  static void openSeatLayoutSheet(LiveRoomControllerBundle bundle) {
    if (CricketRoomModeSignal.isActive(bundle.roomId)) {
      RoomToast.show(
        bundle.context,
        'Seat layout is fixed during Cricket Mode',
      );
      return;
    }
    LiveRoomLifecycleModule.clearFocus(bundle);
    LiveRoomSheetController.showTransparentSheet<void>(
      context: bundle.context,
      builder: (context) => LiveRoomSeatLayoutPickerSheet(
        selectedLayout: bundle.seatController.layoutId,
        onSelected: (layout) {
          bundle.roomStateController.setSeatLayoutId(layout);
          bundle.seatController.changeLayout(layout);
          Navigator.pop(context);
          RoomToast.show(bundle.context, 'Seat layout updated');
          LiveRoomChatModule.insertSystemMessage(
            bundle,
            'Seat layout updated by ${bundle.currentUser.name}.',
          );
          LiveRoomSeatsModule.autoOccupySeatOneForHostOrAdmin(bundle);
        },
      ),
    );
  }

  static void openAnnouncementSheet(LiveRoomControllerBundle bundle) {
    LiveRoomLifecycleModule.clearFocus(bundle);
    if (!bundle.viewerCanManageAdmins) {
      RoomToast.show(
        bundle.context,
        'Only channel host can update broad announcement',
      );
      return;
    }
    bundle.announcementController.text =
        bundle.roomStateController.announcementText;
    LiveRoomSheetController.showTransparentSheet<void>(
      context: bundle.context,
      isScrollControlled: true,
      builder: (sheetContext) => LiveRoomAnnouncementSheet(
        controller: bundle.announcementController,
        onSubmit: (message) {
          Navigator.pop(sheetContext);
          unawaited(saveAnnouncement(bundle, message));
        },
      ),
    );
  }

  static Future<void> saveAnnouncement(
    LiveRoomControllerBundle bundle,
    String message,
  ) async {
    final cleanMessage = message.trim();
    try {
      await bundle.roomStateController.setRoomAnnouncement(cleanMessage);
      if (!bundle.mounted) return;
      bundle.announcementController.clear();
      if (cleanMessage.isNotEmpty) {
        LiveRoomMediaSignalingService.instance.broadcastRoomSystemMessage(
          cleanMessage,
        );
      }
      RoomToast.show(bundle.context, 'Announcement saved');
    } catch (error) {
      if (!bundle.mounted) return;
      RoomToast.show(
        bundle.context,
        error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  static void openInfoSheet(
    LiveRoomControllerBundle bundle,
    String title,
    String body,
  ) {
    LiveRoomSheetController.showTransparentSheet<void>(
      context: bundle.context,
      builder: (context) => LiveRoomInfoSheet(title: title, body: body),
    );
  }
}

class _RoomThemeStoreSheet extends StatelessWidget {
  const _RoomThemeStoreSheet({
    required this.themes,
    required this.onThemePressed,
    required this.onCustomBackgroundTap,
  });

  final List<RoomThemeDto> themes;
  final ValueChanged<RoomThemeDto> onThemePressed;
  final VoidCallback onCustomBackgroundTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.70,
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
                      'Background Store',
                      style: TextStyle(
                        color: RoomColors.plum,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Premium backgrounds and custom uploads',
                      style: TextStyle(
                        color: Color(0xFF82758E),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: RoomColors.plum),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Material(
            color: const Color(0xFF251538),
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onCustomBackgroundTap,
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: RoomColors.aqua.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: RoomColors.aqua.withValues(alpha: 0.24),
                        ),
                      ),
                      child: const Icon(
                        Icons.add_photo_alternate_rounded,
                        color: RoomColors.aqua,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Upload Custom Background',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Submit your room background for monitor review.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: themes.isEmpty
                ? const Center(
                    child: Text(
                      'No store backgrounds available yet.',
                      style: TextStyle(
                        color: Color(0xFF82758E),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: themes.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final theme = themes[index];
                      final priceLabel = theme.isFree
                          ? 'Free'
                          : theme.isOwned
                          ? 'Owned'
                          : '${theme.priceCoins} coins';
                      return Material(
                        color: RoomColors.pearl,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => onThemePressed(theme),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  width: 58,
                                  height: 58,
                                  decoration: BoxDecoration(
                                    color: RoomColors.deep,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: RoomColors.softLine,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: theme.imageUrl != null
                                      ? Image.network(
                                          theme.imageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  const Icon(
                                                    Icons.image_rounded,
                                                  ),
                                        )
                                      : const Icon(
                                          Icons.wallpaper_rounded,
                                          color: Colors.white,
                                        ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        theme.name,
                                        style: const TextStyle(
                                          color: RoomColors.plum,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        priceLabel,
                                        style: TextStyle(
                                          color: theme.isOwned || theme.isFree
                                              ? RoomColors.aqua
                                              : RoomColors.coral,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: RoomColors.plum,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
