import 'package:flutter/material.dart';

import '../../data/family_mock_data.dart';
import '../../models/family_id.dart';
import '../../models/family_level_models.dart';
import '../../models/family_ui_models.dart';

class FamilyController extends ChangeNotifier {
  FamilyController({
    bool initialHasFamily = false,
    FamilyProfileUiModel? initialProfile,
    bool initialIsOwner = false,
    bool initialIsAdmin = false,
  })  : profile = initialProfile ?? FamilyMockData.profile(),
        rankings = [...FamilyMockData.rankings],
        members = [...FamilyMockData.members],
        inviteFriends = [...FamilyMockData.inviteFriends],
        messages = [...FamilyMockData.chats],
        hasFamily = initialHasFamily,
        isOwner = initialIsOwner,
        isAdmin = initialIsAdmin;

  static const FamilyLevelEngine _levelEngine = FamilyLevelEngine();

  FamilyProfileUiModel profile;
  final List<FamilyRankUiModel> rankings;
  final List<FamilyMemberUiModel> members;
  final List<FamilyInviteFriendUiModel> inviteFriends;
  final List<FamilyChatUiModel> messages;
  final Set<String> selectedInviteUserIds = {};

  bool hasFamily;
  bool isOwner;
  bool isAdmin;
  bool joinRequestPending = false;

  FamilyInviteActorType get inviteActorType => (isOwner || isAdmin) ? FamilyInviteActorType.ownerAdmin : FamilyInviteActorType.member;
  bool get canSelectMoreInvites => selectedInviteUserIds.length < 10;

  FamilyExpBreakdown get expBreakdown => _levelEngine.buildBreakdown(
        quarterCarryExp: profile.quarterCarryExp,
        giftCoinsSpent: profile.giftCoinsThisQuarter,
        familyTimeMinutesToday: profile.timeMinutesToday,
      );

  FamilyLevelProgress get levelProgress => _levelEngine.progressForExp(expBreakdown.totalExp);

  int get adminCapacity => _levelEngine.adminCapacityForLevel(levelProgress.level);
  int get adminCount => members.where((member) => member.role == FamilyRole.admin).length;

  void openFamilyFromRanking(FamilyRankUiModel family) {
    profile = family.toProfile();
    notifyListeners();
  }

  void createFamily({required String name, required String minimumVipLabel}) {
    profile = FamilyProfileUiModel(
      id: FamilyId.generateMock(prefix: 'VMF'),
      name: name,
      minimumVipLabel: minimumVipLabel,
      memberCount: 1,
      maxMembers: 200,
      rankLabel: 'Unranked',
      ownerUserId: 'current_user',
      quarterCarryExp: 0,
      giftCoinsThisQuarter: 0,
      timeMinutesToday: 0,
    );
    hasFamily = true;
    isOwner = true;
    isAdmin = true;
    joinRequestPending = false;
    notifyListeners();
  }

  void requestJoinFamily({FamilyRankUiModel? family}) {
    if (hasFamily || joinRequestPending) return;
    if (family != null) profile = family.toProfile();
    joinRequestPending = true;
    notifyListeners();
  }

  void mockApproveJoinRequest() {
    if (!joinRequestPending) return;
    hasFamily = true;
    isOwner = false;
    isAdmin = false;
    joinRequestPending = false;
    notifyListeners();
  }

  void mockRejectJoinRequest() {
    joinRequestPending = false;
    notifyListeners();
  }

  void applyAdminSelection(Set<String> adminUserIds) {
    final cappedAdminIds = adminUserIds.take(adminCapacity).toSet();
    for (var index = 0; index < members.length; index++) {
      final member = members[index];
      if (member.role == FamilyRole.owner) continue;
      members[index] = FamilyMemberUiModel(
        userId: member.userId,
        name: member.name,
        role: cappedAdminIds.contains(member.userId) ? FamilyRole.admin : FamilyRole.member,
        contributionExp: member.contributionExp,
        avatarGradient: member.avatarGradient,
        isFollowing: member.isFollowing,
      );
    }
    notifyListeners();
  }

  void toggleInviteSelection(FamilyInviteFriendUiModel friend) {
    if (!friend.canInvite) return;
    if (selectedInviteUserIds.contains(friend.userId)) {
      selectedInviteUserIds.remove(friend.userId);
    } else if (selectedInviteUserIds.length < 10) {
      selectedInviteUserIds.add(friend.userId);
    }
    notifyListeners();
  }

  void clearInviteSelection() {
    selectedInviteUserIds.clear();
    notifyListeners();
  }

  List<FamilyInviteFriendUiModel> selectedInviteFriends() {
    return inviteFriends.where((friend) => selectedInviteUserIds.contains(friend.userId)).toList();
  }

  void markInvitesSent() {
    selectedInviteUserIds.clear();
    notifyListeners();
  }

  void exitFamily() {
    hasFamily = false;
    isOwner = false;
    isAdmin = false;
    joinRequestPending = false;
    notifyListeners();
  }

  void disbandFamily() {
    hasFamily = false;
    isOwner = false;
    isAdmin = false;
    joinRequestPending = false;
    notifyListeners();
  }

  void sendMessage(String text) {
    final clean = text.trim();
    if (clean.isEmpty || !hasFamily) return;
    messages.insert(0, FamilyChatUiModel(senderName: 'You', message: clean, timeLabel: 'Now', isMine: true));
    notifyListeners();
  }
}
