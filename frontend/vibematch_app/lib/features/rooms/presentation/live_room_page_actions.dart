part of 'live_room_page.dart';

extension _LiveRoomPageActions on _LiveRoomPageState {
  void _onSeatTap(int index) {
    final seat = _seatController.seats[index];
    if (seat.locked) {
      if (_viewerCanManageRoom) {
        _seatController.toggleSelectedSeat(index);
      } else {
        RoomToast.show(context, 'This seat is locked');
      }
      return;
    }

    if (seat.user == null && !_viewerCanManageRoom) {
      if (_applyOnlyModeEnabled) {
        _applyForSeat(index);
      } else {
        _seatController.occupySeat(index);
      }
      return;
    }

    if (seat.user == null && _viewerCanManageRoom) {
      _seatController.toggleSelectedSeat(index);
    }
  }

  void _onUserTap(int index) {
    final user = _seatController.seats[index].user;
    if (user == null) return;
    _openMiniProfile(user, index);
  }

  void _approveSeatApplication(ChatEntry entry) {
    _seatController.approveSeatApplication(
      entry: entry,
      messages: _roomMessageController.messages,
      allRoomUsers: _allRoomUsers,
    );
  }

  void _rejectSeatApplication(ChatEntry entry) {
    _seatController.rejectSeatApplication(
      entry: entry,
      messages: _roomMessageController.messages,
    );
  }

  void _applyForSeat(int index) => _seatController.applyForSeat(
    index: index,
    messages: _roomMessageController.messages,
  );

  void _inviteSeat(int index) {
    _seatController.clearSelectedSeat();
    _openSeatInviteSheet(index);
  }

  void _openSeatInviteSheet(int seatIndex) {
    _clearRoomFocus();
    final inviteUsers = _usersController.buildSeatInviteUsers(
      allRoomUsers: _allRoomUsers,
      seatedUsers: _roomUsers,
    );
    LiveRoomSheetController.showTransparentSheet<void>(
      context: context,
      builder: (_) => LiveRoomInviteSheet(
        seatIndex: seatIndex,
        users: inviteUsers,
        onInvite: (user) =>
            _sendSeatInvite(seatIndex: seatIndex, invitedUser: user),
      ),
    );
  }

  void _sendSeatInvite({
    required int seatIndex,
    required SeatUser invitedUser,
  }) {
    Navigator.pop(context);
    _clearRoomFocus();
    final sent = _seatController.inviteUserToSeat(
      seatIndex: seatIndex,
      invitedUser: invitedUser,
    );
    if (sent) {
      RoomToast.show(context, 'Seat invite sent to ${invitedUser.name}');
    }
  }

  void _handleSeatInviteUpdate() {
    final invite = LiveRoomMediaSignalingService.instance.seatInvite.value;
    _seatInviteAutoHideTimer?.cancel();
    _seatInviteAutoHideTimer = null;

    if (invite == null || invite.roomId != _roomId || invite.seatIndex < 0) {
      if (_pendingSeatInvite != null && mounted) {
        _setRoomState(() => _pendingSeatInvite = null);
      }
      return;
    }

    if (!mounted) return;
    _setRoomState(() {
      _pendingSeatInvite = _PendingSeatInvite(
        inviterName: invite.inviterName,
        invitedUser: _currentUser,
        seatIndex: invite.seatIndex,
      );
    });
    _seatInviteAutoHideTimer = Timer(const Duration(seconds: 15), () {
      if (!mounted) return;
      LiveRoomMediaSignalingService.instance.clearSeatInvite();
      _setRoomState(() => _pendingSeatInvite = null);
    });
  }

  void _rejectSeatInvite() {
    final invite = _pendingSeatInvite;
    if (invite == null) return;

    _seatInviteAutoHideTimer?.cancel();
    _seatInviteAutoHideTimer = null;

    _setRoomState(() {
      _pendingSeatInvite = null;
    });
    LiveRoomMediaSignalingService.instance.rejectSeatInvite(
      seatIndex: invite.seatIndex,
    );

    RoomToast.show(context, 'Seat invite rejected');
  }

  void _acceptSeatInvite() {
    final invite = _pendingSeatInvite;
    if (invite == null) return;

    LiveRoomMediaSignalingService.instance.acceptSeatInvite(
      seatIndex: invite.seatIndex,
    );

    _seatInviteAutoHideTimer?.cancel();
    _seatInviteAutoHideTimer = null;

    _setRoomState(() {
      _pendingSeatInvite = null;
    });
    LiveRoomMediaSignalingService.instance.clearSeatInvite();
  }

