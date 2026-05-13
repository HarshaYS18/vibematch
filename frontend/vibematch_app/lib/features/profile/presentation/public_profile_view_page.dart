import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/data/auth_api_service.dart';
import '../../auth/models/current_user.dart';
import '../../family/models/family_ui_models.dart';
import '../../family/presentation/family_modular_page.dart';
import '../../presence/data/presence_api_service.dart';
import '../../vip/presentation/vip_program_page.dart';
import '../data/profile_api_service.dart';
import '../data/love_bond_realtime_service.dart';
import '../data/profile_rooms_repository.dart';
import 'models/edit_profile_models.dart';
import 'models/public_profile_models.dart';
import 'profile_qr/profile_qr_pages.dart';
import 'widgets/me_profile_constants.dart';
import 'widgets/public_love_bonds_panel.dart';
import 'widgets/public_profile_widgets.dart';

class PublicProfileViewPage extends StatefulWidget {
  const PublicProfileViewPage({super.key, required this.user, required this.vipLevel, required this.svipLevel, required this.presenceLabel, required this.currentRoomName, required this.relationshipLabel, required this.familyName, required this.familyLevel, this.publicUserId});

  final CurrentUser user;
  final int vipLevel;
  final int svipLevel;
  final String presenceLabel;
  final String? currentRoomName;
  final String relationshipLabel;
  final String familyName;
  final int familyLevel;
  final int? publicUserId;

  @override
  State<PublicProfileViewPage> createState() => _PublicProfileViewPageState();
}

class _PublicProfileViewPageState extends State<PublicProfileViewPage> {
  final PageController _coverController = PageController();
  final ProfileApiService _profileApi = const ProfileApiService();
  final AuthApiService _authApi = const AuthApiService();
  final PresenceApiService _presenceApi = const PresenceApiService();
  Timer? _coverTimer;
  Timer? _presenceTimer;
  StreamSubscription<ProfileRelationshipRealtimeEvent>? _relationshipRealtimeSub;
  int _coverIndex = 0;
  bool _loadingProfile = false;
  bool _followBusy = false;
  String? _profileError;
  CurrentUser? _viewer;
  PublicUserProfile? _backendProfile;
  UserRelationship? _relationship;
  PresenceDto? _presence;
  FamilySummaryDto? _familySummary;
  List<ProfileVibeDto> _profileVibes = const <ProfileVibeDto>[];
  bool _loadingFamily = false;
  bool _loadingVibes = false;
  String? _familyError;
  String? _vibesError;

  bool get _isSelfProfile {
    final viewer = _viewer ?? _authApi.cachedUser;
    final targetPublicId = _targetPublicUserId();
    return viewer != null && targetPublicId > 0 && viewer.publicUserId == targetPublicId;
  }

  @override
  void initState() {
    super.initState();
    _viewer = _authApi.cachedUser;
    _startCoverAutoScroll();
    _startPresencePolling();
    _recordProfileVisit();
    _relationshipRealtimeSub = ProfileRelationshipRealtimeService.instance.events.listen(_onRelationshipRealtimeEvent);
    unawaited(_loadBackendProfile());
    unawaited(_syncPublicLoveBonds());
    unawaited(_loadRealFamilyAndVibes());
  }

  @override
  void dispose() {
    _coverTimer?.cancel();
    _presenceTimer?.cancel();
    _relationshipRealtimeSub?.cancel();
    _coverController.dispose();
    super.dispose();
  }

  int _targetPublicUserId() => widget.publicUserId ?? widget.user.publicUserId;

  Future<void> _syncPublicLoveBonds() async {
    final publicUserId = _targetPublicUserId();
    if (publicUserId <= 0) return;

    try {
      await LoveBondRealtimeService.syncPublicBondsFromBackend(profilePublicUserId: publicUserId);
    } catch (_) {}
  }

