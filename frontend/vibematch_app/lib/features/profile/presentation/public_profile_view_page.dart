import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/models/current_user.dart';

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
  bool _profileFollowsViewer = true;
  bool _isBlocked = false;

  final List<_CoverPhoto> _coverPhotos = const [
    _CoverPhoto(
      title: 'Royal Vibe',
      colors: [
        Color(0xFF251538),
        Color(0xFF6D5DF6),
        Color(0xFFE84C72),
      ],
      icon: Icons.auto_awesome_rounded,
    ),
    _CoverPhoto(
      title: 'Music Night',
      colors: [
        Color(0xFF064D46),
        Color(0xFF12C7B7),
        Color(0xFFFFD36A),
      ],
      icon: Icons.music_note_rounded,
    ),
    _CoverPhoto(
      title: 'Family Moment',
      colors: [
        Color(0xFF5C102B),
        Color(0xFFE84C72),
        Color(0xFFFFC857),
      ],
      icon: Icons.groups_rounded,
    ),
  ];

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
      if (!mounted || !_coverController.hasClients || _coverPhotos.length < 2) {
        return;
      }

      final nextIndex = (_coverIndex + 1) % _coverPhotos.length;
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
      _showBlockedFollowPopup();
      return;
    }

    setState(() {
      _viewerFollowsProfile = !_viewerFollowsProfile;
    });

    final status = _followStatus;

    _showAction(
      context,
      status.message,
    );
  }

  void _showBlockedFollowPopup() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.38),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 26),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFECE2D8)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF251538).withValues(alpha: 0.18),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 64,
                  width: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF251538),
                        Color(0xFFE84C72),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE84C72).withValues(alpha: 0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.block_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Vibe Match Notice',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF251538),
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'You have been blocked by this user, so you can’t follow them.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF6F637A),
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF251538),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Okay',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  _FollowStatus get _followStatus {
    if (_viewerFollowsProfile && _profileFollowsViewer) {
      return _FollowStatus.mutual;
    }

    if (_viewerFollowsProfile) {
      return _FollowStatus.following;
    }

    if (_profileFollowsViewer) {
      return _FollowStatus.followBack;
    }

    return _FollowStatus.none;
  }

  String _displayName() {
    return widget.user.displayName ?? widget.user.username ?? 'Vibe User';
  }

  String _username() {
    return widget.user.username ?? 'vibe_user';
  }

  String _publicId() {
    return widget.user.displayCustomId?.toString() ?? widget.user.publicUserId.toString();
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
              child: _PublicProfileHeader(
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
                coverPhotos: _coverPhotos,
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
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                child: _PublicBioPanel(
                  bio:
                      'Building premium live rooms, Vibes, gifts, games and a trusted social-audio community.',
                  age: '27',
                  gender: 'Male',
                  interests: const [
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
                child: _PublicFamilyPanel(
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
                  children: const [
                    Expanded(
                      child: Text(
                        'My Vibes ($_vibesCount)',
                        style: TextStyle(
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
                itemCount: _mockPublicVibes.length,
                separatorBuilder: (context, index) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final vibe = _mockPublicVibes[index];

                  return _PublicVibeCard(
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

enum _FollowStatus {
  none,
  following,
  followBack,
  mutual;

  String get label {
    switch (this) {
      case _FollowStatus.none:
        return 'Follow';
      case _FollowStatus.following:
        return 'Following';
      case _FollowStatus.followBack:
        return 'Follow Back';
      case _FollowStatus.mutual:
        return 'Mutual';
    }
  }

  IconData get icon {
    switch (this) {
      case _FollowStatus.none:
        return Icons.person_add_alt_1_rounded;
      case _FollowStatus.following:
        return Icons.how_to_reg_rounded;
      case _FollowStatus.followBack:
        return Icons.person_add_alt_1_rounded;
      case _FollowStatus.mutual:
        return Icons.handshake_rounded;
    }
  }

  String get message {
    switch (this) {
      case _FollowStatus.none:
        return 'Unfollowed this profile.';
      case _FollowStatus.following:
        return 'You are now following this profile.';
      case _FollowStatus.followBack:
        return 'This user follows you. Tap Follow Back to become mutual.';
      case _FollowStatus.mutual:
        return 'You both follow each other now.';
    }
  }
}

class _CoverPhoto {
  const _CoverPhoto({
    required this.title,
    required this.colors,
    required this.icon,
  });

  final String title;
  final List<Color> colors;
  final IconData icon;
}

class _PublicProfileHeader extends StatelessWidget {
  const _PublicProfileHeader({
    required this.displayName,
    required this.username,
    required this.publicId,
    required this.roleTag,
    required this.showOfficialTick,
    required this.vipLevel,
    required this.svipLevel,
    required this.presenceLabel,
    required this.currentRoomName,
    required this.familyName,
    required this.familyLevel,
    required this.coverPhotos,
    required this.coverController,
    required this.coverIndex,
    required this.followStatus,
    required this.onCoverChanged,
    required this.onBackTap,
    required this.onShareTap,
    required this.onAddCoverTap,
    required this.onFollowTap,
    required this.onMessageTap,
    required this.onRoomTap,
  });

  final String displayName;
  final String username;
  final String publicId;
  final String? roleTag;
  final bool showOfficialTick;
  final int vipLevel;
  final int svipLevel;
  final String presenceLabel;
  final String? currentRoomName;
  final String familyName;
  final int familyLevel;
  final List<_CoverPhoto> coverPhotos;
  final PageController coverController;
  final int coverIndex;
  final _FollowStatus followStatus;
  final ValueChanged<int> onCoverChanged;
  final VoidCallback onBackTap;
  final VoidCallback onShareTap;
  final VoidCallback onAddCoverTap;
  final VoidCallback onFollowTap;
  final VoidCallback onMessageTap;
  final VoidCallback onRoomTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      decoration: _whitePanelDecoration(radius: 34),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                height: 164,
                child: PageView.builder(
                  controller: coverController,
                  itemCount: coverPhotos.length,
                  onPageChanged: onCoverChanged,
                  itemBuilder: (context, index) {
                    final cover = coverPhotos[index];
                    return _CoverPhotoView(cover: cover);
                  },
                ),
              ),
              Positioned(
                left: 14,
                top: 14,
                child: _HeaderIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: onBackTap,
                ),
              ),
              Positioned(
                right: 14,
                top: 14,
                child: Row(
                  children: [
                    _HeaderIconButton(
                      icon: Icons.ios_share_rounded,
                      onTap: onShareTap,
                    ),
                    const SizedBox(width: 8),
                    _HeaderIconButton(
                      icon: Icons.edit_rounded,
                      onTap: onAddCoverTap,
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 16,
                bottom: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.image_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${coverPhotos.length} cover photos',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 18,
                bottom: 18,
                child: Row(
                  children: List.generate(
                    coverPhotos.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(left: 5),
                      height: 6,
                      width: coverIndex == index ? 18 : 6,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: coverIndex == index ? 0.95 : 0.45,
                        ),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: -52,
                child: Center(
                  child: _PublicAvatar(
                    displayName: displayName,
                    showOfficialTick: showOfficialTick,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 62),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF251538),
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    if (showOfficialTick) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.verified_rounded,
                        color: Color(0xFFFFD36A),
                        size: 22,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '@$username · ID $publicId',
                  style: const TextStyle(
                    color: Color(0xFF7A6B86),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    if (roleTag != null)
                      _PublicBadge(
                        label: roleTag!,
                        icon: Icons.verified_user_rounded,
                        color: const Color(0xFFFFD36A),
                      ),
                    _PublicBadge(
                      label: 'VIP $vipLevel',
                      icon: Icons.workspace_premium_rounded,
                      color: const Color(0xFFE84C72),
                    ),
                    if (svipLevel > 0)
                      _PublicBadge(
                        label: 'SVIP $svipLevel',
                        icon: Icons.auto_awesome_rounded,
                        color: const Color(0xFF6D5DF6),
                      ),
                    _PublicBadge(
                      label: '$familyName · Lv. $familyLevel',
                      icon: Icons.groups_rounded,
                      color: const Color(0xFF12C7B7),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _PresenceLine(
                  presenceLabel: presenceLabel,
                  currentRoomName: currentRoomName,
                  onRoomTap: onRoomTap,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _MainProfileButton(
                        label: followStatus.label,
                        icon: followStatus.icon,
                        filled: true,
                        onTap: onFollowTap,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MainProfileButton(
                        label: 'Message',
                        icon: Icons.chat_bubble_rounded,
                        filled: false,
                        onTap: onMessageTap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    _PublicStat(label: 'Following', value: '128'),
                    SizedBox(width: 8),
                    _PublicStat(label: 'Followers', value: '3.4K'),
                    SizedBox(width: 8),
                    _PublicStat(label: 'Rooms', value: '12'),
                    SizedBox(width: 8),
                    _PublicStat(label: 'Visitors', value: '296'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverPhotoView extends StatelessWidget {
  const _CoverPhotoView({required this.cover});

  final _CoverPhoto cover;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: cover.colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -34,
            top: -38,
            child: Icon(
              cover.icon,
              color: Colors.white.withValues(alpha: 0.14),
              size: 132,
            ),
          ),
          Positioned(
            left: -26,
            bottom: -30,
            child: Icon(
              Icons.favorite_rounded,
              color: Colors.white.withValues(alpha: 0.10),
              size: 116,
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _CoverPatternPainter(
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverPatternPainter extends CustomPainter {
  const _CoverPatternPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (double x = -20; x < size.width + 20; x += 34) {
      for (double y = -20; y < size.height + 20; y += 34) {
        canvas.drawCircle(Offset(x, y), 8, paint);
        canvas.drawArc(
          Rect.fromCenter(center: Offset(x, y), width: 22, height: 22),
          0,
          3.14,
          false,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CoverPatternPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _PublicBioPanel extends StatelessWidget {
  const _PublicBioPanel({
    required this.bio,
    required this.age,
    required this.gender,
    required this.interests,
  });

  final String bio;
  final String age;
  final String gender;
  final List<String> interests;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _whitePanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About',
            style: TextStyle(
              color: Color(0xFF251538),
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            bio,
            style: const TextStyle(
              color: Color(0xFF5E526B),
              fontSize: 13,
              height: 1.38,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _InfoPill(
                  icon: Icons.cake_rounded,
                  label: 'Age',
                  value: age,
                  color: const Color(0xFFE84C72),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InfoPill(
                  icon: Icons.person_rounded,
                  label: 'Gender',
                  value: gender,
                  color: const Color(0xFF6D5DF6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Interests',
            style: TextStyle(
              color: Color(0xFF251538),
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: interests
                .map(
                  (interest) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF12C7B7).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: const Color(0xFF12C7B7).withValues(alpha: 0.20),
                      ),
                    ),
                    child: Text(
                      interest,
                      style: const TextStyle(
                        color: Color(0xFF251538),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _PublicFamilyPanel extends StatelessWidget {
  const _PublicFamilyPanel({
    required this.familyName,
    required this.familyLevel,
    required this.onTap,
  });

  final String familyName;
  final int familyLevel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: _whitePanelDecoration(radius: 28),
          child: Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF12C7B7).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  color: Color(0xFF12C7B7),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      familyName,
                      style: const TextStyle(
                        color: Color(0xFF251538),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Family Lv. $familyLevel · View members and family rooms',
                      style: const TextStyle(
                        color: Color(0xFF7A6B86),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Color(0xFF8C8198),
                size: 15,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF251538),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF8C8198),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PublicAvatar extends StatelessWidget {
  const _PublicAvatar({
    required this.displayName,
    required this.showOfficialTick,
  });

  final String displayName;
  final bool showOfficialTick;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 104,
          width: 104,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF251538).withValues(alpha: 0.18),
                blurRadius: 22,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Color(0xFF12C7B7),
                  Color(0xFF6D5DF6),
                  Color(0xFFE84C72),
                ],
              ),
            ),
            child: Center(
              child: Text(
                displayName.characters.first.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
        if (showOfficialTick)
          Positioned(
            right: 2,
            bottom: 5,
            child: Container(
              height: 28,
              width: 28,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFD36A), width: 2),
              ),
              child: const Icon(
                Icons.verified_rounded,
                color: Color(0xFFFFD36A),
                size: 20,
              ),
            ),
          ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 38,
        width: 38,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
          ),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}

class _PublicBadge extends StatelessWidget {
  const _PublicBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: color.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF251538),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PresenceLine extends StatelessWidget {
  const _PresenceLine({
    required this.presenceLabel,
    required this.currentRoomName,
    required this.onRoomTap,
  });

  final String presenceLabel;
  final String? currentRoomName;
  final VoidCallback onRoomTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        _TinyStatusChip(
          icon: Icons.circle_rounded,
          label: presenceLabel,
          color: const Color(0xFF12C7B7),
        ),
        if (currentRoomName != null)
          InkWell(
            onTap: onRoomTap,
            borderRadius: BorderRadius.circular(99),
            child: _TinyStatusChip(
              icon: Icons.graphic_eq_rounded,
              label: 'In chatroom: $currentRoomName',
              color: const Color(0xFF6D5DF6),
            ),
          ),
      ],
    );
  }
}

class _TinyStatusChip extends StatelessWidget {
  const _TinyStatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF251538),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MainProfileButton extends StatelessWidget {
  const _MainProfileButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: filled ? const Color(0xFF251538) : const Color(0xFFFAF7F1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: filled ? const Color(0xFF251538) : const Color(0xFFECE2D8),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: filled ? Colors.white : const Color(0xFF251538),
              size: 18,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: filled ? Colors.white : const Color(0xFF251538),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublicStat extends StatelessWidget {
  const _PublicStat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF7F1),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: const Color(0xFFECE2D8)),
        ),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF251538),
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF8C8198),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublicVibeCard extends StatelessWidget {
  const _PublicVibeCard({
    required this.vibe,
    required this.onTap,
    required this.onLikeTap,
    required this.onCommentTap,
    required this.onShareTap,
  });

  final _PublicVibeItem vibe;
  final VoidCallback onTap;
  final VoidCallback onLikeTap;
  final VoidCallback onCommentTap;
  final VoidCallback onShareTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: _whitePanelDecoration(radius: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _VibeMediaIcon(vibe: vibe),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vibe.title,
                          style: const TextStyle(
                            color: Color(0xFF251538),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${vibe.timeAgo} · ${vibe.mediaType} Vibe',
                          style: const TextStyle(
                            color: Color(0xFF8C8198),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _SmallInfoChip(
                    icon: Icons.sell_rounded,
                    label: vibe.tag,
                    color: vibe.colors.first,
                  ),
                ],
              ),
              const SizedBox(height: 13),
              _VibeMediaPreview(vibe: vibe),
              const SizedBox(height: 13),
              Text(
                vibe.body,
                style: const TextStyle(
                  color: Color(0xFF5E526B),
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  _VibeActionButton(
                    icon: Icons.favorite_rounded,
                    label: vibe.likes,
                    color: const Color(0xFFE84C72),
                    onTap: onLikeTap,
                  ),
                  const SizedBox(width: 9),
                  _VibeActionButton(
                    icon: Icons.chat_bubble_rounded,
                    label: vibe.comments,
                    color: const Color(0xFF6D5DF6),
                    onTap: onCommentTap,
                  ),
                  const Spacer(),
                  _VibeActionButton(
                    icon: Icons.ios_share_rounded,
                    label: 'Share',
                    color: const Color(0xFF12C7B7),
                    onTap: onShareTap,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VibeMediaIcon extends StatelessWidget {
  const _VibeMediaIcon({required this.vibe});

  final _PublicVibeItem vibe;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      width: 42,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: vibe.colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Icon(
        vibe.icon,
        color: Colors.white,
        size: 21,
      ),
    );
  }
}

class _VibeMediaPreview extends StatelessWidget {
  const _VibeMediaPreview({required this.vibe});

  final _PublicVibeItem vibe;

  @override
  Widget build(BuildContext context) {
    if (vibe.mediaType == 'Text') {
      return const SizedBox.shrink();
    }

    final isVideo = vibe.mediaType == 'Video';

    return Container(
      height: 154,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: vibe.colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: vibe.colors.first.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -34,
            top: -38,
            child: Container(
              height: 120,
              width: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Center(
            child: Container(
              height: 58,
              width: 58,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
                ),
              ),
              child: Icon(
                isVideo ? Icons.play_arrow_rounded : Icons.photo_rounded,
                color: Colors.white,
                size: isVideo ? 38 : 30,
              ),
            ),
          ),
          Positioned(
            left: 14,
            top: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                isVideo ? 'Video Vibe' : 'Photo Vibe',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallInfoChip extends StatelessWidget {
  const _SmallInfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF251538),
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _VibeActionButton extends StatelessWidget {
  const _VibeActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF251538),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublicVibeItem {
  const _PublicVibeItem({
    required this.title,
    required this.body,
    required this.timeAgo,
    required this.mediaType,
    required this.tag,
    required this.likes,
    required this.comments,
    required this.icon,
    required this.colors,
  });

  final String title;
  final String body;
  final String timeAgo;
  final String mediaType;
  final String tag;
  final String likes;
  final String comments;
  final IconData icon;
  final List<Color> colors;
}

const List<_PublicVibeItem> _mockPublicVibes = [
  _PublicVibeItem(
    title: 'Late night room memories',
    body: 'Good songs, good friends, and a calm room vibe tonight.',
    timeAgo: '2h ago',
    mediaType: 'Photo',
    tag: 'Room',
    likes: '1.2K',
    comments: '86',
    icon: Icons.photo_rounded,
    colors: [
      Color(0xFF12C7B7),
      Color(0xFF6D5DF6),
    ],
  ),
  _PublicVibeItem(
    title: 'Vibe Sync clip',
    body: 'The audience matched the beat perfectly in Vibe Sync.',
    timeAgo: '1d ago',
    mediaType: 'Video',
    tag: 'VibeSync',
    likes: '3.8K',
    comments: '210',
    icon: Icons.play_arrow_rounded,
    colors: [
      Color(0xFFE84C72),
      Color(0xFFFFD36A),
    ],
  ),
  _PublicVibeItem(
    title: 'Text vibe',
    body: 'Building something premium takes time, but every screen should feel alive.',
    timeAgo: '3d ago',
    mediaType: 'Text',
    tag: 'Thought',
    likes: '894',
    comments: '42',
    icon: Icons.notes_rounded,
    colors: [
      Color(0xFF251538),
      Color(0xFF6D5DF6),
    ],
  ),
];

BoxDecoration _whitePanelDecoration({double radius = 28}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: const Color(0xFFECE2D8)),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF251538).withValues(alpha: 0.045),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );
}
