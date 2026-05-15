part of 'public_profile_view_page.dart';

extension _PublicProfileViewController on _PublicProfileViewPageState {
  int _targetPublicUserId() => widget.publicUserId ?? widget.user.publicUserId;

  Future<void> _loadEconomyPublicCard() async {
    final publicUserId = _targetPublicUserId();
    if (publicUserId <= 0) return;
    try {
      final card = await _economyApi.getPublicCard(publicUserId);
      if (!mounted) return;
      _setProfileState(() => _economyCard = card);
    } catch (_) {}
  }

  Future<void> _syncPublicLoveBonds() async {
    final publicUserId = _targetPublicUserId();
    if (publicUserId <= 0) return;

    try {
      await LoveBondRealtimeService.syncPublicBondsFromBackend(
        profilePublicUserId: publicUserId,
      );
    } catch (_) {}
  }

  Future<void> _loadRealFamilyAndVibes() async {
    final publicUserId = _targetPublicUserId();
    if (publicUserId <= 0) return;

    _setProfileState(() {
      _loadingFamily = true;
      _loadingVibes = true;
      _familyError = null;
      _vibesError = null;
    });

    await Future.wait<void>([
      _loadPublicFamily(publicUserId),
      _loadPublicVibes(publicUserId),
    ]);
  }

  Future<void> _loadPublicFamily(int publicUserId) async {
    try {
      final family = await _profileApi.getPublicFamily(publicUserId);
      if (!mounted) return;
      _setProfileState(() {
        _familySummary = family;
        _familyError = null;
      });
    } catch (error) {
      if (!mounted) return;
      _setProfileState(
        () => _familyError = error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) _setProfileState(() => _loadingFamily = false);
    }
  }

  Future<void> _loadPublicVibes(int publicUserId) async {
    try {
      final vibes = await _profileApi.listPublicUserVibes(publicUserId);
      if (!mounted) return;
      _setProfileState(() {
        _profileVibes = vibes;
        _vibesError = null;
      });
    } catch (error) {
      if (!mounted) return;
      _setProfileState(
        () => _vibesError = error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) _setProfileState(() => _loadingVibes = false);
    }
  }

  Future<void> _loadBackendProfile() async {
    final publicUserId = _targetPublicUserId();
    if (publicUserId <= 0) return;
    _setProfileState(() {
      _loadingProfile = true;
      _profileError = null;
    });
    try {
      final viewer = await _profileApi.getMe(forceRefresh: false);
      final profile = await _profileApi.getPublicProfile(publicUserId);
      if (!mounted) return;
      _setProfileState(() {
        _viewer = viewer;
        _backendProfile = profile;
        _relationship = profile.relationship;
      });
      unawaited(_loadEconomyPublicCard());
    } catch (error) {
      if (!mounted) return;
      _setProfileState(
        () => _profileError = error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) _setProfileState(() => _loadingProfile = false);
    }
  }

  Future<void> _refreshRelationshipOnly() async {
    final publicUserId = _targetPublicUserId();
    if (publicUserId <= 0 || _isSelfProfile) return;
    try {
      final nextRelationship = await _profileApi.getRelationship(publicUserId);
      if (!mounted) return;
      _setProfileState(() => _relationship = nextRelationship);
    } catch (_) {}
  }

  void _onRelationshipRealtimeEvent(ProfileRelationshipRealtimeEvent event) {
    final viewerPublicUserId = (_viewer ?? _authApi.cachedUser)?.publicUserId;
    final targetPublicUserId = _targetPublicUserId();
    if (viewerPublicUserId == null || viewerPublicUserId <= 0) return;
    if (!event.touchesProfile(targetPublicUserId) &&
        !event.touchesProfile(viewerPublicUserId))
      return;
    unawaited(_refreshRelationshipOnly());
  }

  void _publishRelationshipRealtime(String action) {
    final viewerPublicUserId = (_viewer ?? _authApi.cachedUser)?.publicUserId;
    final targetPublicUserId = _targetPublicUserId();
    if (viewerPublicUserId == null) return;
    ProfileRelationshipRealtimeService.instance.publish(
      viewerPublicUserId: viewerPublicUserId,
      targetPublicUserId: targetPublicUserId,
      action: action,
    );
  }

  void _recordProfileVisit() {}

