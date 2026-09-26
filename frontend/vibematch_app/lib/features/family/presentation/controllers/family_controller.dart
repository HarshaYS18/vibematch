import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/family_api_service.dart';
import '../../models/family_level_models.dart';
import '../../models/family_ui_models.dart';
import '../../../social/data/social_api_service.dart';
import '../../../social/models/social_user.dart';

const Object _familyUnset = Object();

const FamilyProfileUiModel _emptyFamilyProfile = FamilyProfileUiModel(
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

class FamilyControllerArgs {
  const FamilyControllerArgs({
    this.initialHasFamily = false,
    this.initialProfile,
    this.initialIsOwner = false,
    this.initialIsAdmin = false,
  });

  final bool initialHasFamily;
  final FamilyProfileUiModel? initialProfile;
  final bool initialIsOwner;
  final bool initialIsAdmin;
}

class FamilyState {
  const FamilyState({
    required this.profile,
    this.rankings = const <FamilyRankUiModel>[],
    this.members = const <FamilyMemberUiModel>[],
    this.inviteFriends = const <FamilyInviteFriendUiModel>[],
    this.messages = const <FamilyChatUiModel>[],
    this.selectedInviteUserIds = const <String>{},
    this.hasFamily = false,
    this.isOwner = false,
    this.isAdmin = false,
    this.joinRequestPending = false,
    this.loadingBackend = false,
    this.loadingRankings = false,
    this.backendError,
    this.selectedRankingPeriod = FamilyRankingPeriod.weekly,
  });

  factory FamilyState.fromArgs(FamilyControllerArgs args) {
    return FamilyState(
      profile: args.initialProfile ?? _emptyFamilyProfile,
      hasFamily: args.initialHasFamily,
      isOwner: args.initialIsOwner,
      isAdmin: args.initialIsAdmin,
    );
  }

  final FamilyProfileUiModel profile;
  final List<FamilyRankUiModel> rankings;
  final List<FamilyMemberUiModel> members;
  final List<FamilyInviteFriendUiModel> inviteFriends;
  final List<FamilyChatUiModel> messages;
  final Set<String> selectedInviteUserIds;
  final bool hasFamily;
  final bool isOwner;
  final bool isAdmin;
  final bool joinRequestPending;
  final bool loadingBackend;
  final bool loadingRankings;
  final String? backendError;
  final FamilyRankingPeriod selectedRankingPeriod;

  FamilyState copyWith({
    FamilyProfileUiModel? profile,
    List<FamilyRankUiModel>? rankings,
    List<FamilyMemberUiModel>? members,
    List<FamilyInviteFriendUiModel>? inviteFriends,
    List<FamilyChatUiModel>? messages,
    Set<String>? selectedInviteUserIds,
    bool? hasFamily,
    bool? isOwner,
    bool? isAdmin,
    bool? joinRequestPending,
    bool? loadingBackend,
    bool? loadingRankings,
    Object? backendError = _familyUnset,
    FamilyRankingPeriod? selectedRankingPeriod,
  }) {
    return FamilyState(
      profile: profile ?? this.profile,
      rankings: List<FamilyRankUiModel>.unmodifiable(
        rankings ?? this.rankings,
      ),
      members: List<FamilyMemberUiModel>.unmodifiable(
        members ?? this.members,
      ),
      inviteFriends: List<FamilyInviteFriendUiModel>.unmodifiable(
        inviteFriends ?? this.inviteFriends,
      ),
      messages: List<FamilyChatUiModel>.unmodifiable(
        messages ?? this.messages,
      ),
      selectedInviteUserIds: Set<String>.unmodifiable(
        selectedInviteUserIds ?? this.selectedInviteUserIds,
      ),
      hasFamily: hasFamily ?? this.hasFamily,
      isOwner: isOwner ?? this.isOwner,
      isAdmin: isAdmin ?? this.isAdmin,
      joinRequestPending: joinRequestPending ?? this.joinRequestPending,
      loadingBackend: loadingBackend ?? this.loadingBackend,
      loadingRankings: loadingRankings ?? this.loadingRankings,
      backendError: identical(backendError, _familyUnset)
          ? this.backendError
          : backendError as String?,
      selectedRankingPeriod:
          selectedRankingPeriod ?? this.selectedRankingPeriod,
    );
  }
}

class FamilyController
    extends AutoDisposeFamilyNotifier<FamilyState, FamilyControllerArgs> {
  static const FamilyLevelEngine _levelEngine = FamilyLevelEngine();
  static const FamilyApiService _api = FamilyApiService();
  static const SocialApiService _socialApi = SocialApiService();

  @override
  FamilyState build(FamilyControllerArgs args) {
    final initial = FamilyState.fromArgs(args);
    Future<void>.microtask(() async {
      await Future.wait<void>([
        hydrateFromBackend(),
        refreshInviteCandidates(),
      ]);
    });
    return initial;
  }

  FamilyProfileUiModel get profile => state.profile;
  List<FamilyRankUiModel> get rankings => state.rankings;
  List<FamilyMemberUiModel> get members => state.members;
  List<FamilyInviteFriendUiModel> get inviteFriends => state.inviteFriends;
  List<FamilyChatUiModel> get messages => state.messages;
  Set<String> get selectedInviteUserIds => state.selectedInviteUserIds;
  bool get hasFamily => state.hasFamily;
  bool get isOwner => state.isOwner;
  bool get isAdmin => state.isAdmin;
  bool get joinRequestPending => state.joinRequestPending;
  bool get loadingBackend => state.loadingBackend;
  bool get loadingRankings => state.loadingRankings;
  String? get backendError => state.backendError;
  FamilyRankingPeriod get selectedRankingPeriod => state.selectedRankingPeriod;

  FamilyInviteActorType get inviteActorType =>
      (state.isOwner || state.isAdmin)
      ? FamilyInviteActorType.ownerAdmin
      : FamilyInviteActorType.member;

  bool get canSelectMoreInvites =>
      state.selectedInviteUserIds.length < 10;

  FamilyExpBreakdown get expBreakdown => _levelEngine.buildBreakdown(
    quarterCarryExp: state.profile.quarterCarryExp,
    giftCoinsSpent: state.profile.giftCoinsThisQuarter,
    familyTimeMinutesToday: state.profile.timeMinutesToday,
  );

  FamilyLevelProgress get levelProgress =>
      _levelEngine.progressForExp(expBreakdown.totalExp);

  int get adminCapacity =>
      _levelEngine.adminCapacityForLevel(levelProgress.level);

  int get adminCount =>
      state.members.where((member) => member.role == FamilyRole.admin).length;

  Future<void> hydrateFromBackend() async {
    state = state.copyWith(loadingBackend: true, backendError: null);
    try {
      final response = await _api.getMyFamily();
      final backendProfile = response.profile;
      state = state.copyWith(
        hasFamily: response.hasFamily,
        isOwner: response.isOwner,
        isAdmin: response.isAdmin,
        profile: backendProfile ??
            (response.hasFamily ? state.profile : _emptyFamilyProfile),
        members: response.members,
        rankings: response.rankings,
        loadingBackend: false,
        backendError: null,
      );
      if (response.rankings.isEmpty) {
        unawaited(refreshRankings());
      }
      if (response.hasFamily &&
          (backendProfile ?? state.profile).id.trim().isNotEmpty) {
        unawaited(refreshChat());
      }
    } catch (error) {
      state = state.copyWith(
        loadingBackend: false,
        backendError: error.toString().replaceFirst('Exception: ', ''),
      );
      unawaited(refreshRankings());
    }
  }

  Future<void> setRankingPeriod(FamilyRankingPeriod period) async {
    if (state.selectedRankingPeriod == period &&
        state.rankings.isNotEmpty) {
      return;
    }
    state = state.copyWith(selectedRankingPeriod: period);
    await refreshRankings(period: period);
  }

  Future<void> refreshRankings({FamilyRankingPeriod? period}) async {
    final activePeriod = period ?? state.selectedRankingPeriod;
    state = state.copyWith(
      selectedRankingPeriod: activePeriod,
      loadingRankings: true,
    );
    try {
      final backendRankings =
          await _api.getRankings(period: activePeriod);
      state = state.copyWith(
        rankings: backendRankings,
        loadingRankings: false,
        backendError: null,
      );
    } catch (error) {
      state = state.copyWith(
        loadingRankings: false,
        backendError: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> refreshMembers() async {
    if (state.profile.id.trim().isEmpty) return;
    try {
      state = state.copyWith(
        members: await _api.getMembers(familyId: state.profile.id),
      );
    } catch (_) {
      // Preserve last authoritative projection during transient failure.
    }
  }

  Future<void> refreshInviteCandidates() async {
    try {
      final friends = await _socialApi.listFriendUsers();
      final inviteFriends =
          friends.map(_inviteFriendFromSocialUser).toList(growable: false);
      final validIds =
          inviteFriends.map((friend) => friend.userId).toSet();
      state = state.copyWith(
        inviteFriends: inviteFriends,
        selectedInviteUserIds: state.selectedInviteUserIds
            .where(validIds.contains)
            .toSet(),
      );
    } catch (_) {
      state = state.copyWith(
        inviteFriends: const <FamilyInviteFriendUiModel>[],
        selectedInviteUserIds: const <String>{},
      );
    }
  }

  void openFamilyFromRanking(FamilyRankUiModel family) {
    state = state.copyWith(
      profile: family.toProfile(),
      hasFamily: false,
    );
    unawaited(refreshMembers());
  }

  void createFamily({
    required String name,
    required String minimumVipLabel,
  }) {
    if (state.loadingBackend) return;
    state = state.copyWith(
      loadingBackend: true,
      backendError: null,
      joinRequestPending: false,
    );
    unawaited(
      _createFamilyOnBackend(
        name: name,
        minimumVipLabel: minimumVipLabel,
      ),
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
      state = state.copyWith(
        profile: backendProfile,
        hasFamily: true,
        isOwner: true,
        isAdmin: true,
        loadingBackend: false,
        backendError: null,
      );
      unawaited(refreshMembers());
    } catch (error) {
      state = state.copyWith(
        loadingBackend: false,
        backendError: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void requestJoinFamily({FamilyRankUiModel? family}) {
    if (state.hasFamily || state.joinRequestPending) return;
    final profile = family?.toProfile() ?? state.profile;
    state = state.copyWith(
      profile: profile,
      joinRequestPending: true,
    );
    unawaited(_requestJoinOnBackend(profile.id));
  }

  Future<void> _requestJoinOnBackend(String familyId) async {
    try {
      await _api.requestJoinFamily(familyId: familyId);
      state = state.copyWith(joinRequestPending: false);
      await hydrateFromBackend();
      state = state.copyWith(backendError: null);
    } catch (error) {
      state = state.copyWith(
        joinRequestPending: false,
        backendError: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void applyAdminSelection(Set<String> adminUserIds) {
    final cappedAdminIds = adminUserIds.take(adminCapacity).toSet();
    state = state.copyWith(
      loadingBackend: true,
      backendError: null,
    );
    unawaited(_setAdminsOnBackend(cappedAdminIds));
  }

  Future<void> _setAdminsOnBackend(Set<String> adminUserIds) async {
    try {
      await _api.setAdmins(
        familyId: state.profile.id,
        adminUserIds: adminUserIds,
      );
      await refreshMembers();
      state = state.copyWith(
        loadingBackend: false,
        backendError: null,
      );
    } catch (error) {
      state = state.copyWith(
        loadingBackend: false,
        backendError: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void toggleInviteSelection(FamilyInviteFriendUiModel friend) {
    if (!friend.canInvite) return;
    final selected = Set<String>.of(state.selectedInviteUserIds);
    if (selected.contains(friend.userId)) {
      selected.remove(friend.userId);
    } else if (selected.length < 10) {
      selected.add(friend.userId);
    }
    state = state.copyWith(selectedInviteUserIds: selected);
  }

  void clearInviteSelection() {
    state = state.copyWith(selectedInviteUserIds: const <String>{});
  }

  List<FamilyInviteFriendUiModel> selectedInviteFriends() {
    return state.inviteFriends
        .where(
          (friend) =>
              state.selectedInviteUserIds.contains(friend.userId),
        )
        .toList(growable: false);
  }

  void markInvitesSent() {
    final selectedIds = Set<String>.from(state.selectedInviteUserIds);
    state = state.copyWith(selectedInviteUserIds: const <String>{});
    unawaited(_sendInvitesOnBackend(selectedIds));
  }

  Future<void> _sendInvitesOnBackend(Set<String> selectedIds) async {
    try {
      await _api.sendInvites(
        familyId: state.profile.id,
        userIds: selectedIds,
      );
      state = state.copyWith(backendError: null);
    } catch (error) {
      state = state.copyWith(
        backendError: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void exitFamily() {
    final oldFamilyId = state.profile.id;
    state = state.copyWith(
      loadingBackend: true,
      backendError: null,
    );
    unawaited(_leaveFamilyOnBackend(oldFamilyId));
  }

  Future<void> _leaveFamilyOnBackend(String familyId) async {
    try {
      await _api.leaveFamily(familyId: familyId);
      _clearCurrentFamily();
      state = state.copyWith(
        loadingBackend: false,
        backendError: null,
      );
    } catch (error) {
      state = state.copyWith(
        loadingBackend: false,
        backendError: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void disbandFamily() {
    final oldFamilyId = state.profile.id;
    state = state.copyWith(
      loadingBackend: true,
      backendError: null,
    );
    unawaited(_disbandFamilyOnBackend(oldFamilyId));
  }

  Future<void> _disbandFamilyOnBackend(String familyId) async {
    try {
      await _api.disbandFamily(familyId: familyId);
      _clearCurrentFamily();
      state = state.copyWith(
        loadingBackend: false,
        backendError: null,
      );
    } catch (error) {
      state = state.copyWith(
        loadingBackend: false,
        backendError: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> refreshChat() async {
    if (!state.hasFamily || state.profile.id.trim().isEmpty) return;
    try {
      final backendMessages =
          await _api.getChatMessages(familyId: state.profile.id);
      state = state.copyWith(
        messages: backendMessages.reversed.toList(growable: false),
        backendError: null,
      );
    } catch (error) {
      state = state.copyWith(
        backendError: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<bool> sendMessage(String text) async {
    final clean = text.trim();
    if (clean.isEmpty ||
        !state.hasFamily ||
        state.profile.id.trim().isEmpty) {
      return false;
    }
    try {
      final sent = await _api.sendChatMessage(
        familyId: state.profile.id,
        text: clean,
      );
      state = state.copyWith(
        messages: <FamilyChatUiModel>[sent, ...state.messages],
        backendError: null,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        backendError: error.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  void _clearCurrentFamily() {
    state = state.copyWith(
      profile: _emptyFamilyProfile,
      hasFamily: false,
      isOwner: false,
      isAdmin: false,
      joinRequestPending: false,
      members: const <FamilyMemberUiModel>[],
      messages: const <FamilyChatUiModel>[],
    );
  }
}

final familyControllerProvider =
    NotifierProvider.autoDispose.family<
      FamilyController,
      FamilyState,
      FamilyControllerArgs
    >(FamilyController.new);

FamilyInviteFriendUiModel _inviteFriendFromSocialUser(SocialUser user) {
  return FamilyInviteFriendUiModel(
    userId: user.publicUserId?.toString() ?? user.id,
    name: user.displayName,
    statusLabel: user.isOnline ? 'Online friend' : 'Friend',
    avatarGradient: user.colors,
    isMutualFriend: true,
  );
}
