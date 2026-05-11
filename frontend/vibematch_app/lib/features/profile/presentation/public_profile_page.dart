import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/data/auth_api_service.dart';
import '../data/profile_api_service.dart';
import 'widgets/profile_match_score_badge.dart';

class PublicProfilePage extends StatefulWidget {
  const PublicProfilePage({
    super.key,
    this.userId = '6418000000',
    this.displayName = 'Vibe User',
    this.username,
  });

  final String userId;
  final String displayName;
  final String? username;

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  final ProfileApiService _profileApi = const ProfileApiService();
  final AuthApiService _authApi = const AuthApiService();

  PublicUserProfile? _profile;
  UserRelationship? _relationship;
  bool _loading = true;
  bool _followBusy = false;
  String? _error;

  int get _targetPublicUserId => int.tryParse(widget.userId.replaceAll(RegExp('[^0-9]'), '')) ?? 0;
  bool get _isSelfProfile => _authApi.cachedUser?.publicUserId == _targetPublicUserId;

  String get _displayName => _profile?.visibleName ?? widget.displayName;
  String? get _username => _profile?.username ?? widget.username;
  String get _visibleId => _profile?.visibleId ?? widget.userId;
  int get _vipLevel => _profile?.vip.vipLevel ?? 0;
  int get _svipLevel => _profile?.vip.svipLevel ?? 0;
  int get _followersCount => _relationship?.followersCount ?? 0;
  int get _followingCount => _relationship?.followingCount ?? 0;

  String get _followLabel {
    final relationship = _relationship;
    if (relationship == null) return 'Follow';
    if (relationship.isFriend) return 'Friends';
    if (relationship.isFollowing) return 'Following';
    if (relationship.followsMe) return 'Follow Back';
    return 'Follow';
  }

  IconData get _followIcon {
    final relationship = _relationship;
    if (relationship?.isFriend == true) return Icons.group_rounded;
    if (relationship?.isFollowing == true) return Icons.verified_user_rounded;
    return Icons.person_add_alt_1_rounded;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadProfile());
  }

  Future<void> _loadProfile() async {
    final publicUserId = _targetPublicUserId;
    if (publicUserId <= 0) {
      setState(() {
        _loading = false;
        _error = 'Invalid public user ID.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _profileApi.getMe(forceRefresh: false);
      final profile = await _profileApi.getPublicProfile(publicUserId);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _relationship = profile.relationship;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow() async {
    if (_isSelfProfile || _followBusy) return;
    final publicUserId = _targetPublicUserId;
    if (publicUserId <= 0) return;

    setState(() => _followBusy = true);
    try {
      final nextRelationship = _relationship?.isFollowing == true
          ? await _profileApi.unfollowUser(publicUserId)
          : await _profileApi.followUser(publicUserId);
      if (!mounted) return;
      setState(() => _relationship = nextRelationship);
      _toast(_followMessage(nextRelationship));
    } catch (error) {
      if (mounted) _toast(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  String _followMessage(UserRelationship relationship) {
    if (relationship.isFriend) return 'You are friends now.';
    if (relationship.isFollowing) return 'You are now following this profile.';
    return 'Unfollowed this profile.';
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)), behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF251538)));
  }

  @override
  Widget build(BuildContext context) {
    final initial = _displayName.trim().isEmpty ? 'V' : _displayName.trim()[0].toUpperCase();
    final score = _matchScore(_visibleId);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
          children: [
            if (_loading) const LinearProgressIndicator(minHeight: 3, color: Color(0xFF12C7B7), backgroundColor: Color(0xFFECE2D8)),
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE8C77C))),
                child: Row(children: [
                  const Icon(Icons.wifi_off_rounded, color: Color(0xFFC99A3B), size: 19),
                  const SizedBox(width: 9),
                  Expanded(child: Text(_error!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w800))),
                  TextButton(onPressed: _loadProfile, child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w900))),
                ]),
              ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(34),
                border: Border.all(color: const Color(0xFFECE2D8)),
                boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.08), blurRadius: 22, offset: const Offset(0, 10))],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        height: 164,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF251538), Color(0xFF6D5DF6), Color(0xFFE84C72)]),
                        ),
                        child: Stack(
                          children: [
                            Positioned(left: 14, top: 14, child: _HeaderButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context))),
                            Positioned(right: 14, top: 14, child: _HeaderButton(icon: Icons.ios_share_rounded, onTap: () => _toast('Profile share sheet will open.'))),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 18,
                        bottom: -54,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 9))]),
                          child: CircleAvatar(radius: 48, backgroundColor: const Color(0xFF6D5DF6), child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900))),
                        ),
                      ),
                      Positioned(right: 16, bottom: -42, child: ProfileMatchScoreBadge(score: score, compact: true)),
                    ],
                  ),
                  const SizedBox(height: 62),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF251538), fontSize: 27, fontWeight: FontWeight.w900, letterSpacing: -0.6)),
                        const SizedBox(height: 6),
                        Text(_username == null ? 'ID $_visibleId' : '@$_username · ID $_visibleId', style: const TextStyle(color: Color(0xFF8C7B8F), fontSize: 13, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          if (_vipLevel > 0) _Badge(icon: Icons.diamond_rounded, label: 'VIP $_vipLevel', color: const Color(0xFFE84C72)),
                          if (_svipLevel > 0) _Badge(icon: Icons.auto_awesome_rounded, label: 'SVIP $_svipLevel', color: const Color(0xFF6D5DF6)),
                          if (_profile?.primaryRoleBadge != null) _Badge(icon: Icons.verified_rounded, label: _profile!.primaryRoleBadge!.badgeLabel, color: const Color(0xFFFFC857)),
                        ]),
                        const SizedBox(height: 14),
                        const Text('Type something about yourself.', style: TextStyle(color: Color(0xFF4A2A63), fontSize: 13, fontWeight: FontWeight.w700, height: 1.35)),
                        const SizedBox(height: 14),
                        Row(children: [
                          Expanded(child: _Stat(value: _compactCount(_followersCount), label: 'Followers')),
                          const SizedBox(width: 8),
                          Expanded(child: _Stat(value: _compactCount(_followingCount), label: 'Following')),
                        ]),
                        if (!_isSelfProfile) ...[
                          const SizedBox(height: 16),
                          Row(children: [
                            Expanded(child: _MainButton(label: _followBusy ? 'Please wait' : _followLabel, icon: _followIcon, filled: true, onTap: _toggleFollow)),
                            const SizedBox(width: 10),
                            Expanded(child: _MainButton(label: 'Message', icon: Icons.chat_bubble_rounded, filled: false, onTap: () => _toast('Message request will open.'))),
                          ]),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _matchScore(String value) {
    final numeric = int.tryParse(value.replaceAll(RegExp('[^0-9]'), '')) ?? 72;
    return 55 + (numeric % 41);
  }
}

String _compactCount(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
  return value.toString();
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(width: 42, height: 42, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.88), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: const Color(0xFF251538))),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: color, size: 14), const SizedBox(width: 4), Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900))]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFFAF7F1), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFECE2D8))),
      child: Column(children: [
        Text(value, style: const TextStyle(color: Color(0xFF251538), fontSize: 15, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 10.5, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _MainButton extends StatelessWidget {
  const _MainButton({required this.label, required this.icon, required this.filled, required this.onTap});
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
        decoration: BoxDecoration(color: filled ? const Color(0xFF251538) : Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF251538))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: filled ? Colors.white : const Color(0xFF251538), size: 18), const SizedBox(width: 7), Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: filled ? Colors.white : const Color(0xFF251538), fontWeight: FontWeight.w900)))]),
      ),
    );
  }
}
