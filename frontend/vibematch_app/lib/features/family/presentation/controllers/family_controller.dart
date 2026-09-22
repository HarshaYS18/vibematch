import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/family_api_service.dart';
import '../../models/family_level_models.dart';
import '../../models/family_ui_models.dart';
import '../../../social/data/social_api_service.dart';
import '../../../social/models/social_user.dart';

class FamilyController extends ChangeNotifier {
  FamilyController({
    bool initialHasFamily = false,
    FamilyProfileUiModel? initialProfile,
    bool initialIsOwner = false,
    bool initialIsAdmin = false,
  }) : profile = initialProfile ?? _emptyFamilyProfile,
       rankings = <FamilyRankUiModel>[],
       members = <FamilyMemberUiModel>[],
       inviteFriends = <FamilyInviteFriendUiModel>[],
       messages = <FamilyChatUiModel>[],
       hasFamily = initialHasFamily,
       isOwner = initialIsOwner,
       isAdmin = initialIsAdmin {
    unawaited(hydrateFromBackend());
    unawaited(refreshInviteCandidates());
  }

  static const FamilyLevelEngine _levelEngine = FamilyLevelEngine();
  static const FamilyApiService _api = FamilyApiService();
  static const SocialApiService _socialApi = SocialApiService();
  static const FamilyProfileUiModel _emptyFamilyProfile = FamilyProfileUiModel(
    id: '',
    name: '',
    minimumVipLabel: '',
    memberCount: 0,
    maxMembers: 0,
    rankLabel: '',
    ownerUserId: '',
    quarterCarryExp: 0,
    giftCoinsThisQuarter: 0,
    timeMinutesToday: 0,
  );

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
  bool loadingRankings = false;
  String? backendError;
  FamilyRankingPeriod selectedRankingPeriod = FamilyRankingPeriod.weekly;

  FamilyInviteActorType get inviteActorType => (isOwner || isAdmin)
      ? FamilyInviteActorType.ownerAdmin
      : FamilyInviteActorType.member;
  bool get canSelectMoreInvites => selectedInviteUserIds.length < 10;

  FamilyExpBreakdown get expBreakdown => _levelEngine.buildBreakdown(
    quarterCarryExp: profile.quarterCarryExp,
    giftCoinsSpent: profile.giftCoinsThisQuarter,
    familyTimeMinutesToday: profile.timeMinutesToday,
  );

  FamilyLevelProgress get levelProgress =>
      _levelEngine.progressForExp(expBreakdown.totalExp);

