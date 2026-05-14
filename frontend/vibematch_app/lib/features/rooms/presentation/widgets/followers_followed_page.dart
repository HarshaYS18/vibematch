import 'dart:async';

import 'package:flutter/material.dart';

import '../../../social/data/social_api_service.dart';
import '../../../social/models/social_user.dart';
import '../live_room_models.dart';
import 'room_theme.dart';
import 'vip_badge.dart';

class FollowersFollowedPage extends StatefulWidget {
  const FollowersFollowedPage({
    super.key,
    required this.user,
    required this.users,
    this.initialTabIndex = 0,
  });

  final SeatUser user;
  final List<SeatUser> users;
  final int initialTabIndex;

  @override
  State<FollowersFollowedPage> createState() => _FollowersFollowedPageState();
}

class _FollowersFollowedPageState extends State<FollowersFollowedPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final SocialApiService _socialApi = const SocialApiService();
  List<SocialUser> _followers = const <SocialUser>[];
  List<SocialUser> _following = const <SocialUser>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex.clamp(0, 1));
    unawaited(_load());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _socialApi.listFollowerUsers(),
        _socialApi.listFollowingUsers(),
      ]);
      if (!mounted) return;
      setState(() {
        _followers = results[0];
        _following = results[1];
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _followers = const <SocialUser>[];
        _following = const <SocialUser>[];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RoomColors.pearl,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(
                children: [
                  RoundRoomButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.pop(context),
                    color: RoomColors.plum,
                    background: Colors.white,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: RoomColors.plum, fontSize: 19, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _loading ? 'Loading real followers...' : 'Followers and following users',
                          style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  VipBadge(level: widget.user.vipLevel, size: VipBadgeSize.small),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999), border: Border.all(color: RoomColors.softLine)),
              child: TabBar(
                controller: _tabController,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(color: RoomColors.plum, borderRadius: BorderRadius.circular(999)),
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF7B6A86),
                labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
                tabs: [
                  Tab(text: 'Followers (${_followers.length})'),
                  Tab(text: 'Following (${_following.length})'),
                ],
              ),
            ),
            if (_loading) const LinearProgressIndicator(minHeight: 3, color: RoomColors.aqua, backgroundColor: Color(0xFFECE2D8)),
            if (_error != null)
              Container(
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE8C77C))),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off_rounded, color: Color(0xFFC99A3B), size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w800))),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _UserList(users: _followers, emptyText: 'No followers yet'),
                  _UserList(users: _following, emptyText: 'Not following anyone yet'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserList extends StatelessWidget {
  const _UserList({required this.users, required this.emptyText});

  final List<SocialUser> users;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return Center(
        child: Text(
          emptyText,
          style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 13, fontWeight: FontWeight.w800),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 20),
      physics: const BouncingScrollPhysics(),
      itemCount: users.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final user = users[index];
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: RoomColors.softLine)),
          child: Row(
            children: [
              _SocialAvatar(user: user),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: RoomColors.plum, fontSize: 14, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text('@${user.username}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              if (user.isOnline)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: RoomColors.aqua.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                  child: const Text('Online', style: TextStyle(color: RoomColors.aqua, fontSize: 10.5, fontWeight: FontWeight.w900)),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SocialAvatar extends StatelessWidget {
  const _SocialAvatar({required this.user});
  final SocialUser user;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user.avatarUrl?.trim();
    final fallback = Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: user.colors)),
      child: Text(user.avatarText, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
    );
    if (avatarUrl == null || avatarUrl.isEmpty) return fallback;
    return ClipOval(
      child: Image.network(
        avatarUrl,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}
