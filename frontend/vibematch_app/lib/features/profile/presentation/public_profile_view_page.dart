import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/data/auth_api_service.dart';
import '../../auth/models/current_user.dart';
import '../../vip/presentation/vip_program_page.dart';
import '../data/profile_api_service.dart';
import '../data/profile_visitor_repository.dart';
import 'models/edit_profile_models.dart';
import 'models/public_profile_models.dart';
import 'profile_qr/profile_qr_pages.dart';
import 'widgets/me_profile_constants.dart';
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
  Timer? _coverTimer;
  StreamSubscription<ProfileRelationshipRealtimeEvent>? _relationshipRealtimeSub;
  int _coverIndex = 0;
  bool _loadingProfile = false;
  bool _followBusy = false;
  String? _profileError;
  CurrentUser? _viewer;
  PublicUserProfile? _backendProfile;
  UserRelationship? _relationship;

  bool get _isSelfProfile {
    final viewer = _viewer ?? _authApi.cachedUser;
    final targetPublicId = _targetPublicUserId();
    return viewer != null && targetPublicId > 0 && viewer.publicUserId == targetPublicId;
  }

  List<PublicCoverPhoto> get _coverPhotos {
    final urls = _backendProfile?.coverPhotoUrls ?? widget.user.coverPhotoUrls;
    return publicCoverPhotosFromUrls(urls);
  }

  @override
  void initState() {
    super.initState();
    _viewer = _authApi.cachedUser;
    _recordProfileVisit();
    _relationshipRealtimeSub = ProfileRelationshipRealtimeService.instance.events.listen(_onRelationshipRealtimeEvent);
    unawaited(_loadBackendProfile());
  }

  @override
  void dispose() {
    _coverTimer?.cancel();
    _relationshipRealtimeSub?.cancel();
    _coverController.dispose();
    super.dispose();
  }

  int _targetPublicUserId() => widget.publicUserId ?? widget.user.publicUserId;

  Future<void> _loadBackendProfile() async {
    final publicUserId = _targetPublicUserId();
    if (publicUserId <= 0) return;
    setState(() { _loadingProfile = true; _profileError = null; });
    try {
      final viewer = await _profileApi.getMe(forceRefresh: false);
      final profile = await _profileApi.getPublicProfile(publicUserId);
      if (!mounted) return;
      setState(() { _viewer = viewer; _backendProfile = profile; _relationship = profile.relationship; _coverIndex = 0; });
      _startCoverAutoScroll();
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

  void _recordProfileVisit() {
    final visitor = _authApi.cachedUser;
    if (visitor == null) return;
    if (visitor.publicUserId == _targetPublicUserId()) return;
    ProfileVisitorRepository.instance.recordVisit(profileOwner: widget.user, visitor: visitor);
  }

  void _startCoverAutoScroll() {
    _coverTimer?.cancel();
    final photos = _coverPhotos;
    if (photos.length < 2) return;
    _coverTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final currentPhotos = _coverPhotos;
      if (!mounted || !_coverController.hasClients || currentPhotos.length < 2) return;
      final nextIndex = (_coverIndex + 1) % currentPhotos.length;
      _coverController.animateToPage(nextIndex, duration: const Duration(milliseconds: 520), curve: Curves.easeOutCubic);
    });
  }

  void _showAction(BuildContext context, String message) {
    ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(SnackBar(content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)), behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF251538)));
  }

  void _showFollowBlockedPopup([String? message]) {
    showPublicProfileAccessDialog(context, title: 'Follow not allowed', message: message?.trim().isNotEmpty == true ? message!.trim() : '${_displayName()} doesn\'t allow you to follow them.');
  }

  void _openProfileQrActions() => ProfileQrActionsSheet.show(context, user: widget.user, title: '${_displayName()} QR');

  void _openViewerVipProgram({required int initialTabIndex}) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => VipProgramPage(initialTabIndex: initialTabIndex, vipLevel: MeProfileConstants.vipLevel, svipLevel: MeProfileConstants.svipLevel, lifetimeRechargeCoins: MeProfileConstants.diamonds, monthlyRechargeCoins: 42000)));
  }

  Future<void> _toggleFollow() async {
    if (_isSelfProfile || _followBusy) return;
    final publicUserId = _targetPublicUserId();
    if (publicUserId <= 0) return;
    final relationship = _relationship;
    if (relationship != null && !relationship.canFollow && relationship.isFollowing != true) { _showFollowBlockedPopup(relationship.followBlockReason); return; }
    setState(() => _followBusy = true);
    try {
      final wasFollowing = _relationship?.isFollowing == true;
      final nextRelationship = wasFollowing ? await _profileApi.unfollowUser(publicUserId) : await _profileApi.followUser(publicUserId);
      if (!mounted) return;
      setState(() => _relationship = nextRelationship);
      _publishRelationshipRealtime(wasFollowing ? 'unfollow' : 'follow');
      _showAction(context, _followStatus.message);
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      if (message.toLowerCase().contains('allow') || message.toLowerCase().contains('block')) { _showFollowBlockedPopup(message); } else { _showAction(context, message); }
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
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
  bool _showOfficialTick() => _backendProfile?.primaryRoleBadge?.showVerifiedTick == true || widget.user.shouldShowOfficialYellowTick;
  String? _roleTag() => _backendProfile?.primaryRoleBadge?.badgeLabel ?? widget.user.primaryRoleBadge?.badgeLabel ?? MeProfileConstants.roleTagFor(widget.user.primaryRole);
  int _vipLevel() => _backendProfile?.vip.vipLevel ?? widget.vipLevel;
  int _svipLevel() => _backendProfile?.vip.svipLevel ?? widget.svipLevel;

  String _presenceLabel() {
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
    final coverPhotos = _coverPhotos;

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
                currentRoomName: widget.currentRoomName,
                familyName: widget.familyName,
                familyLevel: widget.familyLevel,
                coverPhotos: coverPhotos,
                coverController: _coverController,
                coverIndex: _coverIndex.clamp(0, coverPhotos.isEmpty ? 0 : coverPhotos.length - 1),
                followStatus: _followStatus,
                matchScore: _matchScore(),
                showSocialActions: !_isSelfProfile,
                followersCount: _relationship?.followersCount,
                followingCount: _relationship?.followingCount,
                onCoverChanged: (index) => setState(() => _coverIndex = index),
                onBackTap: () => Navigator.pop(context),
                onQrTap: _openProfileQrActions,
                onShareTap: () => _showAction(context, 'Profile share sheet will open.'),
                onAddCoverTap: () => _showAction(context, 'Cover photos can be edited from your own profile.'),
                onFollowTap: _toggleFollow,
                onMessageTap: _isSelfProfile ? () {} : () => _showAction(context, 'Message request will open.'),
                onRoomTap: () => _showAction(context, 'Open ${widget.currentRoomName} if privacy rules allow it.'),
                onFamilyTap: () => _showAction(context, 'Family profile will open when backend family is connected.'),
                onVipTap: () => _openViewerVipProgram(initialTabIndex: 0),
                onSvipTap: () => _openViewerVipProgram(initialTabIndex: 1),
              ),
            ),
            if (profile != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                  child: PublicBioPanel(bio: profile.bio, age: profile.age, gender: displayGenderFromWire(profile.gender), profession: profile.profession, maritalStatus: displayMaritalFromWire(profile.maritalStatus), interests: profile.interests),
                ),
              ),
            if (widget.familyName.trim().isNotEmpty)
              SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(18, 16, 18, 28), child: PublicFamilyPanel(familyName: widget.familyName, familyLevel: widget.familyLevel, onTap: () => _showAction(context, 'Family profile will open when backend family is connected.')))),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        ),
      ),
    );
  }
}

class _PublicProfileBackendError extends StatelessWidget {
  const _PublicProfileBackendError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.fromLTRB(18, 8, 18, 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE8C77C))), child: Row(children: [const Icon(Icons.wifi_off_rounded, color: Color(0xFFC99A3B), size: 19), const SizedBox(width: 9), Expanded(child: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w800))), TextButton(onPressed: onRetry, child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w900)))]));
}
