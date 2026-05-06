import 'package:flutter/material.dart';

import '../models/family_id.dart';
import '../models/family_ui_models.dart';

class FamilyMockData {
  const FamilyMockData._();

  static FamilyProfileUiModel profile() {
    return FamilyProfileUiModel(
      id: FamilyId.generateMock(prefix: 'VMF', now: DateTime(2026, 5, 7, 12)),
      name: 'Aurora Circle',
      minimumVipLabel: 'VIP 5',
      memberCount: members.length,
      maxMembers: 200,
      rankLabel: 'No. 99+',
      ownerUserId: 'family_owner_01',
      quarterCarryExp: 280000,
      giftCoinsThisQuarter: 1085000,
      timeMinutesToday: 12240,
    );
  }

  static const List<FamilyMemberUiModel> members = [
    FamilyMemberUiModel(userId: 'family_owner_01', name: 'Nova Ray', role: FamilyRole.owner, contributionExp: 13530000, avatarGradient: [Color(0xFF12C7B7), Color(0xFF6D5DF6)], isFollowing: true),
    FamilyMemberUiModel(userId: 'family_admin_01', name: 'Orion Vale', role: FamilyRole.admin, contributionExp: 21830000, avatarGradient: [Color(0xFFE84C72), Color(0xFFFFD36A)], isFollowing: false),
    FamilyMemberUiModel(userId: 'family_admin_02', name: 'Luna Frost', role: FamilyRole.admin, contributionExp: 18800000, avatarGradient: [Color(0xFF4E8F3A), Color(0xFFB8F7D4)], isFollowing: false),
    FamilyMemberUiModel(userId: 'family_admin_03', name: 'Kai Storm', role: FamilyRole.admin, contributionExp: 8270000, avatarGradient: [Color(0xFF111827), Color(0xFF9CA3AF)], isFollowing: true),
    FamilyMemberUiModel(userId: 'family_member_01', name: 'Mira Sol', role: FamilyRole.member, contributionExp: 6400000, avatarGradient: [Color(0xFF7C3AED), Color(0xFFFFB8D7)], isFollowing: true),
    FamilyMemberUiModel(userId: 'family_member_02', name: 'Zara Moon', role: FamilyRole.member, contributionExp: 5450000, avatarGradient: [Color(0xFF251538), Color(0xFFFFD36A)], isFollowing: false),
    FamilyMemberUiModel(userId: 'family_member_03', name: 'Riven Fox', role: FamilyRole.member, contributionExp: 4890000, avatarGradient: [Color(0xFF0EA5E9), Color(0xFFB8F7FF)], isFollowing: false),
    FamilyMemberUiModel(userId: 'family_member_04', name: 'Ivy Lane', role: FamilyRole.member, contributionExp: 2840000, avatarGradient: [Color(0xFFEC4899), Color(0xFFFFD1DF)], isFollowing: true),
  ];

  static const List<FamilyInviteFriendUiModel> inviteFriends = [
    FamilyInviteFriendUiModel(userId: 'friend_01', name: 'Astra Vale', statusLabel: 'Mutual friend', avatarGradient: [Color(0xFF06B6D4), Color(0xFF6366F1)]),
    FamilyInviteFriendUiModel(userId: 'friend_02', name: 'Blaze Hart', statusLabel: 'Mutual friend', avatarGradient: [Color(0xFFFF6B6B), Color(0xFFFFD166)]),
    FamilyInviteFriendUiModel(userId: 'friend_03', name: 'Cyan Reef', statusLabel: 'Mutual friend', avatarGradient: [Color(0xFF14B8A6), Color(0xFF99F6E4)]),
    FamilyInviteFriendUiModel(userId: 'friend_04', name: 'Dusk Vero', statusLabel: 'Mutual friend', avatarGradient: [Color(0xFF312E81), Color(0xFFA78BFA)]),
    FamilyInviteFriendUiModel(userId: 'friend_05', name: 'Echo Rain', statusLabel: 'Mutual friend', avatarGradient: [Color(0xFF0F172A), Color(0xFF38BDF8)]),
    FamilyInviteFriendUiModel(userId: 'friend_06', name: 'Faye Lux', statusLabel: 'Mutual friend', avatarGradient: [Color(0xFFDB2777), Color(0xFFFBCFE8)]),
    FamilyInviteFriendUiModel(userId: 'friend_07', name: 'Grey Knox', statusLabel: 'Mutual friend', avatarGradient: [Color(0xFF374151), Color(0xFFD1D5DB)]),
    FamilyInviteFriendUiModel(userId: 'friend_08', name: 'Halo Nyx', statusLabel: 'Mutual friend', avatarGradient: [Color(0xFF7C2D12), Color(0xFFFCD34D)]),
    FamilyInviteFriendUiModel(userId: 'friend_09', name: 'Iris Cove', statusLabel: 'Mutual friend', avatarGradient: [Color(0xFF9333EA), Color(0xFFF0ABFC)]),
    FamilyInviteFriendUiModel(userId: 'friend_10', name: 'Jade Pax', statusLabel: 'Mutual friend', avatarGradient: [Color(0xFF166534), Color(0xFF86EFAC)]),
    FamilyInviteFriendUiModel(userId: 'friend_11', name: 'Kite Noor', statusLabel: 'Mutual friend', avatarGradient: [Color(0xFF1D4ED8), Color(0xFF93C5FD)]),
    FamilyInviteFriendUiModel(userId: 'friend_12', name: 'Lyra Sun', statusLabel: 'Mutual friend', avatarGradient: [Color(0xFFEA580C), Color(0xFFFED7AA)]),
  ];

  static const List<FamilyVibeUiModel> vibes = [
    FamilyVibeUiModel(id: 'family_vibe_01', authorName: 'Nova Ray', caption: 'Family night starts at 9 PM. Bring your best room vibe.', tag: 'Event', isVideo: true, likes: 17, comments: 2, gradient: [Color(0xFF251538), Color(0xFFE84C72)]),
    FamilyVibeUiModel(id: 'family_vibe_02', authorName: 'Orion Vale', caption: 'Quarterly push is live: gifts and room time both grow family EXP.', tag: 'Update', isVideo: false, likes: 42, comments: 11, gradient: [Color(0xFF0F172A), Color(0xFF12C7B7)]),
  ];

  static const List<FamilyChatUiModel> chats = [
    FamilyChatUiModel(senderName: 'Nova Ray', message: 'Let us push family contribution before settlement.', timeLabel: '2m', isMine: false),
    FamilyChatUiModel(senderName: 'You', message: 'Done. I will open the family room tonight.', timeLabel: 'Now', isMine: true),
  ];
}
