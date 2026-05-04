import 'package:flutter/material.dart';

import '../data/social_mock_data.dart';
import '../models/social_user.dart';

class SocialMentionPicker extends StatelessWidget {
  const SocialMentionPicker({
    super.key,
    required this.query,
    required this.onSelected,
  });

  final String query;
  final ValueChanged<SocialUser> onSelected;

  @override
  Widget build(BuildContext context) {
    final normalized = query.toLowerCase().replaceFirst('@', '').trim();
    final users = <SocialUser>{
      ...SocialMockData.following,
      ...SocialMockData.followers,
    }.where((user) {
      if (normalized.isEmpty) return true;
      return user.username.toLowerCase().contains(normalized) ||
          user.displayName.toLowerCase().contains(normalized) ||
          user.id.toLowerCase().contains(normalized);
    }).toList()
      ..sort((a, b) {
        if (a.isFriend != b.isFriend) return a.isFriend ? -1 : 1;
        if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
        return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
      });

    if (users.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxHeight: 210),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFECE2D8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF251538).withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: users.length,
        separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF0E8DE)),
        itemBuilder: (context, index) {
          final user = users[index];
          return ListTile(
            dense: true,
            onTap: () => onSelected(user),
            leading: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: user.colors),
                    borderRadius: BorderRadius.circular(14),
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
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFF12C7B7),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              user.displayName,
              style: const TextStyle(
                color: Color(0xFF251538),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            subtitle: Text(
              '@${user.username} • ${user.isFriend ? 'Friend' : user.isFollowing ? 'Following' : 'Follower'}',
              style: const TextStyle(
                color: Color(0xFF7B6A86),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            trailing: const Icon(Icons.alternate_email_rounded, color: Color(0xFF8C5CF6), size: 18),
          );
        },
      ),
    );
  }
}
