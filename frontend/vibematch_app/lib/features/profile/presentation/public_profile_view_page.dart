import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/models/current_user.dart';
import 'models/public_profile_models.dart';
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
  });

  final CurrentUser user;
  final int vipLevel;
  final int svipLevel;
  final String presenceLabel;
  final String? currentRoomName;
  final String relationshipLabel;
  final String familyName;
  final int familyLevel;

  @override
  State<PublicProfileViewPage> createState() => _PublicProfileViewPageState();
}

class _PublicProfileViewPageState extends State<PublicProfileViewPage> {
  static const int _vibesCount = 18;

  final PageController _coverController = PageController();
  Timer? _coverTimer;
  int _coverIndex = 0;
  bool _viewerFollowsProfile = false;
  final bool _profileFollowsViewer = true;
  final bool _isBlocked = false;

  @override
  void initState() {
    super.initState();
    _startCoverAutoScroll();
  }

  @override
  void dispose() {
    _coverTimer?.cancel();
    _coverController.dispose();
    super.dispose();
  }

  void _startCoverAutoScroll() {
    _coverTimer?.cancel();
    _coverTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted ||
          !_coverController.hasClients ||
          publicProfileCoverPhotos.length < 2) {
        return;
      }

      final nextIndex = (_coverIndex + 1) % publicProfileCoverPhotos.length;
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

  void _toggleFollow() {
    if (_isBlocked) {
      showPublicProfileAccessDialog(context);
      return;
    }

    setState(() {
      _viewerFollowsProfile = !_viewerFollowsProfile;
    });

    _showAction(context, _followStatus.message);
  }

  PublicFollowStatus get _followStatus {
    if (_viewerFollowsProfile && _profileFollowsViewer) {
      return PublicFollowStatus.mutual;
    }

    if (_viewerFollowsProfile) {
      return PublicFollowStatus.following;
    }

    if (_profileFollowsViewer) {
      return PublicFollowStatus.followBack;
    }

    return PublicFollowStatus.none;
  }

  String _displayName() {
    return widget.user.displayName ?? widget.user.username ?? 'Vibe User';
  }

  String _username() {
    return widget.user.username ?? 'vibe_user';
  }

  String _publicId() {
    return widget.user.displayCustomId?.toString() ??
        widget.user.publicUserId.toString();
  }

  bool _showOfficialTick() {
    final role = widget.user.primaryRole.toLowerCase().trim();
    return role == 'founder_owner' || role == 'super_owner' || role == 'owner';
  }

  String? _roleTag() {
    final role = widget.user.primaryRole.toLowerCase().trim();

    if (role == 'founder_owner') return 'Founder Owner';
    if (role == 'super_owner') return 'Super Owner';
    if (role == 'owner') return 'Owner';
    if (role == 'superadmin') return 'SuperAdmin';
    if (role == 'admin') return 'Admin';
    if (role == 'monitor') return 'Monitor';
    if (role == 'cs') return 'CS';

    return null;
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
            SliverToBoxAdapter(
              child: PublicProfileHeader(
                displayName: displayName,
                username: username,
                publicId: publicId,
                roleTag: _roleTag(),
                showOfficialTick: _showOfficialTick(),
                vipLevel: widget.vipLevel,
                svipLevel: widget.svipLevel,
                presenceLabel: widget.presenceLabel,
                currentRoomName: widget.currentRoomName,
                familyName: widget.familyName,
                familyLevel: widget.familyLevel,
                coverPhotos: publicProfileCoverPhotos,
                coverController: _coverController,
                coverIndex: _coverIndex,
                followStatus: _followStatus,
                onCoverChanged: (index) => setState(() => _coverIndex = index),
                onBackTap: () => Navigator.pop(context),
                onShareTap: () => _showAction(
                  context,
                  'Profile share sheet will open.',
                ),
                onAddCoverTap: () => _showAction(
                  context,
                  'Add cover photos flow will open. Users can upload multiple covers.',
                ),
                onFollowTap: _toggleFollow,
                onMessageTap: () => _showAction(
                  context,
                  'Message request will open.',
                ),
                onRoomTap: () => _showAction(
                  context,
                  'Open ${widget.currentRoomName} if privacy rules allow it.',
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(18, 16, 18, 0),
                child: PublicBioPanel(
                  bio:
                      'Building premium live rooms, Vibes, gifts, games and a trusted social-audio community.',
                  age: '27',
                  gender: 'Male',
                  interests: [
                    'Music Rooms',
                    'Gaming',
                    'Tech',
                    'Fitness',
                    'Premium UI',
                    'Live Audio',
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                child: PublicFamilyPanel(
                  familyName: widget.familyName,
                  familyLevel: widget.familyLevel,
                  onTap: () => _showAction(
                    context,
                    'Family profile will open.',
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'My Vibes ($_vibesCount)',
                        style: const TextStyle(
                          color: Color(0xFF251538),
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                  ],
                ),
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
                    onTap: () => _showAction(
                      context,
                      '${vibe.title} vibe details will open.',
                    ),
                    onLikeTap: () => _showAction(
                      context,
                      'Liked this Vibe locally.',
                    ),
                    onCommentTap: () => _showAction(
                      context,
                      'Comments will open.',
                    ),
                    onShareTap: () => _showAction(
                      context,
                      'Share this Vibe.',
                    ),
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
