import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/data/auth_api_service.dart';
import '../../auth/models/current_user.dart';
import '../../economy/data/economy_master_api_service.dart';
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

part 'public_profile_view_controller.dart';
part 'public_profile_view_support.dart';

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
  final PageController _coverController = PageController();
  final ProfileApiService _profileApi = const ProfileApiService();
  final AuthApiService _authApi = const AuthApiService();
  final PresenceApiService _presenceApi = const PresenceApiService();
  final EconomyMasterApiService _economyApi = const EconomyMasterApiService();
  Timer? _coverTimer;
  Timer? _presenceTimer;
  StreamSubscription<ProfileRelationshipRealtimeEvent>?
  _relationshipRealtimeSub;
  int _coverIndex = 0;
  bool _loadingProfile = false;
  bool _followBusy = false;
  String? _profileError;
  CurrentUser? _viewer;
  PublicUserProfile? _backendProfile;
  EconomyPublicCardSnapshot? _economyCard;
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
    return viewer != null &&
        targetPublicId > 0 &&
        viewer.publicUserId == targetPublicId;
  }

  @override
  void initState() {
    super.initState();
    _viewer = _authApi.cachedUser;
    _startCoverAutoScroll();
    _startPresencePolling();
    _recordProfileVisit();
    _relationshipRealtimeSub = ProfileRelationshipRealtimeService
        .instance
        .events
        .listen(_onRelationshipRealtimeEvent);
    unawaited(_loadBackendProfile());
    unawaited(_syncPublicLoveBonds());
    unawaited(_loadRealFamilyAndVibes());
    unawaited(_loadEconomyPublicCard());
  }

  @override
  void dispose() {
    _coverTimer?.cancel();
    _presenceTimer?.cancel();
    _relationshipRealtimeSub?.cancel();
    _coverController.dispose();
    super.dispose();
  }

  void _setProfileState(VoidCallback update) => setState(update);

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
              const SliverToBoxAdapter(
                child: LinearProgressIndicator(
                  minHeight: 3,
                  color: Color(0xFF12C7B7),
                  backgroundColor: Color(0xFFECE2D8),
                ),
              )
            else if (_profileError != null)
              SliverToBoxAdapter(
                child: _PublicProfileBackendError(
                  message: _profileError!,
                  onRetry: _loadBackendProfile,
                ),
              ),
            SliverToBoxAdapter(
              child: PublicProfileHeader(
                displayName: displayName,
                username: username,
                publicId: publicId,
                roleTag: _roleTag(),
                roleBadge:
                    _backendProfile?.primaryRoleBadge ??
                    widget.user.primaryRoleBadge,
                showOfficialTick: _showOfficialTick(),
                vipLevel: _vipLevel(),
                svipLevel: _svipLevel(),
                sentLevel: _sentLevel(),
                receiveLevel: _receiveLevel(),
                monthlyGiftCoinsSent: _monthlyGiftCoinsSent(),
                monthlyGiftCoinsReceived: _monthlyGiftCoinsReceived(),
                presenceLabel: _presenceLabel(),
                currentRoomName: _visibleCurrentRoomName(),
                familyName: _familyName(),
                familyLevel: _familyLevel(),
                coverPhotos: coverPhotos,
                avatarUrl: _avatarUrl(),
                nameGradientColors: _backendProfile?.vip.nameGradientColors ?? widget.user.vip.nameGradientColors,
                coverController: _coverController,
                coverIndex: _coverIndex.clamp(0, coverPhotos.length - 1),
                followStatus: _followStatus,
                matchScore: _matchScore(),
                showSocialActions: !_isSelfProfile,
                followersCount: _relationship?.followersCount,
                followingCount: _relationship?.followingCount,
                roomsCount: const ProfileRoomsRepository().publicRoomsCountFor(
                  publicUserId: _targetPublicUserId(),
                ),
                onCoverChanged: (index) => setState(() => _coverIndex = index),
                onBackTap: () => Navigator.pop(context),
                onQrTap: _openProfileQrActions,
                onShareTap: () =>
                    _showAction(context, 'Profile share sheet will open.'),
                onAddCoverTap: () => _showAction(
                  context,
                  'Add cover photos flow will open. Users can upload multiple covers.',
                ),
                onFollowTap: _toggleFollow,
                onMessageTap: _isSelfProfile
                    ? () {}
                    : () => _showAction(context, 'Message request will open.'),
                onRoomTap: () => _showAction(
                  context,
                  'Open ${_visibleCurrentRoomName() ?? ''} if privacy rules allow it.',
                ),
                onFamilyTap: _openFamilyPage,
                onVipTap: () => _openViewerVipProgram(initialTabIndex: 0),
                onSvipTap: () => _openViewerVipProgram(initialTabIndex: 1),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                child: PublicLoveBondsPanel(
                  publicUserId: _targetPublicUserId(),
                  onVisitorTap: () => _showAction(
                    context,
                    'Bond details are private and cannot be opened by visitors.',
                  ),
                ),
              ),
            ),
            if (profile != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                  child: PublicBioPanel(
                    bio: profile.bio,
                    age: profile.age,
                    gender: displayGenderFromWire(profile.gender),
                    profession: profile.profession,
                    maritalStatus: displayMaritalFromWire(
                      profile.maritalStatus,
                    ),
                    interests: profile.interests,
                  ),
                ),
              ),
            if (_loadingFamily)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(18, 16, 18, 0),
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    color: Color(0xFF12C7B7),
                    backgroundColor: Color(0xFFECE2D8),
                  ),
                ),
              )
            else if (_familySummary?.shouldShow == true)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                  child: PublicFamilyPanel(
                    familyName: _familySummary!.name?.trim().isNotEmpty == true
                        ? _familySummary!.name!.trim()
                        : 'Family',
                    familyLevel: _familySummary!.level,
                    onTap: _openFamilyPage,
                  ),
                ),
              )
            else if (_familyError != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                  child: _PublicProfileBackendError(
                    message: _familyError!,
                    onRetry: _loadRealFamilyAndVibes,
                  ),
                ),
              ),
            if (_loadingVibes)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(18, 16, 18, 0),
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    color: Color(0xFF12C7B7),
                    backgroundColor: Color(0xFFECE2D8),
                  ),
                ),
              )
            else if (_profileVibes.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                  child: Column(
                    children: [
                      for (final vibe in _profileVibes.map(_publicVibeItemFromDto)) ...[
                        PublicVibeCard(
                          vibe: vibe,
                          onTap: () => _showAction(
                            context,
                            'Open Vibe details for ${vibe.title}.',
                          ),
                          onLikeTap: () => _showAction(context, 'Like action will sync.'),
                          onCommentTap: () => _showAction(context, 'Comments will open.'),
                          onShareTap: () => _showAction(context, 'Share sheet will open.'),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              )
            else if (_vibesError != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                  child: _PublicProfileBackendError(
                    message: _vibesError!,
                    onRetry: _loadRealFamilyAndVibes,
                  ),
                ),
              )
            else
              const SliverToBoxAdapter(child: _PublicVibesEmptyState()),
          ],
        ),
      ),
    );
  }
}
