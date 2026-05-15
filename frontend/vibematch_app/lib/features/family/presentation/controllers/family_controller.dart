import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/family_api_service.dart';
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
        isAdmin = initialIsAdmin {
    unawaited(hydrateFromBackend());
  }

  static const FamilyLevelEngine _levelEngine = FamilyLevelEngine();
  static const FamilyApiService _api = FamilyApiService();

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
  bool loadingBackend = false;
  String? backendError;

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

  Future<void> hydrateFromBackend() async {
    loadingBackend = true;
    backendError = null;
    notifyListeners();

    try {
      final response = await _api.getMyFamily();
      hasFamily = response.hasFamily;
      isOwner = response.isOwner;
      isAdmin = response.isAdmin;
      final backendProfile = response.profile;
      if (backendProfile != null) {
        profile = backendProfile;
      }
      if (response.members.isNotEmpty) {
        members
          ..clear()
          ..addAll(response.members);
      }
      if (response.rankings.isNotEmpty) {
        rankings
          ..clear()
          ..addAll(response.rankings);
      } else {
        unawaited(refreshRankings());
      }
      loadingBackend = false;
      backendError = null;
      notifyListeners();
    } catch (error) {
      loadingBackend = false;
      backendError = error.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      unawaited(refreshRankings());
    }
  }

  Future<void> refreshRankings({FamilyRankingPeriod period = FamilyRankingPeriod.weekly}) async {
    try {
      final backendRankings = await _api.getRankings(period: period);
      if (backendRankings.isEmpty) return;
      rankings
        ..clear()
        ..addAll(backendRankings);
      notifyListeners();
    } catch (_) {
      // Keep mock rankings if backend is unavailable.
    }
  }

  Future<void> refreshMembers() async {
    if (profile.id.trim().isEmpty) return;
    try {
      final backendMembers = await _api.getMembers(familyId: profile.id);
      if (backendMembers.isEmpty) return;
      members
        ..clear()
        ..addAll(backendMembers);
      notifyListeners();
    } catch (_) {
      // Keep current member list if backend is unavailable.
    }
  }

  void openFamilyFromRanking(FamilyRankUiModel family) {
    profile = family.toProfile();
    hasFamily = false;
    unawaited(refreshMembers());
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

    unawaited(_createFamilyOnBackend(name: name, minimumVipLabel: minimumVipLabel));
  }

  Future<void> _createFamilyOnBackend({required String name, required String minimumVipLabel}) async {
    try {
      final backendProfile = await _api.createFamily(name: name, minimumVipLabel: minimumVipLabel);
      profile = backendProfile;
      hasFamily = true;
      isOwner = true;
      isAdmin = true;
      backendError = null;
      notifyListeners();
      unawaited(refreshMembers());
    } catch (error) {
      backendError = error.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  void requestJoinFamily({FamilyRankUiModel? family}) {
    if (hasFamily || joinRequestPending) return;
    if (family != null) profile = family.toProfile();
    joinRequestPending = true;
    notifyListeners();

    unawaited(_requestJoinOnBackend(profile.id));
  }

  Future<void> _requestJoinOnBackend(String familyId) async {
    try {
      await _api.requestJoinFamily(familyId: familyId);
      backendError = null;
      notifyListeners();
    } catch (error) {
      backendError = error.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
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

    unawaited(_setAdminsOnBackend(cappedAdminIds));
  }

  Future<void> _setAdminsOnBackend(Set<String> adminUserIds) async {
    try {
      await _api.setAdmins(familyId: profile.id, adminUserIds: adminUserIds);
      backendError = null;
      notifyListeners();
    } catch (error) {
      backendError = error.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
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
    final selectedIds = Set<String>.from(selectedInviteUserIds);
    selectedInviteUserIds.clear();
    notifyListeners();

    unawaited(_sendInvitesOnBackend(selectedIds));
  }

  Future<void> _sendInvitesOnBackend(Set<String> selectedIds) async {
    try {
      await _api.sendInvites(familyId: profile.id, userIds: selectedIds);
      backendError = null;
      notifyListeners();
    } catch (error) {
      backendError = error.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  void exitFamily() {
    final oldFamilyId = profile.id;
    hasFamily = false;
    isOwner = false;
    isAdmin = false;
    joinRequestPending = false;
    notifyListeners();

    unawaited(_leaveFamilyOnBackend(oldFamilyId));
  }

  Future<void> _leaveFamilyOnBackend(String familyId) async {
    try {
      await _api.leaveFamily(familyId: familyId);
      backendError = null;
      notifyListeners();
    } catch (error) {
      backendError = error.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  void disbandFamily() {
    final oldFamilyId = profile.id;
    hasFamily = false;
    isOwner = false;
    isAdmin = false;
    joinRequestPending = false;
    notifyListeners();

    unawaited(_disbandFamilyOnBackend(oldFamilyId));
  }

  Future<void> _disbandFamilyOnBackend(String familyId) async {
    try {
      await _api.disbandFamily(familyId: familyId);
      backendError = null;
      notifyListeners();
    } catch (error) {
      backendError = error.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  void sendMessage(String text) {
    final clean = text.trim();
    if (clean.isEmpty || !hasFamily) return;
    messages.insert(0, FamilyChatUiModel(senderName: 'You', message: clean, timeLabel: 'Now', isMine: true));
    notifyListeners();
  }
}
