import 'package:flutter/material.dart';

import '../data/social_mock_data.dart';
import '../models/social_user.dart';

class FriendsInviteSheet extends StatefulWidget {
  const FriendsInviteSheet({
    super.key,
    required this.title,
    required this.onInvite,
  });

  final String title;
  final ValueChanged<SocialUser> onInvite;

  @override
  State<FriendsInviteSheet> createState() => _FriendsInviteSheetState();
}

class _FriendsInviteSheetState extends State<FriendsInviteSheet> {
  final Set<String> _invitedIds = <String>{};

  List<SocialUser> get _friends {
    final friends = [...SocialMockData.friends];
    friends.sort((a, b) {
      if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
      final idCompare = a.id.compareTo(b.id);
      if (idCompare != 0) return idCompare;
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
    return friends;
  }

  void _invite(SocialUser user) {
    setState(() => _invitedIds.add(user.id));
    widget.onInvite(user);
  }

  @override
  Widget build(BuildContext context) {
    final online = _friends.where((user) => user.isOnline).toList();
    final offline = _friends.where((user) => !user.isOnline).toList();

    return FractionallySizedBox(
      heightFactor: 0.40,
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: EdgeInsets.fromLTRB(14, 10, 14, MediaQuery.paddingOf(context).bottom + 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0D5CB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.title,
              style: const TextStyle(
                color: Color(0xFF251538),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  if (online.isNotEmpty) ...[
                    const _SectionLabel('Online'),
                    ...online.map(_friendRow),
                    const SizedBox(height: 8),
                  ],
                  const _SectionLabel('Friends'),
                  ...offline.map(_friendRow),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _friendRow(SocialUser user) {
    final invited = _invitedIds.contains(user.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: user.colors),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  user.avatarText,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                ),
              ),
              if (user.isOnline)
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: const Color(0xFF12C7B7),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${user.id} · ${user.displayName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF251538),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '@${user.username}',
                  style: const TextStyle(
                    color: Color(0xFF7B6A86),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: invited ? null : () => _invite(user),
            child: Text(invited ? 'Invited' : 'Invite'),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 2),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF7B6A86),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
