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
        joinRequestCount: _pendingRoomMemberRequests.length,
        cricketModeActive: CricketRoomModeSignal.isActive(_roomId),
        onBackgroundTap: () => _openBackgroundPickerFromSettings(sheetContext),
        onCoverPhotoTap: () => _changeRoomCoverPhotoFromSettings(sheetContext),
        onCustomBackgroundTap: () =>
            _submitCustomBackgroundFromSettings(sheetContext),
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

  Future<void> _changeRoomCoverPhotoFromSettings(
    BuildContext sheetContext,
  ) async {
    if (!_viewerCanManageRoom) {
      RoomToast.show(context, 'Only the host/admin can change the cover photo');
      return;
    }
    Navigator.pop(sheetContext);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
      );
      if (file == null || !mounted) return;
      RoomToast.show(context, 'Uploading room cover photo...');
      final api = const RoomApiService();
      final upload = await api.uploadRoomCover(file);
      await api.updateRoomCoverPhoto(
        roomId: _roomId,
        coverPhotoUrl: upload.url,
      );
      if (!mounted) return;
      RoomToast.show(context, 'Room cover photo updated');
      _insertSystemMessage('Room cover photo updated by ${_currentUser.name}.');
    } catch (error) {
      if (!mounted) return;
      RoomToast.show(context, error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _submitCustomBackgroundFromSettings(
    BuildContext sheetContext,
  ) async {
    if (!_viewerCanManageRoom) {
      RoomToast.show(
        context,
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
      if (file == null || !mounted) return;
      RoomToast.show(context, 'Uploading custom background...');
      final api = const RoomApiService();
      final upload = await api.uploadRoomBackground(file);
      final review = await api.submitCustomBackground(
        roomId: _roomId,
        imageUrl: upload.url,
      );
      if (!mounted) return;
      RoomToast.show(context, 'Submitted for review: ${review.reviewPublicId}');
      _insertSystemMessage(
        'Custom room background submitted for review. Current background stays unchanged until approval.',
      );
    } catch (error) {
      if (!mounted) return;
      RoomToast.show(context, error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _openBackgroundPickerFromSettings(
    BuildContext sheetContext,
  ) async {
    if (!_viewerCanManageRoom) {
      RoomToast.show(context, 'Only the host/admin can change room background');
      return;
    }
    Navigator.pop(sheetContext);
    LiveRoomSheetController.showTransparentSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => RoomBackgroundPickerSheet(
        currentTheme: _selectedBackgroundTheme,
        onThemeSelected: (theme) {
          _roomStateController.setSelectedBackgroundTheme(theme);
          LiveRoomMediaSignalingService.instance.setRoomBackgroundTheme(
            theme.id,
          );
          RoomToast.show(context, '${theme.name} applied');
          _insertSystemMessage(
            '${theme.name} background applied by ${_currentUser.name}.',
          );
        },
        onStoreTap: () {
          Navigator.pop(context);
          _openBackgroundStoreSheet();
        },
      ),
    );
  }

  Future<void> _openBackgroundStoreSheet() async {
    RoomToast.show(context, 'Loading store backgrounds...');
    try {
      final api = const RoomApiService();
      final themes = await api.listRoomThemes();
      if (!mounted) return;
      final storeThemes = themes
          .where((theme) => !theme.isDefault)
          .toList(growable: false);
      if (storeThemes.isEmpty) {
        RoomToast.show(context, 'No store backgrounds available yet');
        return;
      }
      LiveRoomSheetController.showTransparentSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => _RoomThemeStoreSheet(
          themes: storeThemes,
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
                roomId: _roomId,
                themeId: selectedTheme.themeId,
              );
              if (!mounted) return;
              Navigator.pop(context);
              _roomStateController.setSelectedBackgroundTheme(
                _themeFromDto(selectedTheme),
              );
              RoomToast.show(context, '${selectedTheme.name} applied');
              _insertSystemMessage(
                '${selectedTheme.name} background applied by ${_currentUser.name}.',
              );
            } catch (error) {
              if (!mounted) return;
              RoomToast.show(
                context,
                error.toString().replaceFirst('Exception: ', ''),
              );
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
      sourceType: theme.isDefault
          ? RoomBackgroundSourceType.chatRoom
          : RoomBackgroundSourceType.store,
      unlockType: theme.isFree
          ? RoomBackgroundUnlockType.free
          : RoomBackgroundUnlockType.storePurchase,
      ownershipType: theme.isFree
          ? RoomBackgroundOwnershipType.free
          : RoomBackgroundOwnershipType.permanent,
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
      builder: (context) => VibeSyncControlSheet(
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

  void _openJoinRequestsSheet() {
    _clearRoomFocus();
    LiveRoomSheetController.showTransparentSheet<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => LiveRoomJoinRequestsSheet(
          users: _pendingRoomMemberRequests,
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
    if (!_viewerCanManageAdmins) {
      RoomToast.show(
        context,
        'Only channel host can approve room member requests',
      );
      return;
    }
    if (approved) {
      LiveRoomMemberRequestService.instance.approveMembership(user);
      LiveRoomMembershipService.markMember(roomId: _roomId, userId: user.id);
    } else {
      LiveRoomMemberRequestService.instance.rejectMembership(user);
      LiveRoomMembershipService.markGuest(roomId: _roomId, userId: user.id);
    }
    RoomToast.show(
      context,
      approved
          ? '${user.name} approved as room member'
          : '${user.name} rejected',
    );
  }

  void _openPrivacySheet() {
    _clearRoomFocus();
    LiveRoomSheetController.showTransparentSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => LiveRoomPrivacySheet(
        currentMode: _privacyMode,
        onModeChanged: (mode) {
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
    if (CricketRoomModeSignal.isActive(_roomId)) {
      RoomToast.show(context, 'Seat layout is fixed during Cricket Mode');
      return;
    }
    _clearRoomFocus();
    LiveRoomSheetController.showTransparentSheet<void>(
      context: context,
      builder: (context) => LiveRoomSeatLayoutPickerSheet(
        selectedLayout: _seatController.layoutId,
        onSelected: (layout) {
          _roomStateController.setSeatLayoutId(layout);
          _seatController.changeLayout(layout);
          Navigator.pop(context);
          RoomToast.show(context, 'Seat layout updated');
          _insertSystemMessage('Seat layout updated by ${_currentUser.name}.');
          _autoOccupySeatOneForHostOrAdmin();
        },
      ),
    );
  }

  void _openEditRoomNameSheet() {
    _clearRoomFocus();
    if (!_viewerCanManageAdmins) {
      RoomToast.show(context, 'Only channel host can edit room name');
      return;
    }
    LiveRoomSheetController.showTransparentSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _RoomNameEditSheet(
        initialName: _roomName,
        onSubmit: (name) {
          Navigator.pop(sheetContext);
          unawaited(_saveRoomName(name));
        },
      ),
    );
  }

  Future<void> _saveRoomName(String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      RoomToast.show(context, 'Room name cannot be empty');
      return;
    }
    try {
      await _roomStateController.setRoomName(cleanName);
      if (!mounted) return;
      RoomToast.show(context, 'Room name updated');