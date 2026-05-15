import 'package:flutter/material.dart';

import '../data/social_api_service.dart';
import '../models/social_user.dart';

class SocialMentionPicker extends StatefulWidget {
  const SocialMentionPicker({
    super.key,
    required this.query,
    required this.onSelected,
    this.socialApiService = const SocialApiService(),
  });

  final String query;
  final ValueChanged<SocialUser> onSelected;
  final SocialApiService socialApiService;

  @override
  State<SocialMentionPicker> createState() => _SocialMentionPickerState();
}

class _SocialMentionPickerState extends State<SocialMentionPicker> {
  late Future<List<SocialUser>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = _loadMentionUsers();
  }

  @override
  void didUpdateWidget(covariant SocialMentionPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _usersFuture = _loadMentionUsers();
    }
  }

  Future<List<SocialUser>> _loadMentionUsers() async {
    final following = await widget.socialApiService.listFollowingUsers();
    final followers = await widget.socialApiService.listFollowerUsers();
    final usersByKey = <String, SocialUser>{};

    for (final user in [...following, ...followers]) {
      final key = user.publicUserId?.toString() ?? user.id;
      if (key.trim().isEmpty) continue;
      usersByKey[key] = user;
    }

    final normalized = widget.query.toLowerCase().replaceFirst('@', '').trim();
    final users = usersByKey.values.where((user) {
      if (normalized.isEmpty) return true;
      return user.username.toLowerCase().contains(normalized) ||
          user.displayName.toLowerCase().contains(normalized) ||
          user.id.toLowerCase().contains(normalized) ||
          (user.publicUserId?.toString().contains(normalized) ?? false);
    }).toList();

    users.sort((a, b) {
      if (a.isFriend != b.isFriend) return a.isFriend ? -1 : 1;
      if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });

    return users;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SocialUser>>(
      future: _usersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _MentionPickerShell(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF111015))),
                  SizedBox(width: 10),
                  Text('Searching users...', style: TextStyle(color: Color(0xFF7B6A86), fontSize: 12, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return const _MentionPickerShell(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text('Could not load mention users. Check backend connection.', style: TextStyle(color: Color(0xFFE84C72), fontSize: 12, fontWeight: FontWeight.w800)),
            ),
          );
        }

        final users = snapshot.data ?? const <SocialUser>[];
        if (users.isEmpty) return const SizedBox.shrink();

        return _MentionPickerShell(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: users.length,
            separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF0E8DE)),
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                dense: true,
                onTap: () => widget.onSelected(user),
                leading: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: user.colors),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: user.avatarUrl == null || user.avatarUrl!.trim().isEmpty
                          ? Text(user.avatarText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))
                          : Image.network(
                              user.avatarUrl!,
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Text(user.avatarText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF251538), fontSize: 13, fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  '@${user.username} • ${user.isFriend ? 'Friend' : user.isFollowing ? 'Following' : 'Follower'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11, fontWeight: FontWeight.w700),
                ),
                trailing: const Icon(Icons.alternate_email_rounded, color: Color(0xFF8C5CF6), size: 18),
              );
            },
          ),
        );
      },
    );
  }
}

class _MentionPickerShell extends StatelessWidget {
  const _MentionPickerShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
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
      child: child,
    );
  }
}