  void _startPresencePolling() {
    _presenceTimer?.cancel();
    unawaited(_loadRealtimePresence());
    _presenceTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(_loadRealtimePresence()),
    );
  }

  Future<void> _loadRealtimePresence() async {
    final publicUserId = _targetPublicUserId();
    if (publicUserId <= 0) return;

    try {
      final presence = await _presenceApi.getPublicPresence(publicUserId);
      if (!mounted) return;
      _setProfileState(() => _presence = presence);
    } catch (_) {}
  }

  String? _visibleCurrentRoomName() {
    final presence = _presence;
    if (presence == null || !presence.hasVisibleRoom) return null;
    return presence.roomName;
  }

  List<PublicCoverPhoto> _visibleCoverPhotos() {
    final urls = _backendProfile?.coverPhotoUrls ?? widget.user.coverPhotoUrls;
    final covers = publicCoverPhotosFromUrls(urls);
    return covers.isEmpty ? publicProfileCoverPhotos : covers;
  }

  void _startCoverAutoScroll() {
    _coverTimer?.cancel();
    _coverTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final covers = _visibleCoverPhotos();
      if (!mounted || !_coverController.hasClients || covers.length < 2) return;
      final nextIndex = (_coverIndex + 1) % covers.length;
      _coverController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _showAction(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF251538),
        ),
      );
  }

  void _showFollowBlockedPopup([String? message]) {
    showPublicProfileAccessDialog(
      context,
      title: 'Follow not allowed',
      message: message?.trim().isNotEmpty == true
          ? message!.trim()
          : '${_displayName()} doesn\'t allow you to follow.',
    );
  }

  void _openProfileQrActions() => ProfileQrActionsSheet.show(
    context,
    user: widget.user,
    title: '${_displayName()} QR',
  );

  void _openViewerVipProgram({required int initialTabIndex}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VipProgramPage(
          initialTabIndex: initialTabIndex,
          vipLevel: _vipLevel(),
          svipLevel: _svipLevel(),
          lifetimeRechargeCoins: 0,
          monthlyRechargeCoins: 0,
        ),
      ),
    );
  }

  Future<void> _toggleFollow() async {
    if (_isSelfProfile || _followBusy) return;
    final publicUserId = _targetPublicUserId();
    if (publicUserId <= 0) return;

    final relationship = _relationship;
    final status = _followStatus;
    final shouldUnfollow =
        status == PublicFollowStatus.following ||
        status == PublicFollowStatus.mutual;

    if (!shouldUnfollow && relationship != null && !relationship.canFollow) {
      _showFollowBlockedPopup(relationship.followBlockReason);
      return;
    }

    _setProfileState(() => _followBusy = true);
    try {
      final nextRelationship = shouldUnfollow
          ? await _profileApi.unfollowUser(publicUserId)
          : await _profileApi.followUser(publicUserId);
      if (!mounted) return;
      _setProfileState(() => _relationship = nextRelationship);
      _publishRelationshipRealtime(
        shouldUnfollow
            ? 'unfollow'
            : (nextRelationship.isFriend ? 'friends' : 'follow'),
      );
      _showAction(context, _followStatus.message);
      unawaited(_refreshRelationshipOnly());
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      if (message.toLowerCase().contains('allow') ||
          message.toLowerCase().contains('block')) {
        _showFollowBlockedPopup(message);
      } else {
        _showAction(context, message);
      }
    } finally {
      if (mounted) _setProfileState(() => _followBusy = false);
    }
  }

  void _openFamilyPage() {
    final family = _familySummary;
    if (family == null || !family.shouldShow) {
      _showAction(context, 'This user is not in a family yet.');
      return;
    }

    final familyProfile = FamilyProfileUiModel(
      id: family.safeId,
      name: family.safeName,
      minimumVipLabel: 'VIP 0',
      memberCount: family.memberCount,
      maxMembers: family.memberCount > 0 ? family.memberCount : 1,
      rankLabel: 'Family Lv. ${family.level}',
      ownerUserId: family.ownerPublicUserId?.toString() ?? '',
      quarterCarryExp: family.totalExp,
      giftCoinsThisQuarter: family.totalExp,
      timeMinutesToday: 0,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FamilyModularPage(
          openCurrentFamily: true,
          initialFamilyProfile: familyProfile,
        ),
      ),
    );
  }

  PublicFollowStatus get _followStatus {
    final relationship = _relationship;
    if (relationship == null) return PublicFollowStatus.none;
    if (relationship.isFriend) return PublicFollowStatus.mutual;
    if (relationship.isFollowing) return PublicFollowStatus.following;
    if (relationship.followsMe) return PublicFollowStatus.followBack;
    return PublicFollowStatus.none;
  }

  String _displayName() =>
      _backendProfile?.visibleName ??
      _economyCard?.displayName ??
      widget.user.displayName ??
      widget.user.username ??
      'Vibe User';
  String _username() => _backendProfile?.username ?? widget.user.username ?? '';
  String _publicId() =>
      _backendProfile?.visibleId ??
      widget.user.displayCustomId?.toString() ??
      widget.user.publicUserId.toString();
  String? _avatarUrl() => _backendProfile?.avatarUrl ?? _economyCard?.avatarUrl ?? widget.user.avatarUrl;
  bool _showOfficialTick() =>
      _backendProfile?.primaryRoleBadge?.showVerifiedTick == true ||
      widget.user.shouldShowOfficialYellowTick;
  String? _roleTag() =>
      _backendProfile?.primaryRoleBadge?.badgeLabel ??
      widget.user.primaryRoleBadge?.badgeLabel ??
      MeProfileConstants.roleTagFor(widget.user.primaryRole);
  int _vipLevel() => _economyCard?.vipLevel ?? _backendProfile?.vip.vipLevel ?? widget.vipLevel;
  int _svipLevel() => _economyCard?.svipLevel ?? _backendProfile?.vip.svipLevel ?? widget.svipLevel;
  int _sentLevel() =>
      _economyCard?.sendLevel ??
      _backendProfile?.wallet.sendLevel ??
      widget.user.wallet.sendLevel;
  int _receiveLevel() =>
      _economyCard?.receiveLevel ??
      _backendProfile?.wallet.receiveLevel ??
      widget.user.wallet.receiveLevel;
  int _monthlyGiftCoinsSent() =>
      _economyCard?.monthlySentCoins ??
      _backendProfile?.wallet.monthlyGiftCoinsSent ??
      widget.user.wallet.monthlyGiftCoinsSent;
  int _monthlyGiftCoinsReceived() =>
      _economyCard?.monthlyReceivedCoins ??
      _backendProfile?.wallet.monthlyGiftCoinsReceived ??
      widget.user.wallet.monthlyGiftCoinsReceived;
  String _familyName() =>
      _familySummary?.shouldShow == true ? _familySummary!.safeName : '';
  int _familyLevel() =>
      _familySummary?.shouldShow == true ? _familySummary!.level : 0;

  String _presenceLabel() {
    final realtime = _presence;
    if (realtime != null) return realtime.onlineLabel;
    final profile = _backendProfile;
    if (profile == null) return widget.presenceLabel;
    if (profile.isOnline) return 'Online';
    final lastSeen = profile.lastSeenAt;
    if (lastSeen == null) return 'Offline';
    final diff = DateTime.now().difference(lastSeen.toLocal());
    if (diff.inMinutes < 1) return 'last seen just now';
    if (diff.inMinutes < 60) return 'last seen ${diff.inMinutes} min ago';
    if (diff.inHours < 24) return 'last seen ${diff.inHours} hour ago';
    if (diff.inDays < 30) return 'last seen ${diff.inDays} day ago';
    return 'last seen a month ago';
  }

  int? _matchScore() {
    if (_isSelfProfile) return null;
    final viewer = _viewer;
    final profile = _backendProfile;
    if (viewer == null || profile == null) return null;
    return calculateProfileMatchScore(
      viewerInterests: viewer.interests,
      profileInterests: profile.interests,
      viewerGenderPreference: friendGenderPreferenceFromWire(
        viewer.friendGenderPreference,
      ),
      profileGender: profileGenderFromWire(profile.gender),
      viewerMaritalPreference: friendMaritalPreferenceFromWire(
        viewer.friendMaritalPreference,
      ),
      profileMaritalStatus: maritalStatusFromWire(profile.maritalStatus),
      viewerGender: profileGenderFromWire(viewer.gender),
      profileGenderPreference: friendGenderPreferenceFromWire(
        profile.friendGenderPreference,
      ),
    );
  }
}
