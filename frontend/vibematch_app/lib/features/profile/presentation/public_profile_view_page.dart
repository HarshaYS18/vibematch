import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/data/auth_api_service.dart';
import '../../auth/models/current_user.dart';
import '../../family/models/family_ui_models.dart';
import '../../family/presentation/family_modular_page.dart';
import '../../vip/presentation/vip_program_page.dart';
import '../data/profile_api_service.dart';
import '../data/profile_visitor_repository.dart';
import 'models/edit_profile_models.dart';
import 'models/public_profile_models.dart';
import 'profile_qr/profile_qr_pages.dart';
import 'widgets/me_profile_constants.dart';
import 'widgets/public_love_bonds_panel.dart';
import 'widgets/public_profile_widgets.dart';

class PublicProfileViewPage extends StatefulWidget {
  const PublicProfileViewPage({
    super.key,
    required this.user,
    required this.vipLevel,
    required this.svipLevel,
    required this.presenceLabel,
    required this.currentRoomName,
    required this.relationshipLabel,
    required this.familyName,
    required this.familyLevel,
    this.publicUserId,
  });

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
  static const int _vibesCount = 18;

  final PageController _coverController = PageController();
  final ProfileApiService _profileApi = const ProfileApiService();
  final AuthApiService _authApi = const AuthApiService();
  Timer? _coverTimer;
  int _coverIndex = 0;
  bool _isBlocked = false;
  bool _loadingProfile = false;
  bool _followBusy = false;
  String? _profileError;
  CurrentUser? _viewer;
  PublicUserProfile? _backendProfile;
  UserRelationship? _relationship;

