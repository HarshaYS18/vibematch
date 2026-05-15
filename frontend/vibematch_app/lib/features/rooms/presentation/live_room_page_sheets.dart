part of 'live_room_page.dart';

extension _LiveRoomPageSheets on _LiveRoomPageState {
  void _openSettingsSheet() {
    _clearRoomFocus();
    LiveRoomSheetController.showTransparentStatefulSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext, setSheetState) => LiveRoomSettingsSheetModule(
        roomId: _roomId,
        privacyMode: _privacyMode,
        roomImagesEnabled: _roomImagesEnabled,
        guestMessagesEnabled: _guestMessagesEnabled,
        applyOnlyModeEnabled: _applyOnlyModeEnabled,
        joinRequestCount: _roomMessageController.joinRequestUsers.length,
        onBackgroundTap: () => _openBackgroundStoreFromSettings(sheetContext),
        onCoverPhotoTap: () => _changeRoomCoverPhotoFromSettings(sheetContext),
        onCustomBackgroundTap: () => _submitCustomBackgroundFromSettings(sheetContext),
        onPrivacyTap: _openPrivacySheet,
        onSeatLayoutTap: _openSeatLayoutSheet,
        onAnnouncementTap: _openAnnouncementSheet,
        onInboxTap: () => _openInboxPageFromSheet(sheetContext),
        onJoinRequestsTap: _openJoinRequestsSheet,
        onVibeSyncTap: () => _openVibeSyncSheetFromSettings(sheetContext),
        onWatchPartyTap: () => _openWatchPartyFromSettings(sheetContext),
        onCricketModeTap: () => _openCricketModeFromSettings(sheetContext),
        onClearChatTap: () {
          LiveRoomMediaSignalingService.instance.broadcastChatCleared();
          RoomToast.show(context, 'Chat clear broadcasted');
        },
        canCloseRoom: _currentUser.isHost,
        onToggleRoomImages: (value) {
          _roomStateController.setRoomImagesEnabled(value);
          setSheetState(() {});
          LiveRoomMediaSignalingService.instance.broadcastRoomSystemMessage(
            _settingsController.roomImagesSystemMessage(value),
          );
        },
        onToggleGuestMessages: (value) {
          _roomStateController.setGuestMessagesEnabled(value);
          setSheetState(() {});
          LiveRoomMediaSignalingService.instance.broadcastRoomSystemMessage(
            _settingsController.guestMessagesSystemMessage(value),
          );
        },
        onToggleApplyOnlyMode: (value) {
          _roomStateController.setApplyOnlyModeEnabled(value);
          setSheetState(() {});
          LiveRoomMediaSignalingService.instance.broadcastRoomSystemMessage(
            _settingsController.applyOnlyModeSystemMessage(value),
          );
        },
        onCloseRoom: () => _leaveRoomFromSheet(sheetContext),
      ),
    );
  }

  Future<void> _changeRoomCoverPhotoFromSettings(BuildContext sheetContext) async {
    if (!_viewerCanManageRoom) {
      RoomToast.show(context, 'Only the host/admin can change the cover photo');
      return;
    }
    Navigator.pop(sheetContext);
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 88);
      if (file == null || !mounted) return;
      RoomToast.show(context, 'Uploading room cover photo...');
      final api = const RoomApiService();
      final upload = await api.uploadRoomCover(file);
      await api.updateRoomCoverPhoto(roomId: _roomId, coverPhotoUrl: upload.url);
      if (!mounted) return;
      RoomToast.show(context, 'Room cover photo updated');
      _insertSystemMessage('Room cover photo updated by ${_currentUser.name}.');
    } catch (error) {
      if (!mounted) return;
      RoomToast.show(context, error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _submitCustomBackgroundFromSettings(BuildContext sheetContext) async {
    if (!_viewerCanManageRoom) {
      RoomToast.show(context, 'Only the host/admin can submit room backgrounds');
      return;
    }
    Navigator.pop(sheetContext);
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
      if (file == null || !mounted) return;
      RoomToast.show(context, 'Uploading custom background...');
      final api = const RoomApiService();
      final upload = await api.uploadRoomBackground(file);
      final review = await api.submitCustomBackground(roomId: _roomId, imageUrl: upload.url);
      if (!mounted) return;
      RoomToast.show(context, 'Submitted for review: ${review.reviewPublicId}');
      _insertSystemMessage('Custom room background submitted for review. Current background stays unchanged until approval.');
    } catch (error) {
      if (!mounted) return;
      RoomToast.show(context, error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _openBackgroundStoreFromSettings(BuildContext sheetContext) async {
    if (!_viewerCanManageRoom) {
      RoomToast.show(context, 'Only the host/admin can change room background');
      return;
    }
    Navigator.pop(sheetContext);
    RoomToast.show(context, 'Loading room backgrounds...');
    try {
      final api = const RoomApiService();
      final themes = await api.listRoomThemes();
      if (!mounted) return;
      if (themes.isEmpty) {
        RoomToast.show(context, 'No backgrounds available yet');
        return;
      }
      LiveRoomSheetController.showTransparentSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _RoomThemeStoreSheet(
          themes: themes,
          onThemePressed: (theme) async {
            try {
              var selectedTheme = theme;
              if (!selectedTheme.isOwned && !selectedTheme.isFree) {
                RoomToast.show(context, 'Purchasing ${selectedTheme.name}...');
                selectedTheme = await api.purchaseRoomTheme(selectedTheme.themeId);
              }
              await api.applyRoomTheme(roomId: _roomId, themeId: selectedTheme.themeId);
              if (!mounted) return;
              Navigator.pop(context);
              _roomStateController.setSelectedBackgroundTheme(
                _themeFromDto(selectedTheme),
              );
              RoomToast.show(context, '${selectedTheme.name} applied');
              _insertSystemMessage('${selectedTheme.name} background applied by ${_currentUser.name}.');
            } catch (error) {
              if (!mounted) return;
              RoomToast.show(context, error.toString().replaceFirst('Exception: ', ''));
            }
          },
        ),
      );
    } catch (error) {
      if (!mounted) return;
      RoomToast.show(context, error.toString().replaceFirst('Exception: ', ''));
    }
  }

  RoomBackgroundTheme _themeFromDto(RoomThemeDto theme) {
    return RoomBackgroundTheme(
      id: theme.themeId,
      name: theme.name,
      imageUrl: theme.imageUrl,
      assetPath: theme.assetPath,
      accent: RoomColors.aqua,
      sourceType: RoomBackgroundSourceType.store,
      unlockType: theme.isFree ? RoomBackgroundUnlockType.free : RoomBackgroundUnlockType.storePurchase,
      ownershipType: theme.isFree ? RoomBackgroundOwnershipType.free : RoomBackgroundOwnershipType.permanent,
      isDefault: theme.isDefault,
      overlayOpacity: 0.42,
      fallbackColors: const [RoomColors.deep, RoomColors.plum],
    );
  }

  void _openCricketModeFromSettings(BuildContext sheetContext) {
    Navigator.pop(sheetContext);
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (!mounted) return;

      CricketStumpsFlowModule.open(
        context: context,
        roomId: _roomId,
        roomName: _roomName,
        canManage: _viewerCanManageRoom,
        previousBackground: _selectedBackgroundTheme,
        onBackgroundChanged: _roomStateController.setSelectedBackgroundTheme,
        onSystemMessage: _insertSystemMessage,
      );
    });
  }

  void _openWatchPartyFromSettings(BuildContext sheetContext) {
    Navigator.pop(sheetContext);
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (mounted) {
        _openInfoSheet(
          'Watch Party',
          'Watch Party settings will open here. YouTube link, play/pause/seek sync, and 10-seat watch layout will connect next.',
        );
      }
    });
  }

  void _openVibeSyncSheetFromSettings(BuildContext sheetContext) {
    Navigator.pop(sheetContext);
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _openVibeSyncSheet();
    });
  }

  void _openVibeSyncSheet() {
    _clearRoomFocus();
    LiveRoomSheetController.showTransparentSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => VibeSyncControlSheet(
        state: _vibeSyncState,
        users: _roomUsers,
        canManage: _viewerCanManageRoom,
        onPickFirst: (user) {
          _roomStateController.setVibeSyncState(
            _vibeSyncController.pickFirstUser(
              state: _vibeSyncState,
              user: user,
            ),
          );
        },
        onPickSecond: (user) {
          _roomStateController.setVibeSyncState(
            _vibeSyncController.pickSecondUser(
              state: _vibeSyncState,
              user: user,
            ),
          );
        },
        onAnnounce: () {
          Navigator.pop(context);
          final announcement = _vibeSyncController.announce(_vibeSyncState);
          if (announcement == null) return;
          _roomStateController.setVibeSyncState(announcement.state);
          _insertSystemMessage(announcement.systemMessage);
        },
        onEnd: () {
          Navigator.pop(context);
          _roomStateController.setVibeSyncState(_vibeSyncController.end());
          _insertSystemMessage(_vibeSyncController.endSystemMessage());
        },
      ),
    );
  }

  void _clearVibeSyncOverlay() {
    _roomStateController.setVibeSyncState(
      _vibeSyncController.clearOverlay(_vibeSyncState),
    );
  }

  void _openJoinRequestsSheet() {
    _clearRoomFocus();
    LiveRoomSheetController.showTransparentSheet<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => LiveRoomJoinRequestsSheet(
          users: _roomMessageController.joinRequestUsers,
          onApprove: (user) {
            _resolveJoinRequest(user, approved: true);
            setSheetState(() {});
          },
          onReject: (user) {
            _resolveJoinRequest(user, approved: false);
            setSheetState(() {});
          },
        ),
      ),
    );
  }

  void _resolveJoinRequest(SeatUser user, {required bool approved}) {
    _roomMessageController.resolveJoinRequest(
      user: user,
      approved: approved,
      roomName: _roomName,
    );
    RoomToast.show(
      context,
      approved ? '${user.name} approved' : '${user.name} rejected',
    );
  }

  void _openPrivacySheet() {
    _clearRoomFocus();
    LiveRoomSheetController.showTransparentSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => LiveRoomPrivacySheet(
        currentMode: _privacyMode,
        onModeChanged: (mode) {
          _roomStateController.setPrivacyMode(mode);
          _insertSystemMessage(
            _settingsController.privacyModeSystemMessage(mode),
          );
        },
      ),
    );
  }

  void _openGamesSheet() {
    _clearRoomFocus();
    LiveRoomGamesActionsModule.openGamesSheet(context: context);
  }

  void _openSeatLayoutSheet() {
    _clearRoomFocus();
    LiveRoomSheetController.showTransparentSheet<void>(
      context: context,
      builder: (_) => LiveRoomSeatLayoutPickerSheet(
        selectedLayout: _seatController.layoutId,
        onSelected: (layout) {
          _seatController.changeLayout(layout);
          Navigator.pop(context);
          unawaited(RoomMusicController.instance.attachRoom(widget.roomId));
          unawaited(_roomStateController.loadPersistedRoomSettings());
          _autoOccupySeatOneForHostOrAdmin();
        },
      ),
    );
  }

  void _openBackgroundSheet() {
    _clearRoomFocus();
    LiveRoomSheetController.showTransparentSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => LiveRoomBackgroundSheet(
        currentTheme: _selectedBackgroundTheme,
        onThemeSelected: (theme) {
          _roomStateController.setSelectedBackgroundTheme(theme);
          RoomToast.show(
            context,
            _settingsController.backgroundAppliedToast(theme),
          );
        },
        onStoreTap: () => RoomToast.show(context, 'Theme store opened'),
      ),
    );
  }

  void _openAnnouncementSheet() {
    _clearRoomFocus();
    LiveRoomSheetController.showTransparentSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => LiveRoomAnnouncementSheet(
        controller: _announcementController,
        onSubmit: (message) {
          Navigator.pop(context);
          if (message.isNotEmpty) {
            _insertSystemMessage(message);
            _announcementController.clear();
          }
          RoomToast.show(context, 'Announcement saved');
        },
      ),
    );
  }

  void _openLeaveSheet() {
    LiveRoomLeaveActionsModule.openLeaveSheet(
      context: context,
      navigationController: _navigationController,
      roomStateController: _roomStateController,
      roomName: _roomName,
      roomId: _roomId,
      language: widget.language,
      modeTitle: widget.modeTitle,
      onlineCount: _safeOnlineCount,
      dismissSeatActionPill: dismissRoomSeatActionPill,
      clearFocus: _clearRoomFocus,
      mountedGetter: () => mounted,
    );
  }

  void _leaveRoomFromSheet(BuildContext sheetContext) {
    LiveRoomLeaveActionsModule.leaveRoomFromSheet(
      context: context,
      sheetContext: sheetContext,
      navigationController: _navigationController,
      roomStateController: _roomStateController,
      mountedGetter: () => mounted,
    );
  }

  void _openInfoSheet(String title, String body) {
    LiveRoomSheetController.showTransparentSheet<void>(
      context: context,
      builder: (_) => LiveRoomInfoSheet(title: title, body: body),
    );
  }
}