  int get adminCapacity =>
      _levelEngine.adminCapacityForLevel(levelProgress.level);
  int get adminCount =>
      members.where((member) => member.role == FamilyRole.admin).length;

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
      } else if (!hasFamily) {
        profile = _emptyFamilyProfile;
      }
      members
        ..clear()
        ..addAll(response.members);
      rankings
        ..clear()
        ..addAll(response.rankings);
      if (response.rankings.isEmpty) unawaited(refreshRankings());
      if (hasFamily && profile.id.trim().isNotEmpty) {
        unawaited(refreshChat());
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

  Future<void> setRankingPeriod(FamilyRankingPeriod period) async {
    if (selectedRankingPeriod == period && rankings.isNotEmpty) return;
    selectedRankingPeriod = period;
    notifyListeners();
    await refreshRankings(period: period);
  }

  Future<void> refreshRankings({FamilyRankingPeriod? period}) async {
    final activePeriod = period ?? selectedRankingPeriod;
    selectedRankingPeriod = activePeriod;
    loadingRankings = true;
    notifyListeners();
    try {
      final backendRankings = await _api.getRankings(period: activePeriod);
      rankings
        ..clear()
        ..addAll(backendRankings);
      loadingRankings = false;
      backendError = null;
      notifyListeners();
    } catch (error) {
      loadingRankings = false;
      backendError = error.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  Future<void> refreshMembers() async {
    if (profile.id.trim().isEmpty) return;
    try {
      final backendMembers = await _api.getMembers(familyId: profile.id);
      members
        ..clear()
        ..addAll(backendMembers);
      notifyListeners();
    } catch (_) {
      // Keep current member list if backend is unavailable.
    }
  }

  Future<void> refreshInviteCandidates() async {
    try {
      final friends = await _socialApi.listFriendUsers();
      inviteFriends
        ..clear()
        ..addAll(friends.map(_inviteFriendFromSocialUser));
      selectedInviteUserIds.removeWhere(
        (id) => inviteFriends.every((friend) => friend.userId != id),
      );
      notifyListeners();
    } catch (_) {
      inviteFriends.clear();
      selectedInviteUserIds.clear();
      notifyListeners();
    }
  }

  void openFamilyFromRanking(FamilyRankUiModel family) {
    profile = family.toProfile();
    hasFamily = false;
    unawaited(refreshMembers());
    notifyListeners();
  }

  void createFamily({required String name, required String minimumVipLabel}) {
    if (loadingBackend) return;
    loadingBackend = true;
    backendError = null;
    joinRequestPending = false;
    notifyListeners();

    unawaited(
      _createFamilyOnBackend(name: name, minimumVipLabel: minimumVipLabel),
    );
  }

  Future<void> _createFamilyOnBackend({
    required String name,
    required String minimumVipLabel,
  }) async {
    try {
      final backendProfile = await _api.createFamily(
        name: name,
        minimumVipLabel: minimumVipLabel,
      );
      profile = backendProfile;
      hasFamily = true;
      isOwner = true;
      isAdmin = true;
      loadingBackend = false;
      backendError = null;
      notifyListeners();
      unawaited(refreshMembers());
    } catch (error) {
      loadingBackend = false;
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
      joinRequestPending = false;
      await hydrateFromBackend();
      backendError = null;
      notifyListeners();
    } catch (error) {
      joinRequestPending = false;
      backendError = error.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  void applyAdminSelection(Set<String> adminUserIds) {
    final cappedAdminIds = adminUserIds.take(adminCapacity).toSet();
    loadingBackend = true;
    backendError = null;
    notifyListeners();

    unawaited(_setAdminsOnBackend(cappedAdminIds));
  }

  Future<void> _setAdminsOnBackend(Set<String> adminUserIds) async {
    try {
      await _api.setAdmins(familyId: profile.id, adminUserIds: adminUserIds);
      await refreshMembers();
      loadingBackend = false;
      backendError = null;
      notifyListeners();
    } catch (error) {
      loadingBackend = false;
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
    return inviteFriends
        .where((friend) => selectedInviteUserIds.contains(friend.userId))
        .toList();
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
    loadingBackend = true;
    backendError = null;
    notifyListeners();

    unawaited(_leaveFamilyOnBackend(oldFamilyId));
  }

  Future<void> _leaveFamilyOnBackend(String familyId) async {
    try {
      await _api.leaveFamily(familyId: familyId);
      _clearCurrentFamily();
      loadingBackend = false;
      backendError = null;
      notifyListeners();
    } catch (error) {
      loadingBackend = false;
      backendError = error.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  void disbandFamily() {
    final oldFamilyId = profile.id;
    loadingBackend = true;
    backendError = null;
    notifyListeners();

    unawaited(_disbandFamilyOnBackend(oldFamilyId));
  }

  Future<void> _disbandFamilyOnBackend(String familyId) async {
    try {
      await _api.disbandFamily(familyId: familyId);
      _clearCurrentFamily();
      loadingBackend = false;
      backendError = null;
      notifyListeners();
    } catch (error) {
      loadingBackend = false;
      backendError = error.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  Future<void> refreshChat() async {
    if (!hasFamily || profile.id.trim().isEmpty) return;
    try {
      final backendMessages = await _api.getChatMessages(familyId: profile.id);
      messages
        ..clear()
        ..addAll(backendMessages.reversed);
      backendError = null;
      notifyListeners();
    } catch (error) {
      backendError = error.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  Future<bool> sendMessage(String text) async {
    final clean = text.trim();
    if (clean.isEmpty || !hasFamily || profile.id.trim().isEmpty) return false;
    try {
      final sent = await _api.sendChatMessage(
        familyId: profile.id,
        text: clean,
      );
      messages.insert(0, sent);
      backendError = null;
      notifyListeners();
      return true;
    } catch (error) {
      backendError = error.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  void _clearCurrentFamily() {
    profile = _emptyFamilyProfile;
    hasFamily = false;
    isOwner = false;
    isAdmin = false;
    joinRequestPending = false;
    members.clear();
    messages.clear();
  }
}

FamilyInviteFriendUiModel _inviteFriendFromSocialUser(SocialUser user) {
  return FamilyInviteFriendUiModel(
    userId: user.publicUserId?.toString() ?? user.id,
    name: user.displayName,
    statusLabel: user.isOnline ? 'Online friend' : 'Friend',
    avatarGradient: user.colors,
    isMutualFriend: true,
  );
}