  Future<void> _loadRealFamilyAndVibes() async {
    final publicUserId = _targetPublicUserId();
    if (publicUserId <= 0) return;

    setState(() {
      _loadingFamily = true;
      _loadingVibes = true;
      _familyError = null;
      _vibesError = null;
    });

    await Future.wait<void>([_loadPublicFamily(publicUserId), _loadPublicVibes(publicUserId)]);
  }

  Future<void> _loadPublicFamily(int publicUserId) async {
    try {
      final family = await _profileApi.getPublicFamily(publicUserId);
      if (!mounted) return;
      setState(() {
        _familySummary = family;
        _familyError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _familyError = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loadingFamily = false);
    }
  }

  Future<void> _loadPublicVibes(int publicUserId) async {
    try {
      final vibes = await _profileApi.listPublicUserVibes(publicUserId);
      if (!mounted) return;
      setState(() {
        _profileVibes = vibes;
        _vibesError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _vibesError = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loadingVibes = false);
    }
  }

  Future<void> _loadBackendProfile() async {
    final publicUserId = _targetPublicUserId();
    if (publicUserId <= 0) return;
    setState(() { _loadingProfile = true; _profileError = null; });
    try {
      final viewer = await _profileApi.getMe(forceRefresh: false);
      final profile = await _profileApi.getPublicProfile(publicUserId);
      if (!mounted) return;
      setState(() { _viewer = viewer; _backendProfile = profile; _relationship = profile.relationship; });
    } catch (error) {
      if (!mounted) return;
      setState(() => _profileError = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _refreshRelationshipOnly() async {
    final publicUserId = _targetPublicUserId();
    if (publicUserId <= 0 || _isSelfProfile) return;
    try {
      final nextRelationship = await _profileApi.getRelationship(publicUserId);
      if (!mounted) return;
      setState(() => _relationship = nextRelationship);
    } catch (_) {}
  }

  void _onRelationshipRealtimeEvent(ProfileRelationshipRealtimeEvent event) {
    final viewerPublicUserId = (_viewer ?? _authApi.cachedUser)?.publicUserId;
    final targetPublicUserId = _targetPublicUserId();
    if (viewerPublicUserId == null || viewerPublicUserId <= 0) return;
    if (!event.touchesProfile(targetPublicUserId) && !event.touchesProfile(viewerPublicUserId)) return;
    unawaited(_refreshRelationshipOnly());
  }

  void _publishRelationshipRealtime(String action) {
    final viewerPublicUserId = (_viewer ?? _authApi.cachedUser)?.publicUserId;
    final targetPublicUserId = _targetPublicUserId();
    if (viewerPublicUserId == null) return;
    ProfileRelationshipRealtimeService.instance.publish(viewerPublicUserId: viewerPublicUserId, targetPublicUserId: targetPublicUserId, action: action);
  }

  void _recordProfileVisit() {}

  void _startPresencePolling() {
    _presenceTimer?.cancel();
    unawaited(_loadRealtimePresence());
    _presenceTimer = Timer.periodic(const Duration(seconds: 15), (_) => unawaited(_loadRealtimePresence()));
  }

  Future<void> _loadRealtimePresence() async {
    final publicUserId = _targetPublicUserId();
    if (publicUserId <= 0) return;

    try {
      final presence = await _presenceApi.getPublicPresence(publicUserId);
      if (!mounted) return;
      setState(() => _presence = presence);
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
      _coverController.animateToPage(nextIndex, duration: const Duration(milliseconds: 520), curve: Curves.easeOutCubic);
    });
  }

  void _showAction(BuildContext context, String message) {
    ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(SnackBar(content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)), behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF251538)));
  }

  void _showFollowBlockedPopup([String? message]) {
    showPublicProfileAccessDialog(context, title: 'Follow not allowed', message: message?.trim().isNotEmpty == true ? message!.trim() : '${_displayName()} doesn\'t allow you to follow.');
  }

  void _openProfileQrActions() => ProfileQrActionsSheet.show(context, user: widget.user, title: '${_displayName()} QR');

  void _openViewerVipProgram({required int initialTabIndex}) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => VipProgramPage(initialTabIndex: initialTabIndex, vipLevel: _vipLevel(), svipLevel: _svipLevel(), lifetimeRechargeCoins: 0, monthlyRechargeCoins: 0)));
  }

  Future<void> _toggleFollow() async {
    if (_isSelfProfile || _followBusy) return;
    final publicUserId = _targetPublicUserId();
    if (publicUserId <= 0) return;

    final relationship = _relationship;
    final status = _followStatus;
    final shouldUnfollow = status == PublicFollowStatus.following || status == PublicFollowStatus.mutual;

    if (!shouldUnfollow && relationship != null && !relationship.canFollow) {
      _showFollowBlockedPopup(relationship.followBlockReason);
      return;
    }

    setState(() => _followBusy = true);
    try {
      final nextRelationship = shouldUnfollow ? await _profileApi.unfollowUser(publicUserId) : await _profileApi.followUser(publicUserId);
      if (!mounted) return;
      setState(() => _relationship = nextRelationship);
      _publishRelationshipRealtime(shouldUnfollow ? 'unfollow' : (nextRelationship.isFriend ? 'friends' : 'follow'));
      _showAction(context, _followStatus.message);
      unawaited(_refreshRelationshipOnly());
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      if (message.toLowerCase().contains('allow') || message.toLowerCase().contains('block')) { _showFollowBlockedPopup(message); } else { _showAction(context, message); }
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  void _openFamilyPage() {
    final family = _familySummary;
    if (family == null || !family.shouldShow) {
      _showAction(context, 'This user is not in a family yet.');
      return;
    }

    final familyProfile = FamilyProfileUiModel(id: family.safeId, name: family.safeName, minimumVipLabel: 'VIP 0', memberCount: family.memberCount, maxMembers: family.memberCount > 0 ? family.memberCount : 1, rankLabel: 'Family Lv. ${family.level}', ownerUserId: family.ownerPublicUserId?.toString() ?? '', quarterCarryExp: family.totalExp, giftCoinsThisQuarter: family.totalExp, timeMinutesToday: 0);

    Navigator.of(context).push(MaterialPageRoute(builder: (_) => FamilyModularPage(openCurrentFamily: true, initialFamilyProfile: familyProfile)));
  }

  PublicFollowStatus get _followStatus {
    final relationship = _relationship;
    if (relationship == null) return PublicFollowStatus.none;
    if (relationship.isFriend) return PublicFollowStatus.mutual;
    if (relationship.isFollowing) return PublicFollowStatus.following;
    if (relationship.followsMe) return PublicFollowStatus.followBack;
    return PublicFollowStatus.none;
  }

  String _displayName() => _backendProfile?.visibleName ?? widget.user.displayName ?? widget.user.username ?? 'Vibe User';
  String _username() => _backendProfile?.username ?? widget.user.username ?? '';
  String _publicId() => _backendProfile?.visibleId ?? widget.user.displayCustomId?.toString() ?? widget.user.publicUserId.toString();
  String? _avatarUrl() => _backendProfile?.avatarUrl ?? widget.user.avatarUrl;
  bool _showOfficialTick() => _backendProfile?.primaryRoleBadge?.showVerifiedTick == true || widget.user.shouldShowOfficialYellowTick;
  String? _roleTag() => _backendProfile?.primaryRoleBadge?.badgeLabel ?? widget.user.primaryRoleBadge?.badgeLabel ?? MeProfileConstants.roleTagFor(widget.user.primaryRole);
  int _vipLevel() => _backendProfile?.vip.vipLevel ?? widget.vipLevel;
  int _svipLevel() => _backendProfile?.vip.svipLevel ?? widget.svipLevel;
  String _familyName() => _familySummary?.shouldShow == true ? _familySummary!.safeName : '';
  int _familyLevel() => _familySummary?.shouldShow == true ? _familySummary!.level : 0;

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
    return calculateProfileMatchScore(viewerInterests: viewer.interests, profileInterests: profile.interests, viewerGenderPreference: friendGenderPreferenceFromWire(viewer.friendGenderPreference), profileGender: profileGenderFromWire(profile.gender), viewerMaritalPreference: friendMaritalPreferenceFromWire(viewer.friendMaritalPreference), profileMaritalStatus: maritalStatusFromWire(profile.maritalStatus), viewerGender: profileGenderFromWire(viewer.gender), profileGenderPreference: friendGenderPreferenceFromWire(profile.friendGenderPreference));
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _displayName();
    final username = _username();
    final publicId = _publicId();
    final profile = _backendProfile;
    final coverPhotos = _visibleCoverPhotos();

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            if (_loadingProfile)
              const SliverToBoxAdapter(child: LinearProgressIndicator(minHeight: 3, color: Color(0xFF12C7B7), backgroundColor: Color(0xFFECE2D8)))
            else if (_profileError != null)
              SliverToBoxAdapter(child: _PublicProfileBackendError(message: _profileError!, onRetry: _loadBackendProfile)),
            SliverToBoxAdapter(
              child: PublicProfileHeader(
                displayName: displayName,
                username: username,
                publicId: publicId,
                roleTag: _roleTag(),
                roleBadge: _backendProfile?.primaryRoleBadge ?? widget.user.primaryRoleBadge,
                showOfficialTick: _showOfficialTick(),
                vipLevel: _vipLevel(),
                svipLevel: _svipLevel(),
                presenceLabel: _presenceLabel(),
                currentRoomName: _visibleCurrentRoomName(),
                familyName: _familyName(),
                familyLevel: _familyLevel(),
                coverPhotos: coverPhotos,
                avatarUrl: _avatarUrl(),
                coverController: _coverController,
                coverIndex: _coverIndex.clamp(0, coverPhotos.length - 1),
                followStatus: _followStatus,
                matchScore: _matchScore(),
                showSocialActions: !_isSelfProfile,
                followersCount: _relationship?.followersCount,
                followingCount: _relationship?.followingCount,
                roomsCount: const ProfileRoomsRepository().publicRoomsCountFor(publicUserId: _targetPublicUserId()),
                onCoverChanged: (index) => setState(() => _coverIndex = index),
                onBackTap: () => Navigator.pop(context),
                onQrTap: _openProfileQrActions,
                onShareTap: () => _showAction(context, 'Profile share sheet will open.'),
                onAddCoverTap: () => _showAction(context, 'Add cover photos flow will open. Users can upload multiple covers.'),
                onFollowTap: _toggleFollow,
                onMessageTap: _isSelfProfile ? () {} : () => _showAction(context, 'Message request will open.'),
                onRoomTap: () => _showAction(context, 'Open ${_visibleCurrentRoomName() ?? ''} if privacy rules allow it.'),
                onFamilyTap: _openFamilyPage,
                onVipTap: () => _openViewerVipProgram(initialTabIndex: 0),
                onSvipTap: () => _openViewerVipProgram(initialTabIndex: 1),
              ),
            ),
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(18, 16, 18, 0), child: PublicLoveBondsPanel(publicUserId: _targetPublicUserId(), onVisitorTap: () => _showAction(context, 'Bond details are private and cannot be opened by visitors.')))),
            if (profile != null)
              SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(18, 16, 18, 0), child: PublicBioPanel(bio: profile.bio, age: profile.age, gender: displayGenderFromWire(profile.gender), profession: profile.profession, maritalStatus: displayMaritalFromWire(profile.maritalStatus), interests: profile.interests))),
            if (_loadingFamily)
              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(18, 16, 18, 0), child: LinearProgressIndicator(minHeight: 3, color: Color(0xFF12C7B7), backgroundColor: Color(0xFFECE2D8))))
            else if (_familySummary?.shouldShow == true)
              SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(18, 16, 18, 0), child: PublicFamilyPanel(familyName: _familySummary!.safeName, familyLevel: _familySummary!.level, onTap: _openFamilyPage)))
            else if (_familyError != null)
              SliverToBoxAdapter(child: _PublicProfileBackendError(message: _familyError!, onRetry: () => _loadPublicFamily(_targetPublicUserId()))),
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(18, 22, 18, 10), child: Row(children: [Expanded(child: Text('My Vibes (${_profileVibes.length})', style: const TextStyle(color: Color(0xFF251538), fontSize: 23, fontWeight: FontWeight.w900, letterSpacing: -0.4)))]))),
            if (_loadingVibes)
              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(18, 0, 18, 28), child: LinearProgressIndicator(minHeight: 3, color: Color(0xFF6D5DF6), backgroundColor: Color(0xFFECE2D8))))
            else if (_vibesError != null)
              SliverToBoxAdapter(child: _PublicProfileBackendError(message: _vibesError!, onRetry: () => _loadPublicVibes(_targetPublicUserId())))
            else if (_profileVibes.isEmpty)
              const SliverToBoxAdapter(child: _PublicVibesEmptyState())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                sliver: SliverList.separated(
                  itemCount: _profileVibes.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final vibe = _publicVibeItemFromDto(_profileVibes[index]);
                    return PublicVibeCard(vibe: vibe, onTap: () => _showAction(context, 'Vibe details will open.'), onLikeTap: () => _showAction(context, 'Like action will sync with Vibes backend soon.'), onCommentTap: () => _showAction(context, 'Comments will open.'), onShareTap: () => _showAction(context, 'Share this Vibe.'));
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

PublicVibeItem _publicVibeItemFromDto(ProfileVibeDto dto) {
  final mediaType = dto.mediaType.trim().toLowerCase();
  final icon = switch (mediaType) {
    'photo' => Icons.photo_rounded,
    'video' => Icons.play_circle_fill_rounded,
    _ => Icons.notes_rounded,
  };

  final colors = switch (mediaType) {
    'photo' => const <Color>[Color(0xFF6D5DF6), Color(0xFFE84C72)],
    'video' => const <Color>[Color(0xFF12C7B7), Color(0xFF6D5DF6)],
    _ => const <Color>[Color(0xFF251538), Color(0xFFC99A3B)],
  };

  return PublicVibeItem(title: dto.title, mediaType: mediaType.isEmpty ? 'text' : mediaType, timeAgo: dto.timeAgo, body: dto.caption.trim().isEmpty ? 'Shared a Vibe.' : dto.caption.trim(), likes: dto.likesLabel, comments: dto.commentsLabel, icon: icon, colors: colors, mediaUrl: dto.mediaUrl);
}

class _PublicVibesEmptyState extends StatelessWidget {
  const _PublicVibesEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(margin: const EdgeInsets.fromLTRB(18, 0, 18, 28), padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFECE2D8))), child: const Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.auto_awesome_rounded, color: Color(0xFF6D5DF6), size: 34), SizedBox(height: 8), Text('No Vibes yet', style: TextStyle(color: Color(0xFF251538), fontSize: 17, fontWeight: FontWeight.w900)), SizedBox(height: 5), Text('When this user posts real Vibes, they will appear here.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF7B6A86), fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.35))]));
  }
}

class _PublicProfileBackendError extends StatelessWidget {
  const _PublicProfileBackendError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.fromLTRB(18, 8, 18, 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE8C77C))), child: Row(children: [const Icon(Icons.wifi_off_rounded, color: Color(0xFFC99A3B), size: 19), const SizedBox(width: 9), Expanded(child: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w800))), TextButton(onPressed: onRetry, child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w900)))]));
}