  void _openRoomShareSheet() {
    _clearRoomFocus();
    LiveRoomSheetController.showTransparentSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FriendsInviteSheet(
        title: 'Invite friends to $_roomName',
        actionLabel: 'Invite',
        completedLabel: 'Sent',
        onInvite: (friend) => _sendRoomInviteToInbox(friend.displayName),
      ),
    );
  }

  void _sendRoomInviteToInbox(String friendName) {
    RoomToast.show(context, 'Room invite sent to $friendName\'s Inbox');
  }

  void _dismissRoomOverlays() {
    dismissRoomSeatActionPill();
    _clearRoomFocus();
  }

  void _insertSystemMessage(String message) =>
      _roomMessageController.insertSystemMessage(message);

  void _clearRoomFocus() {
    _messageFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _toggleMic() {
    _clearRoomFocus();
    _seatController.toggleMic();
  }

  void _handleJoinRoom() {
    _clearRoomFocus();

    if (_currentUserIsMember) {
      RoomToast.show(context, 'You are already a room member of $_roomName');
      return;
    }

    if (_joinRequestPending) {
      RoomToast.show(context, 'Your room member request is already pending.');
      return;
    }

    LiveRoomMemberRequestService.instance.requestMembership();
    RoomToast.show(context, 'Room member request sent to channel host');
  }

  void _openRoomUsersSheet() {
    LiveRoomSheetController.showTransparentSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => LiveRoomUsersSheet(
        users: _allRoomUsers,
        onUserTap: (user) {
          Navigator.pop(context);
          Future<void>.delayed(const Duration(milliseconds: 80), () {
            if (mounted) _openMiniProfileForUser(user);
          });
        },
      ),
    );
  }

  void _openRoomRankingsSheet() {
    LiveRoomSheetController.showTransparentSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => RoomContributionRankingsSheet(
        roomName: _roomName,
        users: _allRoomUsers,
        onUserTap: (user) {
          Navigator.pop(context);
          Future<void>.delayed(const Duration(milliseconds: 80), () {
            if (mounted) _openMiniProfileForUser(user);
          });
        },
      ),
    );
  }

  void _openRoomLevelPage() {
    _clearRoomFocus();
    RoomLevelSheet.show(
      context,
      roomName: _roomName,
      roomPublicId: _roomId,
      fallbackLevel: 1,
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    late final ChatModerationResult moderation;
    try {
      moderation = await _chatModerationApi.checkText(
        text: text,
        roomId: _roomId,
      );
    } catch (error) {
      RoomToast.show(context, error.toString().replaceFirst('Exception: ', ''));
      return;
    }
    if (!moderation.allowed) {
      RoomToast.show(context, moderation.userMessage);
      return;
    }
    _roomMessageController.sendMessage(text);
    _messageController.clear();
  }

  void _openMiniProfileFromChat(ChatEntry entry) {
    if (entry.senderId == null || entry.senderId == 'system') return;
    _openMiniProfileForUser(
      _usersController.resolveUserFromChatEntry(
        entry: entry,
        allRoomUsers: _allRoomUsers,
      ),
    );
  }

  void _openMiniProfileForUser(SeatUser user) {
    final liveUser = _allRoomUsers.firstWhere(
      (item) => item.id == user.id,
      orElse: () => user,
    );
    final seatIndex = _seatController.seats.indexWhere(
      (seat) => seat.user?.id == liveUser.id,
    );
    _openMiniProfile(liveUser, seatIndex);
  }

  void _openMiniProfile(SeatUser user, int seatIndex) {
    _clearRoomFocus();
    LiveRoomMiniProfileLauncher.open(
      context: context,
      user: user,
      seatIndex: seatIndex,
      currentUser: _currentUser,
      canModerate: _viewerCanManageRoom,
      allRoomUsers: _allRoomUsers,
      privacyMode: _privacyMode,
      roomName: _roomName,
      roomId: _roomId,
      onMentionTap: _mentionUser,
      onSetAdminTap: _setUserAsAdmin,
      onRemoveAdminTap: _removeUserAsAdmin,
      onReportTap: _openReportForUser,
      onKickOutDurationSelected: _canKickOutUser(user)
          ? (duration) => _kickOutUser(user: user, duration: duration)
          : null,
      onLeaveAndLock: (targetSeatIndex) {
        Navigator.pop(context);
        _seatController.leaveAndLockSeat(targetSeatIndex);
      },
      onLeaveSeatOnly: (targetSeatIndex) {
        Navigator.pop(context);
        final seatedUser =
            targetSeatIndex >= 0 &&
                targetSeatIndex < _seatController.seats.length
            ? _seatController.seats[targetSeatIndex].user
            : null;
        if (seatedUser?.id == _currentUser.id) {
          _seatController.leaveAndLockSeat(targetSeatIndex);
        } else {
          _seatController.leaveSeatOnly(targetSeatIndex);
        }
      },
      onSelfMuteToggle: (userId) {
        Navigator.pop(context);
        _seatController.toggleSelfMute(userId);
      },
      onAdminMuteToggle: (userId) {
        Navigator.pop(context);
        _seatController.toggleAdminMute(userId);
      },
      onGiftTap: (userId) {
        Navigator.pop(context);
        _setRoomState(() {
          (_giftControllerInstance ??= _createGiftController()).selectedReceiverIds
            ..clear()
            ..add(userId);
        });
        _openGiftPanel();
      },
    );
  }

  bool _canKickOutUser(SeatUser target) {
    return _moderationController.canKickOutUser(
      target: target,
      canManageRoom: _viewerCanManageRoom,
    );
  }

  Future<void> _kickOutUser({
    required SeatUser user,
    required RoomKickoutDuration duration,
  }) async {
    final result = await _moderationController.kickOutUser(
      roomId: _roomId,
      target: user,
      duration: duration,
      canManageRoom: _viewerCanManageRoom,
    );
    if (!mounted) return;
    final systemMessage = result.systemMessage;
    if (systemMessage != null) _insertSystemMessage(systemMessage);
    final removedUserId = result.removedUserId;
    if (removedUserId != null) {
      _seatController.kickUserFromRoom(
        userId: removedUserId,
        duration: duration.apiValue,
      );
    }
    final toastMessage = result.toastMessage;
    if (toastMessage != null) RoomToast.show(context, toastMessage);
  }

  void _mentionUser(SeatUser user) {
    Navigator.pop(context);

    _messageController.insertMention(user.name);

    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      _openMessageComposerWithMention();
    });
  }

  void _openMentionedUserProfile(String mentionName) {
    final cleanMention = mentionName.trim().toLowerCase();
    if (cleanMention.isEmpty) return;

    final user = _allRoomUsers.where((item) {
      final cleanName = item.name.trim().toLowerCase();
      final cleanUsername = cleanName.replaceAll(' ', '_');
      return cleanName == cleanMention ||
          cleanUsername == cleanMention ||
          cleanName.replaceAll(' ', '') == cleanMention.replaceAll('_', '');
    }).firstOrNull;

    if (user == null) {
      RoomToast.show(context, '@$mentionName profile not found in this room');
      return;
    }

    LiveRoomProfileNavigator.openExistingPublicProfile(
      context: context,
      user: user,
      privacyMode: _privacyMode,
      roomName: _roomName,
    );
  }

  void _openMessageComposerWithMention() {
    _clearRoomFocus();
    LiveRoomMessageActionsModule.openComposer(
      context: context,
      controller: _messageController,
      focusNode: _messageFocusNode,
      imagesEnabled: _roomImagesEnabled,
      onSendText: _sendMessage,
      onImageTap: () =>
          RoomToast.show(context, 'Image message picker will connect here'),
      onSendFloatingText: _sendMessage,
    );
  }

  void _setUserAsAdmin(String userId) {
    Navigator.pop(context);
    if (!_viewerCanManageAdmins) {
      RoomToast.show(context, 'Only channel host can add admins');
      return;
    }
    _seatController.setUserAsAdmin(userId);
    _clearRoomFocus();
  }

  void _removeUserAsAdmin(String userId) {
    Navigator.pop(context);
    if (!_viewerCanManageAdmins) {
      RoomToast.show(context, 'Only channel host can remove admins');
      return;
    }
    _seatController.removeUserAsAdmin(userId);
    _clearRoomFocus();
  }

  void _addRoomAdminFromInfo(SeatUser user) {
    if (!_viewerCanManageAdmins) {
      RoomToast.show(context, 'Only channel host can add admins');
      return;
    }
    _seatController.setUserAsAdmin(user.id);
    _clearRoomFocus();
  }

  void _removeRoomAdminFromInfo(SeatUser user) {
    if (!_viewerCanManageAdmins) {
      RoomToast.show(context, 'Only channel host can remove admins');
      return;
    }
    _seatController.removeUserAsAdmin(user.id);
    _clearRoomFocus();
  }

  void _removeRoomMemberFromInfo(SeatUser user) {
    if (!_viewerCanManageAdmins) {
      RoomToast.show(context, 'Only channel host can remove room members');
      return;
    }
    LiveRoomMemberRequestService.instance.removeRoomMember(user);
    RoomToast.show(context, 'Removing ${user.name} from room members');
    _clearRoomFocus();
  }

  void _openReportForUser(SeatUser user) {
    Navigator.pop(context);
    _openInfoSheet(
      'Report submitted',
      '${user.name} has been sent to the room safety review queue.',
    );
  }

  void _openGiftPanel() {
    _clearRoomFocus();
    LiveRoomGiftActionsModule.openGiftPanel(
      context: context,
      giftController: _giftControllerInstance ??= _createGiftController(),
      roomUsers: _roomUsers,
    );
  }

  void _openInboxPage() {
    _clearRoomFocus();
    LiveRoomInboxActionsModule.openInboxSheet(
      context: context,
      roomStateController: _roomStateController,
    );
  }

  void _openInboxPageFromSheet(BuildContext sheetContext) {
    LiveRoomInboxActionsModule.openInboxSheetAfterClosingCurrentSheet(
      pageContext: context,
      sheetContext: sheetContext,
      roomStateController: _roomStateController,
    );
  }

  void _openEmojiTray() {
    _clearRoomFocus();
    LiveRoomEmojiActionsModule.openEmojiTray(context: context);
  }
}

extension _FirstOrNullOnIterable<T> on Iterable<T> {
  T? get firstOrNull {
    for (final item in this) {
      return item;
    }
    return null;
  }
}
