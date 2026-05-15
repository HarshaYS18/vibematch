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
        onBackgroundTap: _openBackgroundSheet,
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
