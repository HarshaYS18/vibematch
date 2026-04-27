import 'package:flutter/material.dart';

class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  static const String _mockUnlockPin = '1234';

  String _selectedFilter = 'All';

  final Set<String> _lockedConversationIds = {
    'akhil_room_invite',
  };

  final Set<String> _blockedConversationIds = {};

  final List<String> _filters = const [
    'All',
    'Unread',
    'Online',
    'Room Invites',
    'Official',
    'Strangers',
    'Locked',
    'Blocked',
  ];

  final List<_InboxConversation> _normalConversations = const [
    _InboxConversation(
      id: 'team_official',
      title: 'Vibe Match Team',
      subtitle: 'Your custom room background was approved.',
      time: 'Now',
      badge: 'Official',
      unreadCount: 2,
      avatarText: 'V',
      type: _InboxType.official,
      presence: _PresenceStatus.online,
      lastSeenText: 'online',
      currentRoomName: null,
      colors: [
        Color(0xFF251538),
        Color(0xFF6D5DF6),
      ],
      messages: [
        _InboxMessage(
          sender: 'Vibe Match Team',
          text:
              'Your custom room background was approved and has been applied to your room.',
          time: 'Now',
          isMine: false,
        ),
        _InboxMessage(
          sender: 'Vibe Match Team',
          text:
              'Official updates, safety notices, account alerts, wallet/recharge notices and review results will appear here.',
          time: '2m ago',
          isMine: false,
        ),
      ],
    ),
    _InboxConversation(
      id: 'akhil_room_invite',
      title: 'Akhil',
      subtitle: 'Invited you to join Late Night Chill.',
      time: '3m',
      badge: 'Room Invite',
      unreadCount: 1,
      avatarText: 'A',
      type: _InboxType.roomInvite,
      presence: _PresenceStatus.online,
      lastSeenText: 'online',
      currentRoomName: 'Late Night Chill',
      colors: [
        Color(0xFF12C7B7),
        Color(0xFF6D5DF6),
      ],
      messages: [
        _InboxMessage(
          sender: 'Akhil',
          text: 'Bro join the room 🔥',
          time: '3m ago',
          isMine: false,
        ),
        _InboxMessage(
          sender: 'Akhil',
          text:
              'Room Invite: Late Night Chill\nLanguage: English\nAccess: Invite allows direct entry while valid.',
          time: '3m ago',
          isMine: false,
          inviteRoomName: 'Late Night Chill',
        ),
      ],
    ),
    _InboxConversation(
      id: 'meera_chat',
      title: 'Meera',
      subtitle: 'That Vibe was nice ✨',
      time: '18m',
      badge: 'Chat',
      unreadCount: 0,
      avatarText: 'M',
      type: _InboxType.chat,
      presence: _PresenceStatus.offline,
      lastSeenText: 'last seen 1 min ago',
      currentRoomName: null,
      colors: [
        Color(0xFFE84C72),
        Color(0xFFFF8DAA),
      ],
      messages: [
        _InboxMessage(
          sender: 'Meera',
          text: 'That Vibe was nice ✨',
          time: '18m ago',
          isMine: false,
        ),
        _InboxMessage(
          sender: 'You',
          text: 'Thanks! I’m improving the Vibes page next.',
          time: '15m ago',
          isMine: true,
        ),
      ],
    ),
    _InboxConversation(
      id: 'riya_mention',
      title: 'Riya',
      subtitle: 'Mentioned you in a Vibe comment.',
      time: '1h',
      badge: 'Mention',
      unreadCount: 1,
      avatarText: 'R',
      type: _InboxType.chat,
      presence: _PresenceStatus.offline,
      lastSeenText: 'last seen 1 hour ago',
      currentRoomName: null,
      colors: [
        Color(0xFFC99A3B),
        Color(0xFFE84C72),
      ],
      messages: [
        _InboxMessage(
          sender: 'Riya',
          text:
              'Mention notification: Riya mentioned you in a Vibe comment using @founder.',
          time: '1h ago',
          isMine: false,
        ),
      ],
    ),
  ];

  final List<_InboxConversation> _strangerConversations = const [
    _InboxConversation(
      id: 'stranger_kiran',
      title: 'Kiran',
      subtitle: 'Hey, saw you in Telugu Beats.',
      time: '9m',
      badge: 'Stranger',
      unreadCount: 1,
      avatarText: 'K',
      type: _InboxType.stranger,
      presence: _PresenceStatus.online,
      lastSeenText: 'online',
      currentRoomName: 'Telugu Beats',
      colors: [
        Color(0xFF8C8198),
        Color(0xFF6D5DF6),
      ],
      messages: [
        _InboxMessage(
          sender: 'Kiran',
          text:
              'Hey, saw you in Telugu Beats. Can we connect? This message is grouped under Stranger Messages because this is not a mutual-follow chat.',
          time: '9m ago',
          isMine: false,
        ),
      ],
    ),
    _InboxConversation(
      id: 'stranger_nisha',
      title: 'Nisha',
      subtitle: 'Hi, I liked your Vibe post.',
      time: '28m',
      badge: 'Stranger',
      unreadCount: 1,
      avatarText: 'N',
      type: _InboxType.stranger,
      presence: _PresenceStatus.offline,
      lastSeenText: 'last seen 1 day ago',
      currentRoomName: null,
      colors: [
        Color(0xFFE84C72),
        Color(0xFF8C8198),
      ],
      messages: [
        _InboxMessage(
          sender: 'Nisha',
          text: 'Hi, I liked your Vibe post. Stranger message request pending.',
          time: '28m ago',
          isMine: false,
        ),
      ],
    ),
    _InboxConversation(
      id: 'stranger_dev',
      title: 'Dev',
      subtitle: 'Join my room?',
      time: '2h',
      badge: 'Stranger',
      unreadCount: 0,
      avatarText: 'D',
      type: _InboxType.stranger,
      presence: _PresenceStatus.offline,
      lastSeenText: 'last seen 7 days ago',
      currentRoomName: null,
      colors: [
        Color(0xFF12C7B7),
        Color(0xFF8C8198),
      ],
      messages: [
        _InboxMessage(
          sender: 'Dev',
          text:
              'Join my room? Since this sender is not a mutual friend, this stays inside Stranger Messages.',
          time: '2h ago',
          isMine: false,
        ),
      ],
    ),
  ];

  int get _strangerUnreadCount {
    return _strangerConversations.fold<int>(
      0,
      (total, conversation) => total + conversation.unreadCount,
    );
  }

  _InboxConversation get _strangerGroupConversation {
    final unread = _strangerUnreadCount;
    final count = _strangerConversations.length;
    final onlineCount = _strangerConversations
        .where((conversation) => conversation.presence == _PresenceStatus.online)
        .length;

    return _InboxConversation(
      id: 'stranger_group',
      title: 'Stranger Messages',
      subtitle: '$count one-sided follower messages • $onlineCount online now',
      time: '9m',
      badge: 'Grouped',
      unreadCount: unread,
      avatarText: 'S',
      type: _InboxType.strangerGroup,
      presence:
          onlineCount > 0 ? _PresenceStatus.online : _PresenceStatus.offline,
      lastSeenText:
          onlineCount > 0 ? '$onlineCount online' : 'no strangers online',
      currentRoomName: null,
      colors: const [
        Color(0xFF8C8198),
        Color(0xFF251538),
      ],
      messages: const [],
    );
  }

  List<_InboxConversation> get _allListConversations {
    return [
      ..._normalConversations,
      _strangerGroupConversation,
    ];
  }

  List<_InboxConversation> get _visibleConversations {
    if (_selectedFilter == 'Unread') {
      final normalUnread = _normalConversations
          .where((conversation) => conversation.unreadCount > 0)
          .toList();

      return [
        ...normalUnread,
        if (_strangerUnreadCount > 0) _strangerGroupConversation,
      ];
    }

    if (_selectedFilter == 'Online') {
      final onlineNormal = _normalConversations
          .where(
            (conversation) => conversation.presence == _PresenceStatus.online,
          )
          .toList();

      final onlineStrangers = _strangerConversations
          .where(
            (conversation) => conversation.presence == _PresenceStatus.online,
          )
          .toList();

      return [
        ...onlineNormal,
        if (onlineStrangers.isNotEmpty) _strangerGroupConversation,
      ];
    }

    if (_selectedFilter == 'Room Invites') {
      return _normalConversations
          .where((conversation) => conversation.type == _InboxType.roomInvite)
          .toList();
    }

    if (_selectedFilter == 'Official') {
      return _normalConversations
          .where((conversation) => conversation.type == _InboxType.official)
          .toList();
    }

    if (_selectedFilter == 'Strangers') {
      return [_strangerGroupConversation];
    }

    if (_selectedFilter == 'Locked') {
      return _allListConversations
          .where((conversation) => _isLocked(conversation))
          .toList();
    }

    if (_selectedFilter == 'Blocked') {
      return _allListConversations
          .where((conversation) => _isBlocked(conversation))
          .toList();
    }

    return _allListConversations;
  }

  bool _isLocked(_InboxConversation conversation) {
    return _lockedConversationIds.contains(conversation.id);
  }

  bool _isBlocked(_InboxConversation conversation) {
    return _blockedConversationIds.contains(conversation.id);
  }

  void _showAction(String message) {
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

  void _toggleLock(_InboxConversation conversation) {
    if (conversation.type == _InboxType.official) {
      _showAction('Official Vibe Match Team chat cannot be locked locally.');
      return;
    }

    setState(() {
      if (_lockedConversationIds.contains(conversation.id)) {
        _lockedConversationIds.remove(conversation.id);
      } else {
        _lockedConversationIds.add(conversation.id);
      }
    });

    final locked = _lockedConversationIds.contains(conversation.id);
    _showAction(
      locked
          ? '${conversation.title} chat locked.'
          : '${conversation.title} chat unlocked.',
    );
  }

  void _toggleBlock(_InboxConversation conversation) {
    if (conversation.type == _InboxType.official ||
        conversation.type == _InboxType.strangerGroup) {
      _showAction('This conversation cannot be blocked.');
      return;
    }

    setState(() {
      if (_blockedConversationIds.contains(conversation.id)) {
        _blockedConversationIds.remove(conversation.id);
      } else {
        _blockedConversationIds.add(conversation.id);
      }
    });

    final blocked = _blockedConversationIds.contains(conversation.id);
    _showAction(
      blocked
          ? '${conversation.title} blocked locally.'
          : '${conversation.title} unblocked locally.',
    );
  }

  void _reportProfile(_InboxConversation conversation) {
    if (conversation.type == _InboxType.official ||
        conversation.type == _InboxType.strangerGroup) {
      _showAction('Report is not available for this conversation.');
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _ReportProfileSheet(
          conversation: conversation,
          onSubmit: (reason) {
            Navigator.pop(context);
            _showAction(
              'Report submitted for ${conversation.title}: $reason',
            );
          },
        );
      },
    );
  }

  void _showConversationOptions(_InboxConversation conversation) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _ChatOptionsSheet(
          conversation: conversation,
          isLocked: _isLocked(conversation),
          isBlocked: _isBlocked(conversation),
          onLockTap: () {
            Navigator.pop(context);
            _toggleLock(conversation);
          },
          onBlockTap: () {
            Navigator.pop(context);
            _toggleBlock(conversation);
          },
          onReportTap: () {
            Navigator.pop(context);
            _reportProfile(conversation);
          },
        );
      },
    );
  }

  void _openConversation(_InboxConversation conversation) {
    if (conversation.type == _InboxType.strangerGroup) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _StrangerMessagesPage(
            conversations: _strangerConversations,
            isLocked: _isLocked,
            isBlocked: _isBlocked,
            onOpenConversation: _openConversation,
            onShowOptions: _showConversationOptions,
          ),
        ),
      );
      return;
    }

    if (_isLocked(conversation)) {
      _showUnlockSheet(conversation);
      return;
    }

    _pushChat(conversation);
  }

  void _showUnlockSheet(_InboxConversation conversation) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return _ChatUnlockSheet(
          conversation: conversation,
          mockPin: _mockUnlockPin,
          onUnlocked: () {
            Navigator.pop(context);
            _pushChat(conversation);
          },
          onForgotPin: () {
            _showAction(
              'PIN recovery flow will verify account ownership later.',
            );
          },
        );
      },
    );
  }

  void _pushChat(_InboxConversation conversation) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _InboxChatPage(
          conversation: conversation,
          isLocked: _isLocked(conversation),
          isBlocked: _isBlocked(conversation),
          onMoreTap: () => _showConversationOptions(conversation),
          onToggleLock: () => _toggleLock(conversation),
          onToggleBlock: () => _toggleBlock(conversation),
          onReport: () => _reportProfile(conversation),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleConversations = _visibleConversations;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Inbox',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF251538),
                          letterSpacing: -0.6,
                        ),
                      ),
                    ),
                    _RoundIconButton(
                      icon: Icons.search_rounded,
                      onTap: () => _showAction('Inbox search will open here.'),
                    ),
                    const SizedBox(width: 10),
                    _RoundIconButton(
                      icon: Icons.lock_rounded,
                      onTap: () {
                        setState(() {
                          _selectedFilter = 'Locked';
                        });
                        _showAction('Showing locked chats.');
                      },
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 38,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final filter = _filters[index];
                    final selected = filter == _selectedFilter;

                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      },
                      borderRadius: BorderRadius.circular(99),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFF251538)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF251538)
                                : const Color(0xFFECE2D8),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            filter,
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF7A6B86),
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (visibleConversations.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyInboxState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 104),
                sliver: SliverList.separated(
                  itemCount: visibleConversations.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final conversation = visibleConversations[index];

                    return _InboxConversationCard(
                      conversation: conversation,
                      isLocked: _isLocked(conversation),
                      isBlocked: _isBlocked(conversation),
                      onTap: () => _openConversation(conversation),
                      onLongPress: () => _showConversationOptions(conversation),
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

class _StrangerMessagesPage extends StatelessWidget {
  const _StrangerMessagesPage({
    required this.conversations,
    required this.isLocked,
    required this.isBlocked,
    required this.onOpenConversation,
    required this.onShowOptions,
  });

  final List<_InboxConversation> conversations;
  final bool Function(_InboxConversation conversation) isLocked;
  final bool Function(_InboxConversation conversation) isBlocked;
  final ValueChanged<_InboxConversation> onOpenConversation;
  final ValueChanged<_InboxConversation> onShowOptions;

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

  @override
  Widget build(BuildContext context) {
    final unreadCount = conversations.fold<int>(
      0,
      (total, conversation) => total + conversation.unreadCount,
    );

    final onlineCount = conversations
        .where((conversation) => conversation.presence == _PresenceStatus.online)
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                child: Row(
                  children: [
                    _RoundIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Stranger Messages',
                        style: TextStyle(
                          color: Color(0xFF251538),
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    _RoundIconButton(
                      icon: Icons.shield_rounded,
                      onTap: () => _showAction(
                        context,
                        'Stranger message privacy settings will open.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF251538),
                      Color(0xFF4A2A63),
                      Color(0xFF8C8198),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: const Icon(
                        Icons.mark_unread_chat_alt_rounded,
                        color: Color(0xFFFFD36A),
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${conversations.length} requests • $onlineCount online • $unreadCount unread',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.86),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
              sliver: SliverList.separated(
                itemCount: conversations.length,
                separatorBuilder: (context, index) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final conversation = conversations[index];

                  return _StrangerConversationCard(
                    conversation: conversation,
                    isLocked: isLocked(conversation),
                    isBlocked: isBlocked(conversation),
                    onOpenTap: () => onOpenConversation(conversation),
                    onOptionsTap: () => onShowOptions(conversation),
                    onAcceptTap: () => _showAction(
                      context,
                      '${conversation.title} accepted. Later backend will move this into normal chats.',
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

class _StrangerConversationCard extends StatelessWidget {
  const _StrangerConversationCard({
    required this.conversation,
    required this.isLocked,
    required this.isBlocked,
    required this.onOpenTap,
    required this.onOptionsTap,
    required this.onAcceptTap,
  });

  final _InboxConversation conversation;
  final bool isLocked;
  final bool isBlocked;
  final VoidCallback onOpenTap;
  final VoidCallback onOptionsTap;
  final VoidCallback onAcceptTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onOpenTap,
        onLongPress: onOptionsTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFECE2D8)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _InboxAvatar(
                    conversation: conversation,
                    size: 44,
                    isLocked: isLocked,
                    isBlocked: isBlocked,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ConversationMainInfo(
                      conversation: conversation,
                      isLocked: isLocked,
                      isBlocked: isBlocked,
                      showBadgeRow: false,
                    ),
                  ),
                  _ConversationTrailing(conversation: conversation),
                ],
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: _StrangerActionButton(
                      label: isBlocked ? 'Blocked' : 'Options',
                      icon: Icons.more_horiz_rounded,
                      color: const Color(0xFF6D5DF6),
                      onTap: onOptionsTap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StrangerActionButton(
                      label: 'Accept',
                      icon: Icons.check_circle_rounded,
                      color: const Color(0xFF12C7B7),
                      onTap: onAcceptTap,
                    ),
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

class _StrangerActionButton extends StatelessWidget {
  const _StrangerActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
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

class _InboxChatPage extends StatelessWidget {
  const _InboxChatPage({
    required this.conversation,
    required this.isLocked,
    required this.isBlocked,
    required this.onMoreTap,
    required this.onToggleLock,
    required this.onToggleBlock,
    required this.onReport,
  });

  final _InboxConversation conversation;
  final bool isLocked;
  final bool isBlocked;
  final VoidCallback onMoreTap;
  final VoidCallback onToggleLock;
  final VoidCallback onToggleBlock;
  final VoidCallback onReport;

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

  @override
  Widget build(BuildContext context) {
    final isOfficial = conversation.type == _InboxType.official;
    final isStranger = conversation.type == _InboxType.stranger;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: Column(
          children: [
            _ChatHeader(
              conversation: conversation,
              isLocked: isLocked,
              isBlocked: isBlocked,
              onBackTap: () => Navigator.pop(context),
              onMoreTap: onMoreTap,
              onRoomTap: conversation.currentRoomName == null
                  ? null
                  : () => _showAction(
                        context,
                        'Open ${conversation.currentRoomName} room preview. Access rules will be checked by backend.',
                      ),
            ),
            if (isBlocked)
              _BlockedNotice(
                onUnblockTap: onToggleBlock,
                onReportTap: onReport,
              )
            else if (isStranger)
              _StrangerChatNotice(
                onAcceptTap: () => _showAction(
                  context,
                  '${conversation.title} accepted. Later backend will move this into normal chats.',
                ),
                onOptionsTap: onMoreTap,
              ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                itemCount: conversation.messages.length,
                separatorBuilder: (context, index) => const SizedBox(height: 7),
                itemBuilder: (context, index) {
                  final message = conversation.messages[index];

                  return _MessageBubble(
                    message: message,
                    conversation: conversation,
                    onJoinRoomTap: () => _showAction(
                      context,
                      'Room access will be checked. If invite is valid, user joins ${message.inviteRoomName}.',
                    ),
                  );
                },
              ),
            ),
            _ChatInputBar(
              readOnly: isOfficial || isStranger || isBlocked,
              readOnlyText: isOfficial
                  ? 'Official updates are read-only'
                  : isBlocked
                      ? 'Unblock this profile to reply'
                      : isStranger
                          ? 'Accept request to reply'
                          : 'Message...',
              onSendTap: () => _showAction(
                context,
                isOfficial
                    ? 'Official team chat is read-only for users.'
                    : isBlocked
                        ? 'Unblock this profile before replying.'
                        : isStranger
                            ? 'Accept this stranger message request before replying.'
                            : 'Message will be sent when chat API is connected.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockedNotice extends StatelessWidget {
  const _BlockedNotice({
    required this.onUnblockTap,
    required this.onReportTap,
  });

  final VoidCallback onUnblockTap;
  final VoidCallback onReportTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEF3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF2BCD0)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.block_rounded,
            color: Color(0xFFE84C72),
            size: 21,
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Text(
              'This profile is blocked. You will not receive normal messages from this user.',
              style: TextStyle(
                color: Color(0xFF251538),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
          _MiniTextButton(
            label: 'Report',
            color: const Color(0xFFC99A3B),
            onTap: onReportTap,
          ),
          const SizedBox(width: 7),
          _MiniTextButton(
            label: 'Unblock',
            color: const Color(0xFF12C7B7),
            onTap: onUnblockTap,
          ),
        ],
      ),
    );
  }
}

class _StrangerChatNotice extends StatelessWidget {
  const _StrangerChatNotice({
    required this.onAcceptTap,
    required this.onOptionsTap,
  });

  final VoidCallback onAcceptTap;
  final VoidCallback onOptionsTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEFD4A1)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.shield_rounded,
            color: Color(0xFFC99A3B),
            size: 21,
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Text(
              'Stranger request. Accept to reply or open options.',
              style: TextStyle(
                color: Color(0xFF251538),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
          _MiniTextButton(
            label: 'Options',
            color: const Color(0xFF6D5DF6),
            onTap: onOptionsTap,
          ),
          const SizedBox(width: 7),
          _MiniTextButton(
            label: 'Accept',
            color: const Color(0xFF12C7B7),
            onTap: onAcceptTap,
          ),
        ],
      ),
    );
  }
}

class _MiniTextButton extends StatelessWidget {
  const _MiniTextButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.conversation,
    required this.isLocked,
    required this.isBlocked,
    required this.onBackTap,
    required this.onMoreTap,
    required this.onRoomTap,
  });

  final _InboxConversation conversation;
  final bool isLocked;
  final bool isBlocked;
  final VoidCallback onBackTap;
  final VoidCallback onMoreTap;
  final VoidCallback? onRoomTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFECE2D8).withValues(alpha: 0.9),
          ),
        ),
      ),
      child: Row(
        children: [
          _RoundIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: onBackTap,
          ),
          const SizedBox(width: 10),
          _InboxAvatar(
            conversation: conversation,
            size: 42,
            isLocked: isLocked,
            isBlocked: isBlocked,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ConversationMainInfo(
              conversation: conversation,
              isLocked: false,
              isBlocked: isBlocked,
              showBadgeRow: false,
              titleFontSize: 16,
            ),
          ),
          _RoundIconButton(
            icon: Icons.more_horiz_rounded,
            onTap: onMoreTap,
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.conversation,
    required this.onJoinRoomTap,
  });

  final _InboxMessage message;
  final _InboxConversation conversation;
  final VoidCallback onJoinRoomTap;

  @override
  Widget build(BuildContext context) {
    final isInvite = message.inviteRoomName != null;

    return Align(
      alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: message.isMine ? const Color(0xFF251538) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(22),
            topRight: const Radius.circular(22),
            bottomLeft: Radius.circular(message.isMine ? 22 : 6),
            bottomRight: Radius.circular(message.isMine ? 6 : 22),
          ),
          border: message.isMine
              ? null
              : Border.all(color: const Color(0xFFECE2D8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!message.isMine)
              Text(
                message.sender,
                style: TextStyle(
                  color: conversation.type == _InboxType.official
                      ? const Color(0xFF6D5DF6)
                      : conversation.type == _InboxType.stranger
                          ? const Color(0xFFC99A3B)
                          : const Color(0xFF12C7B7),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            if (!message.isMine) const SizedBox(height: 3),
            Text(
              message.text,
              style: TextStyle(
                color: message.isMine ? Colors.white : const Color(0xFF251538),
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isInvite) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: onJoinRoomTap,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF12C7B7),
                        Color(0xFF6D5DF6),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.login_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Join Room',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 7),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                message.time,
                style: TextStyle(
                  color: message.isMine
                      ? Colors.white.withValues(alpha: 0.62)
                      : const Color(0xFF8C8198),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({
    required this.readOnly,
    required this.readOnlyText,
    required this.onSendTap,
  });

  final bool readOnly;
  final String readOnlyText;
  final VoidCallback onSendTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFECE2D8)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7F1),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFECE2D8)),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  readOnly ? readOnlyText : 'Message...',
                  style: const TextStyle(
                    color: Color(0xFF8C8198),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: onSendTap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                color: readOnly
                    ? const Color(0xFFE2D9CF)
                    : const Color(0xFF251538),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                readOnly ? Icons.lock_rounded : Icons.send_rounded,
                color: readOnly ? const Color(0xFF8C8198) : Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InboxConversationCard extends StatelessWidget {
  const _InboxConversationCard({
    required this.conversation,
    required this.isLocked,
    required this.isBlocked,
    required this.onTap,
    required this.onLongPress,
  });

  final _InboxConversation conversation;
  final bool isLocked;
  final bool isBlocked;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
          child: Row(
            children: [
              _InboxAvatar(
                conversation: conversation,
                size: 48,
                isLocked: isLocked,
                isBlocked: isBlocked,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: _ConversationMainInfo(
                  conversation: conversation,
                  isLocked: isLocked,
                  isBlocked: isBlocked,
                ),
              ),
              const SizedBox(width: 8),
              _ConversationTrailing(conversation: conversation),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationMainInfo extends StatelessWidget {
  const _ConversationMainInfo({
    required this.conversation,
    required this.isLocked,
    required this.isBlocked,
    this.showBadgeRow = true,
    this.titleFontSize = 14,
  });

  final _InboxConversation conversation;
  final bool isLocked;
  final bool isBlocked;
  final bool showBadgeRow;
  final double titleFontSize;

  @override
  Widget build(BuildContext context) {
    final isOfficial = conversation.type == _InboxType.official;
    final isInvite = conversation.type == _InboxType.roomInvite;
    final isStrangerGroup = conversation.type == _InboxType.strangerGroup;

    final preview = isBlocked
        ? 'Blocked profile • Tap for options'
        : isLocked
            ? 'Locked chat • Tap to unlock'
            : conversation.subtitle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                conversation.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF251538),
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (isOfficial) ...[
              const SizedBox(width: 5),
              const Icon(
                Icons.verified_rounded,
                color: Color(0xFF6D5DF6),
                size: 15,
              ),
            ],
            if (isLocked) ...[
              const SizedBox(width: 5),
              const Icon(
                Icons.lock_rounded,
                color: Color(0xFF251538),
                size: 14,
              ),
            ],
            if (isBlocked) ...[
              const SizedBox(width: 5),
              const Icon(
                Icons.block_rounded,
                color: Color(0xFFE84C72),
                size: 14,
              ),
            ],
            if (isStrangerGroup) ...[
              const SizedBox(width: 5),
              const Icon(
                Icons.shield_rounded,
                color: Color(0xFFC99A3B),
                size: 15,
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        _PresenceText(conversation: conversation),
        if (!isLocked && !isBlocked && conversation.currentRoomName != null) ...[
          const SizedBox(height: 2),
          _RoomStatusText(
            roomName: conversation.currentRoomName!,
          ),
        ],
        const SizedBox(height: 2),
        Text(
          preview,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isBlocked
                ? const Color(0xFFE84C72)
                : isLocked
                    ? const Color(0xFF251538)
                    : const Color(0xFF7A6B86),
            fontSize: 12,
            fontWeight: isLocked || isBlocked ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
        if (showBadgeRow) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              _ConversationBadge(
                label: isBlocked
                    ? 'Blocked'
                    : isLocked
                        ? 'Locked'
                        : conversation.badge,
                color: isBlocked
                    ? const Color(0xFFE84C72)
                    : isLocked
                        ? const Color(0xFF251538)
                        : isOfficial
                            ? const Color(0xFF6D5DF6)
                            : isInvite
                                ? const Color(0xFF12C7B7)
                                : isStrangerGroup
                                    ? const Color(0xFFC99A3B)
                                    : const Color(0xFFE84C72),
              ),
              if (isStrangerGroup) ...[
                const SizedBox(width: 5),
                const _ConversationBadge(
                  label: 'Grouped',
                  color: Color(0xFF8C8198),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _ConversationTrailing extends StatelessWidget {
  const _ConversationTrailing({
    required this.conversation,
  });

  final _InboxConversation conversation;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            conversation.time,
            style: const TextStyle(
              color: Color(0xFF8C8198),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (conversation.unreadCount > 0)
            Container(
              height: 19,
              constraints: const BoxConstraints(minWidth: 19),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: const BoxDecoration(
                color: Color(0xFFE84C72),
                borderRadius: BorderRadius.all(Radius.circular(99)),
              ),
              child: Center(
                child: Text(
                  conversation.unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
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

class _InboxAvatar extends StatelessWidget {
  const _InboxAvatar({
    required this.conversation,
    required this.size,
    required this.isLocked,
    required this.isBlocked,
  });

  final _InboxConversation conversation;
  final double size;
  final bool isLocked;
  final bool isBlocked;

  @override
  Widget build(BuildContext context) {
    final isOfficial = conversation.type == _InboxType.official;
    final isStrangerGroup = conversation.type == _InboxType.strangerGroup;
    final isOnline = conversation.presence == _PresenceStatus.online;
    final isInRoom = conversation.currentRoomName != null;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: size,
          width: size,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: isBlocked
                  ? const [
                      Color(0xFF8C8198),
                      Color(0xFFE84C72),
                    ]
                  : conversation.colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: Center(
              child: Text(
                conversation.avatarText,
                style: TextStyle(
                  color: isBlocked
                      ? const Color(0xFFE84C72)
                      : conversation.colors.first,
                  fontSize: size * 0.36,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            height: 13,
            width: 13,
            decoration: BoxDecoration(
              color:
                  isOnline ? const Color(0xFF12C7B7) : const Color(0xFF8C8198),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
        if (isInRoom && !isLocked && !isBlocked)
          Positioned(
            left: -3,
            bottom: -2,
            child: Container(
              height: 16,
              width: 16,
              decoration: BoxDecoration(
                color: const Color(0xFF6D5DF6),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.graphic_eq_rounded,
                color: Colors.white,
                size: 9,
              ),
            ),
          ),
        if (isLocked || isBlocked || isOfficial || isStrangerGroup)
          Positioned(
            right: -3,
            top: -3,
            child: Container(
              height: 17,
              width: 17,
              decoration: BoxDecoration(
                color: isBlocked
                    ? const Color(0xFFE84C72)
                    : isLocked
                        ? const Color(0xFF251538)
                        : isOfficial
                            ? const Color(0xFF6D5DF6)
                            : const Color(0xFFC99A3B),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(
                isBlocked
                    ? Icons.block_rounded
                    : isLocked
                        ? Icons.lock_rounded
                        : isOfficial
                            ? Icons.verified_rounded
                            : Icons.shield_rounded,
                color: Colors.white,
                size: 9,
              ),
            ),
          ),
      ],
    );
  }
}

class _PresenceText extends StatelessWidget {
  const _PresenceText({
    required this.conversation,
  });

  final _InboxConversation conversation;

  @override
  Widget build(BuildContext context) {
    final isOnline = conversation.presence == _PresenceStatus.online;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 6,
          width: 6,
          decoration: BoxDecoration(
            color:
                isOnline ? const Color(0xFF12C7B7) : const Color(0xFF8C8198),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            conversation.lastSeenText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color:
                  isOnline ? const Color(0xFF05796D) : const Color(0xFF8C8198),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _RoomStatusText extends StatelessWidget {
  const _RoomStatusText({
    required this.roomName,
  });

  final String roomName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.graphic_eq_rounded,
          size: 12,
          color: Color(0xFF6D5DF6),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            'In chatroom: $roomName',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF6D5DF6),
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _ConversationBadge extends StatelessWidget {
  const _ConversationBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF251538),
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ChatOptionsSheet extends StatelessWidget {
  const _ChatOptionsSheet({
    required this.conversation,
    required this.isLocked,
    required this.isBlocked,
    required this.onLockTap,
    required this.onBlockTap,
    required this.onReportTap,
  });

  final _InboxConversation conversation;
  final bool isLocked;
  final bool isBlocked;
  final VoidCallback onLockTap;
  final VoidCallback onBlockTap;
  final VoidCallback onReportTap;

  @override
  Widget build(BuildContext context) {
    final canBlockOrReport = conversation.type != _InboxType.official &&
        conversation.type != _InboxType.strangerGroup;

    return Container(
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF251538).withValues(alpha: 0.14),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _InboxAvatar(
                  conversation: conversation,
                  size: 46,
                  isLocked: isLocked,
                  isBlocked: isBlocked,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    conversation.title,
                    style: const TextStyle(
                      color: Color(0xFF251538),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.close_rounded,
                      color: Color(0xFF8C8198),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _OptionRow(
              icon: isLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
              title: isLocked ? 'Unlock chat' : 'Lock this chat',
              subtitle: isLocked
                  ? 'Show message preview and open without PIN.'
                  : 'Hide preview and require PIN before opening.',
              color: const Color(0xFF251538),
              onTap: onLockTap,
            ),
            if (canBlockOrReport) ...[
              const SizedBox(height: 8),
              _OptionRow(
                icon: isBlocked ? Icons.person_add_alt_rounded : Icons.block_rounded,
                title: isBlocked ? 'Unblock profile' : 'Block profile',
                subtitle: isBlocked
                    ? 'Allow this user to message you again.'
                    : 'Stop normal messages from this user.',
                color:
                    isBlocked ? const Color(0xFF12C7B7) : const Color(0xFFE84C72),
                onTap: onBlockTap,
              ),
              const SizedBox(height: 8),
              _OptionRow(
                icon: Icons.report_rounded,
                title: 'Report profile',
                subtitle: 'Send this profile to CS/Monitor review later.',
                color: const Color(0xFFC99A3B),
                onTap: onReportTap,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF251538),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF7A6B86),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Color(0xFF8C8198),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportProfileSheet extends StatefulWidget {
  const _ReportProfileSheet({
    required this.conversation,
    required this.onSubmit,
  });

  final _InboxConversation conversation;
  final ValueChanged<String> onSubmit;

  @override
  State<_ReportProfileSheet> createState() => _ReportProfileSheetState();
}

class _ReportProfileSheetState extends State<_ReportProfileSheet> {
  String _selectedReason = 'Harassment or abuse';

  final List<String> _reasons = const [
    'Harassment or abuse',
    'Spam or scam',
    'Inappropriate profile',
    'Fake account',
    'Hate or harmful behavior',
    'Other safety issue',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF251538).withValues(alpha: 0.14),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC99A3B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: const Icon(
                    Icons.report_rounded,
                    color: Color(0xFFC99A3B),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Report ${widget.conversation.title}',
                    style: const TextStyle(
                      color: Color(0xFF251538),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._reasons.map(
              (reason) {
                final selected = reason == _selectedReason;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedReason = reason;
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF251538).withValues(alpha: 0.08)
                          : const Color(0xFFFAF7F1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF251538)
                            : const Color(0xFFECE2D8),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            reason,
                            style: const TextStyle(
                              color: Color(0xFF251538),
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (selected)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF251538),
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF251538),
                      side: const BorderSide(color: Color(0xFFECE2D8)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => widget.onSubmit(_selectedReason),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE84C72),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text(
                      'Submit Report',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatUnlockSheet extends StatefulWidget {
  const _ChatUnlockSheet({
    required this.conversation,
    required this.mockPin,
    required this.onUnlocked,
    required this.onForgotPin,
  });

  final _InboxConversation conversation;
  final String mockPin;
  final VoidCallback onUnlocked;
  final VoidCallback onForgotPin;

  @override
  State<_ChatUnlockSheet> createState() => _ChatUnlockSheetState();
}

class _ChatUnlockSheetState extends State<_ChatUnlockSheet> {
  final TextEditingController _pinController = TextEditingController();

  String? _errorText;
  int _failedAttempts = 0;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _unlock() {
    final pin = _pinController.text.trim();

    if (pin == widget.mockPin) {
      widget.onUnlocked();
      return;
    }

    setState(() {
      _failedAttempts += 1;
      _errorText = _failedAttempts >= 3
          ? 'Too many wrong attempts. Cooldown will be added later.'
          : 'Wrong PIN. Try 1234 for mock testing.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF251538).withValues(alpha: 0.14),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 62,
                width: 62,
                decoration: BoxDecoration(
                  color: const Color(0xFF251538).withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  color: Color(0xFF251538),
                  size: 32,
                ),
              ),
              const SizedBox(height: 13),
              Text(
                'Unlock ${widget.conversation.title}',
                style: const TextStyle(
                  color: Color(0xFF251538),
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'This chat is locked. Enter your PIN to open it.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF7A6B86),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF251538),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '1234',
                  errorText: _errorText,
                  filled: true,
                  fillColor: const Color(0xFFFAF7F1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Color(0xFFECE2D8)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Color(0xFFECE2D8)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(
                      color: Color(0xFF12C7B7),
                      width: 1.4,
                    ),
                  ),
                ),
                onSubmitted: (_) => _unlock(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onForgotPin,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF251538),
                        side: const BorderSide(color: Color(0xFFECE2D8)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text(
                        'Forgot PIN',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _unlock,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF251538),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text(
                        'Unlock',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
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

class _EmptyInboxState extends StatelessWidget {
  const _EmptyInboxState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(22),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFECE2D8)),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_rounded,
              color: Color(0xFF8C8198),
              size: 44,
            ),
            SizedBox(height: 12),
            Text(
              'No conversations here',
              style: TextStyle(
                color: Color(0xFF251538),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Chats, room invites, stranger messages, online status, locks and profile safety controls will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF7A6B86),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFECE2D8)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF251538).withValues(alpha: 0.045),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: const Color(0xFF251538),
            size: 21,
          ),
        ),
      ),
    );
  }
}

enum _InboxType {
  chat,
  roomInvite,
  official,
  stranger,
  strangerGroup,
}

enum _PresenceStatus {
  online,
  offline,
}

class _InboxConversation {
  const _InboxConversation({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.badge,
    required this.unreadCount,
    required this.avatarText,
    required this.type,
    required this.presence,
    required this.lastSeenText,
    required this.currentRoomName,
    required this.colors,
    required this.messages,
  });

  final String id;
  final String title;
  final String subtitle;
  final String time;
  final String badge;
  final int unreadCount;
  final String avatarText;
  final _InboxType type;
  final _PresenceStatus presence;
  final String lastSeenText;
  final String? currentRoomName;
  final List<Color> colors;
  final List<_InboxMessage> messages;
}

class _InboxMessage {
  const _InboxMessage({
    required this.sender,
    required this.text,
    required this.time,
    required this.isMine,
    this.inviteRoomName,
  });

  final String sender;
  final String text;
  final String time;
  final bool isMine;
  final String? inviteRoomName;
}