  final List<String> _viewerInterests = const ['Music Rooms', 'Gaming', 'Tech', 'Fitness', 'Live Audio'];
  final List<String> _profileInterests = const ['Music Rooms', 'Gaming', 'Tech', 'Fitness', 'Premium UI', 'Live Audio'];

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
    _recordProfileVisit();
    unawaited(_loadBackendProfile());
  }

  @override
  void dispose() {
    _coverTimer?.cancel();
    _coverController.dispose();
    super.dispose();
  }

  int _targetPublicUserId() => widget.publicUserId ?? widget.user.publicUserId;

  Future<void> _loadBackendProfile() async {
    final publicUserId = _targetPublicUserId();
    if (publicUserId <= 0) return;
    setState(() {
      _loadingProfile = true;
      _profileError = null;
    });
    try {
      final viewer = await _profileApi.getMe(forceRefresh: false);
      final profile = await _profileApi.getPublicProfile(publicUserId);
      if (!mounted) return;
      setState(() {
        _viewer = viewer;
        _backendProfile = profile;
        _relationship = profile.relationship;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _profileError = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  void _recordProfileVisit() {
    final visitor = _authApi.cachedUser;
    if (visitor == null) return;
    if (visitor.publicUserId == _targetPublicUserId()) return;
    ProfileVisitorRepository.instance.recordVisit(
      profileOwner: widget.user,
      visitor: visitor,
    );
  }

  void _startCoverAutoScroll() {
    _coverTimer?.cancel();
    _coverTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted || !_coverController.hasClients || publicProfileCoverPhotos.length < 2) return;
      final nextIndex = (_coverIndex + 1) % publicProfileCoverPhotos.length;
      _coverController.animateToPage(nextIndex, duration: const Duration(milliseconds: 520), curve: Curves.easeOutCubic);
    });
  }

  void _showAction(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)), behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF251538)));
  }

  void _openProfileQrActions() {
    ProfileQrActionsSheet.show(context, user: widget.user, title: '${_displayName()} QR');
  }

  void _openViewerVipProgram({required int initialTabIndex}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VipProgramPage(
          initialTabIndex: initialTabIndex,
          vipLevel: MeProfileConstants.vipLevel,
          svipLevel: MeProfileConstants.svipLevel,
          lifetimeRechargeCoins: MeProfileConstants.diamonds,
          monthlyRechargeCoins: 42000,
        ),
      ),
    );
  }

  Future<void> _toggleFollow() async {
    if (_isSelfProfile) return;
    if (_isBlocked) {
      showPublicProfileAccessDialog(context);
      return;
    }
    if (_followBusy) return;
    final publicUserId = _targetPublicUserId();
    if (publicUserId <= 0) return;

    setState(() => _followBusy = true);
    try {
      final nextRelationship = _relationship?.isFollowing == true
          ? await _profileApi.unfollowUser(publicUserId)
          : await _profileApi.followUser(publicUserId);
      if (!mounted) return;
      setState(() => _relationship = nextRelationship);
      _showAction(context, _followStatus.message);
    } catch (error) {
      if (mounted) _showAction(context, error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  void _openFamilyPage() {
    final familyProfile = FamilyProfileUiModel(
      id: 'VMF6922',
      name: widget.familyName,
      minimumVipLabel: 'VIP 5',
      memberCount: 128,
      maxMembers: 200,
      rankLabel: 'No. 99+',
      ownerUserId: 'family_owner_01',
      quarterCarryExp: 1085000,
      giftCoinsThisQuarter: 1085000,
      timeMinutesToday: 12240,
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

  String _displayName() => _backendProfile?.visibleName ?? widget.user.displayName ?? widget.user.username ?? 'Vibe User';
  String _username() => _backendProfile?.username ?? widget.user.username ?? 'vibe_user';
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

  int _matchScore() {
    return calculateProfileMatchScore(
      viewerInterests: _viewerInterests,
      profileInterests: _profileInterests,
      viewerGenderPreference: FriendGenderPreference.both,
      profileGender: ProfileGender.male,
      viewerMaritalPreference: FriendMaritalPreference.any,
      profileMaritalStatus: MaritalStatus.single,
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _displayName();
    final username = _username();
    final publicId = _publicId();

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
                coverPhotos: publicProfileCoverPhotos,
                coverController: _coverController,
                coverIndex: _coverIndex,
                followStatus: _followStatus,
                matchScore: _matchScore(),
                showSocialActions: !_isSelfProfile,
                followersCount: _relationship?.followersCount,
                followingCount: _relationship?.followingCount,
                onCoverChanged: (index) => setState(() => _coverIndex = index),
                onBackTap: () => Navigator.pop(context),
                onQrTap: _openProfileQrActions,
                onShareTap: () => _showAction(context, 'Profile share sheet will open.'),
                onAddCoverTap: () => _showAction(context, 'Add cover photos flow will open. Users can upload multiple covers.'),
                onFollowTap: _toggleFollow,
                onMessageTap: _isSelfProfile ? () {} : () => _showAction(context, 'Message request will open.'),
                onRoomTap: () => _showAction(context, 'Open ${widget.currentRoomName} if privacy rules allow it.'),
                onFamilyTap: _openFamilyPage,
                onVipTap: () => _openViewerVipProgram(initialTabIndex: 0),
                onSvipTap: () => _openViewerVipProgram(initialTabIndex: 1),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                child: PublicLoveBondsPanel(onVisitorTap: () => _showAction(context, 'Bond details are private and cannot be opened by visitors.')),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                child: PublicBioPanel(
                  bio: 'Type something about yourself.',
                  age: '',
                  gender: '',
                  interests: const [],
                ),
              ),
            ),
            if (widget.familyName.trim().isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                  child: PublicFamilyPanel(familyName: widget.familyName, familyLevel: widget.familyLevel, onTap: _openFamilyPage),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 10),
                child: Row(children: [Expanded(child: Text('My Vibes ($_vibesCount)', style: const TextStyle(color: Color(0xFF251538), fontSize: 23, fontWeight: FontWeight.w900, letterSpacing: -0.4)))]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
              sliver: SliverList.separated(
                itemCount: mockPublicVibes.length,
                separatorBuilder: (context, index) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final vibe = mockPublicVibes[index];
                  return PublicVibeCard(
                    vibe: vibe,
                    onTap: () => _showAction(context, '${vibe.title} vibe details will open.'),
                    onLikeTap: () => _showAction(context, 'Liked this Vibe locally.'),
                    onCommentTap: () => _showAction(context, 'Comments will open.'),
                    onShareTap: () => _showAction(context, 'Share this Vibe.'),
                  );
                },
              ),
            ),
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
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 8, 18, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE8C77C))),
      child: Row(children: [
        const Icon(Icons.wifi_off_rounded, color: Color(0xFFC99A3B), size: 19),
        const SizedBox(width: 9),
        Expanded(child: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w800))),
        TextButton(onPressed: onRetry, child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w900))),
      ]),
    );
  }
}
