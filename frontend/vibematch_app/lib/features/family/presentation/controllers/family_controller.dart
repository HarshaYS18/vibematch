import 'package:flutter/material.dart';

import '../../data/family_mock_data.dart';
import '../../models/family_id.dart';
import '../../models/family_level_models.dart';
import '../../models/family_ui_models.dart';

class FamilyController extends ChangeNotifier {
  FamilyController()
      : profile = FamilyMockData.profile(),
        members = [...FamilyMockData.members],
        vibes = [...FamilyMockData.vibes],
        messages = [...FamilyMockData.chats];

  static const FamilyLevelEngine _levelEngine = FamilyLevelEngine();

  FamilyProfileUiModel profile;
  final List<FamilyMemberUiModel> members;
  final List<FamilyVibeUiModel> vibes;
  final List<FamilyChatUiModel> messages;

  bool hasFamily = true;
  bool isOwner = true;
  bool isAdmin = true;
  FamilyChannelTab selectedTab = FamilyChannelTab.vibes;

  FamilyExpBreakdown get expBreakdown => _levelEngine.buildBreakdown(
        quarterCarryExp: profile.quarterCarryExp,
        giftCoinsSpent: profile.giftCoinsThisQuarter,
        familyTimeMinutesToday: profile.timeMinutesToday,
      );

  FamilyLevelProgress get levelProgress => _levelEngine.progressForExp(expBreakdown.totalExp);

  int get adminCapacity => _levelEngine.adminCapacityForLevel(levelProgress.level);
  int get adminCount => members.where((member) => member.role == FamilyRole.admin).length;
  bool get canPostFamilyVibe => isOwner || isAdmin;

  void selectTab(FamilyChannelTab tab) {
    selectedTab = tab;
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
    notifyListeners();
  }

  void exitFamily() {
    hasFamily = false;
    isOwner = false;
    isAdmin = false;
    notifyListeners();
  }

  void disbandFamily() {
    hasFamily = false;
    notifyListeners();
  }

  void postFamilyVibe() {
    if (!canPostFamilyVibe) return;
    vibes.insert(
      0,
      const FamilyVibeUiModel(
        id: 'local_family_vibe',
        authorName: 'You',
        caption: 'New family channel update posted locally.',
        tag: 'New',
        isVideo: false,
        likes: 0,
        comments: 0,
        gradient: [Color(0xFF12C7B7), Color(0xFF6D5DF6)],
      ),
    );
    notifyListeners();
  }

  void sendMessage(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return;
    messages.insert(0, FamilyChatUiModel(senderName: 'You', message: clean, timeLabel: 'Now', isMine: true));
    notifyListeners();
  }
}
