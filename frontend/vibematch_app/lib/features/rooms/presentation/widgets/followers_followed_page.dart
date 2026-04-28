import 'package:flutter/material.dart';

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

class _FollowersFollowedPageState extends State<FollowersFollowedPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<SeatUser> get _followers {
    final list = widget.users.where((item) => item.id != widget.user.id).toList();
    list.sort((a, b) => b.receivedExp.compareTo(a.receivedExp));
    return list;
  }

  List<SeatUser> get _followed {
    final list = widget.users.where((item) => item.id != widget.user.id).toList();
    list.sort((a, b) => b.sentExp.compareTo(a.sentExp));
    return list;
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
                          style: const TextStyle(
                            color: RoomColors.plum,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Followers and followed users',
                          style: TextStyle(
                            color: Color(0xFF7B6A86),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
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
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: RoomColors.softLine),
              ),
              child: TabBar(
                controller: _tabController,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: RoomColors.plum,
                  borderRadius: BorderRadius.circular(999),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF7B6A86),
                labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
                tabs: const [
                  Tab(text: 'Followers'),
                  Tab(text: 'Followed'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _UserList(users: _followers, emptyText: 'No followers visible yet'),
                  _UserList(users: _followed, emptyText: 'No followed users visible yet'),
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

  final List<SeatUser> users;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return Center(
        child: Text(
          emptyText,
          style: const TextStyle(
            color: Color(0xFF7B6A86),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
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
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: RoomColors.softLine),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: user.avatarColors),
                ),
                child: Text(
                  avatarLetter(user.name),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: RoomColors.plum,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user.roleLabel.isEmpty ? 'Member' : user.roleLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF7B6A86),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              VipBadge(level: user.vipLevel, size: VipBadgeSize.tiny),
            ],
          ),
        );
      },
    );
  }
}
