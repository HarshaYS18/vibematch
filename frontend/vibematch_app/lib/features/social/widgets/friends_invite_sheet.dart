import 'package:flutter/material.dart';

import '../data/social_api_service.dart';
import '../data/social_mock_data.dart';
import '../models/social_user.dart';

class FriendsInviteSheet extends StatefulWidget {
  const FriendsInviteSheet({
    super.key,
    required this.title,
    required this.onInvite,
    this.actionLabel = 'Invite',
    this.completedLabel = 'Invited',
    this.onlineOnly = true,
    this.sendRoomInvite = true,
    this.socialApiService = const SocialApiService(),
  });

  final String title;
  final ValueChanged<SocialUser> onInvite;
  final String actionLabel;
  final String completedLabel;
  final bool onlineOnly;
  final bool sendRoomInvite;
  final SocialApiService socialApiService;

  @override
  State<FriendsInviteSheet> createState() => _FriendsInviteSheetState();
}

class _FriendsInviteSheetState extends State<FriendsInviteSheet> {
  final Set<String> _completedIds = <String>{};
  final Set<String> _sendingIds = <String>{};
  late Future<List<SocialUser>> _friendsFuture;

  String get _roomName {
    const prefix = 'Invite friends to ';
    final title = widget.title.trim();
    if (title.startsWith(prefix)) {
      final parsed = title.substring(prefix.length).trim();
      if (parsed.isNotEmpty) return parsed;
    }
    return title.isEmpty ? 'this room' : title;
  }

  @override
  void initState() {
    super.initState();
    _friendsFuture = _loadFriends();
  }

  Future<List<SocialUser>> _loadFriends() async {
    try {
      final users = await widget.socialApiService.listFriendUsers(onlineOnly: widget.onlineOnly);
      return _sortedFriends(users);
    } catch (_) {
      final fallback = widget.onlineOnly
          ? SocialMockData.friends.where((user) => user.isOnline).toList(growable: false)
          : SocialMockData.friends;
      return _sortedFriends(fallback);
    }
  }

  List<SocialUser> _sortedFriends(List<SocialUser> users) {
    final friends = [...users];
    friends.sort((a, b) {
      if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
      final idCompare = a.id.compareTo(b.id);
      if (idCompare != 0) return idCompare;
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
    return friends;
  }

  void _refreshFriends() {
    setState(() {
      _friendsFuture = _loadFriends();
    });
  }

  Future<void> _completeAction(SocialUser user) async {
    if (_sendingIds.contains(user.id) || _completedIds.contains(user.id)) return;
    setState(() => _sendingIds.add(user.id));

    try {
      if (widget.sendRoomInvite) {
        final publicUserId = user.publicUserId ?? int.tryParse(user.id);
        if (publicUserId != null && publicUserId > 0) {
          await widget.socialApiService.sendRoomInvite(
            targetPublicUserId: publicUserId,
            roomName: _roomName,
          );
        }
      }
      widget.onInvite(user);
      if (!mounted) return;
      setState(() {
        _sendingIds.remove(user.id);
        _completedIds.add(user.id);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _sendingIds.remove(user.id));
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF251538),
            content: Text('Action failed: $error', style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.40,
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: EdgeInsets.fromLTRB(14, 10, 14, MediaQuery.paddingOf(context).bottom + 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: FutureBuilder<List<SocialUser>>(
          future: _friendsFuture,
          builder: (context, snapshot) {
            final friends = snapshot.data ?? const <SocialUser>[];
            final online = friends.where((user) => user.isOnline).toList();
            final offline = friends.where((user) => !user.isOnline).toList();
            final loading = snapshot.connectionState == ConnectionState.waiting;

            return Column(
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF251538),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh friends',
                      visualDensity: VisualDensity.compact,
                      onPressed: loading ? null : _refreshFriends,
                      icon: loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF7B6A86)),
                    ),
                    Text(
                      widget.onlineOnly ? '${friends.length} online' : '${friends.length} friends',
                      style: const TextStyle(
                        color: Color(0xFF7B6A86),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      if (online.isNotEmpty) ...[
                        const _SectionLabel('Online now'),
                        ...online.map(_friendRow),
                        const SizedBox(height: 8),
                      ],
                      if (!widget.onlineOnly && offline.isNotEmpty) ...[
                        const _SectionLabel('Friends'),
                        ...offline.map(_friendRow),
                      ],
                      if (!loading && friends.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 22),
                          child: Center(
                            child: Text(
                              widget.onlineOnly
                                  ? 'No friends are online right now.'
                                  : 'No friends available right now.',
                              style: const TextStyle(
                                color: Color(0xFF7B6A86),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _friendRow(SocialUser user) {
    final completed = _completedIds.contains(user.id);
    final sending = _sendingIds.contains(user.id);

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
                child: user.avatarUrl == null
                    ? Text(
                        user.avatarText,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.network(
                          user.avatarUrl!,
                          width: 38,
                          height: 38,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Text(
                            user.avatarText,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                          ),
                        ),
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
                  user.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF251538),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  user.isOnline ? '@${user.username} · online' : '@${user.username}',
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
            onPressed: completed || sending ? null : () => _completeAction(user),
            child: sending
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(completed ? widget.completedLabel : widget.actionLabel),
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