class _RoomThemeStoreSheet extends StatelessWidget {
  const _RoomThemeStoreSheet({required this.themes, required this.onThemePressed});

  final List<RoomThemeDto> themes;
  final ValueChanged<RoomThemeDto> onThemePressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.70,
      padding: EdgeInsets.fromLTRB(14, 10, 14, MediaQuery.paddingOf(context).bottom + 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(width: 44),
          const SizedBox(height: 14),
          const Text(
            'Room Background Store',
            style: TextStyle(color: RoomColors.plum, fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            'Buy, apply, or use approved custom backgrounds.',
            style: TextStyle(color: Color(0xFF82758E), fontSize: 12, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: themes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final theme = themes[index];
                final action = theme.isOwned || theme.isFree ? 'Apply' : 'Buy ${theme.priceCoins} coins';
                return Material(
                  color: RoomColors.pearl,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => onThemePressed(theme),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              gradient: const LinearGradient(colors: [RoomColors.deep, RoomColors.violet]),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: theme.imageUrl == null
                                ? const Icon(Icons.wallpaper_rounded, color: Colors.white)
                                : Image.network(theme.imageUrl!, fit: BoxFit.cover),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(theme.name, style: const TextStyle(color: RoomColors.plum, fontSize: 14, fontWeight: FontWeight.w900)),
                                const SizedBox(height: 3),
                                Text(theme.isOwned ? 'Owned' : theme.isFree ? 'Free' : 'Store background', style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 12, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(color: RoomColors.plum, borderRadius: BorderRadius.circular(999)),
                            child: Text(action, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
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
