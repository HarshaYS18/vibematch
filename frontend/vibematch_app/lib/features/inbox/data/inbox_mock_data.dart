import 'package:flutter/material.dart';

import '../models/inbox_models.dart';

class InboxMockData {
  const InboxMockData._();

  static const List<InboxConversation> conversations = [
    InboxConversation(
      id: 'team_official',
      title: 'Vibe Match Team',
      subtitle: 'Your custom room background was approved.',
      time: 'Now',
      avatarText: 'V',
      type: InboxConversationType.official,
      unreadCount: 2,
      isOnline: true,
      lastSeenText: 'online',
      colors: [Color(0xFF251538), Color(0xFF6D5DF6)],
      messages: [
        InboxMessage(sender: 'Vibe Match Team', text: 'Your custom room background was approved and applied.', time: 'Now', isMine: false),
        InboxMessage(sender: 'Vibe Match Team', text: 'Official updates, safety notices, account alerts and review results will appear here.', time: '2m ago', isMine: false),
      ],
    ),
    InboxConversation(
      id: 'akhil_room_invite',
      title: 'Akhil',
      subtitle: 'Invited you to join Late Night Chill.',
      time: '3m',
      avatarText: 'A',
      type: InboxConversationType.roomInvite,
      unreadCount: 1,
      isOnline: true,
      lastSeenText: 'online',
      currentRoomName: 'Late Night Chill',
      isLockedByBackend: true,
      colors: [Color(0xFF12C7B7), Color(0xFF6D5DF6)],
      messages: [
        InboxMessage(sender: 'Akhil', text: 'Bro join the room 🔥', time: '3m ago', isMine: false),
        InboxMessage(sender: 'Akhil', text: 'Room Invite: Late Night Chill\nAccess: invite allows direct entry while valid.', time: '3m ago', isMine: false, inviteRoomName: 'Late Night Chill'),
      ],
    ),
    InboxConversation(
      id: 'meera_chat',
      title: 'Meera',
      subtitle: 'That Vibe was nice ✨',
      time: '18m',
      avatarText: 'M',
      type: InboxConversationType.chat,
      unreadCount: 0,
      isOnline: false,
      lastSeenText: 'last seen 1 min ago',
      colors: [Color(0xFFE84C72), Color(0xFFFF8DAA)],
      messages: [
        InboxMessage(sender: 'Meera', text: 'That Vibe was nice ✨', time: '18m ago', isMine: false),
        InboxMessage(sender: 'You', text: 'Thanks! I’m improving the Vibes page next.', time: '15m ago', isMine: true),
      ],
    ),
    InboxConversation(
      id: 'riya_mention',
      title: 'Riya',
      subtitle: 'Mentioned you in a Vibe comment.',
      time: '1h',
      avatarText: 'R',
      type: InboxConversationType.chat,
      unreadCount: 1,
      isOnline: false,
      lastSeenText: 'last seen 1 hour ago',
      colors: [Color(0xFFC99A3B), Color(0xFFE84C72)],
      messages: [
        InboxMessage(sender: 'Riya', text: 'Mention notification: Riya mentioned you in a Vibe comment.', time: '1h ago', isMine: false),
      ],
    ),
    InboxConversation(
      id: 'stranger_kiran',
      title: 'Kiran',
      subtitle: 'Hey, saw you in Telugu Beats.',
      time: '9m',
      avatarText: 'K',
      type: InboxConversationType.stranger,
      unreadCount: 1,
      isOnline: true,
      lastSeenText: 'online',
      currentRoomName: 'Telugu Beats',
      colors: [Color(0xFF8C8198), Color(0xFF6D5DF6)],
      messages: [
        InboxMessage(sender: 'Kiran', text: 'Hey, saw you in Telugu Beats. Can we connect?', time: '9m ago', isMine: false),
      ],
    ),
    InboxConversation(
      id: 'stranger_nisha',
      title: 'Nisha',
      subtitle: 'Hi, I liked your Vibe post.',
      time: '28m',
      avatarText: 'N',
      type: InboxConversationType.stranger,
      unreadCount: 1,
      isOnline: false,
      lastSeenText: 'last seen 1 day ago',
      colors: [Color(0xFFE84C72), Color(0xFF8C8198)],
      messages: [
        InboxMessage(sender: 'Nisha', text: 'Hi, I liked your Vibe post. Stranger message request pending.', time: '28m ago', isMine: false),
      ],
    ),
  ];
}
