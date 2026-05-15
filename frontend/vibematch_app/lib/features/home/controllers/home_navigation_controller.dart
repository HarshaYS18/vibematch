import 'package:flutter/material.dart';

import '../../../core/navigation/vm_navigator.dart';
import '../../auth/models/current_user.dart';
import '../../create/presentation/create_page.dart';
import '../models/home_banner.dart';
import '../models/home_room.dart';
import '../presentation/widgets/home_language_sheet.dart';
import '../presentation/widgets/home_locked_room_sheet.dart';
import 'home_controller.dart';

class HomeNavigationController {
  const HomeNavigationController._();

  static bool canManageHomeBanners(Object? user, Object? currentUser) {
    final dynamic activeUser = user ?? currentUser;
    try {
      final primaryRole = activeUser?.primaryRole?.toString().toLowerCase();
      final roles = activeUser?.roles;
      if (primaryRole == 'founder_owner' || primaryRole == 'super_owner' || primaryRole == 'owner') return true;
      if (roles is Iterable) {
        return roles.any((role) {
          final normalized = role.toString().toLowerCase();
          return normalized == 'founder_owner' ||
              normalized == 'owner' ||
              normalized == 'super_owner' ||
              normalized == 'banner_manager' ||
              normalized == 'manage_home_banners' ||
              normalized == 'permission_manage_home_banners';
        });
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  static CurrentUser? activeCurrentUser(Object? user, Object? currentUser) {
    final activeUser = currentUser ?? user;
    return activeUser is CurrentUser ? activeUser : null;
  }

  static void showToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF251538),
        content: Text(message),
      ),
    );
  }

  static Future<void> openMyRoomOrCreate({
    required BuildContext context,
    required HomeController controller,
    required CurrentUser? currentUser,
  }) async {
    if (currentUser == null) {
      showToast(context, 'Login session not ready. Refresh and try again.');
      return;
    }

    var existingRoom = controller.myCreatedRoom;
    if (existingRoom == null) {
      showToast(context, 'Checking your room...');
      await controller.loadHomeChrome();
      if (!context.mounted) return;
      existingRoom = controller.myCreatedRoom;
    }

    if (existingRoom != null) {
      enterRoom(context: context, room: existingRoom, currentUser: currentUser);
      return;
    }

    await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => CreatePage(currentUser: currentUser)));
    if (!context.mounted) return;
    await controller.refreshAfterRoomCreation();
    if (!context.mounted) return;

    final createdRoom = controller.myCreatedRoom;
    if (createdRoom != null) {
      enterRoom(context: context, room: createdRoom, currentUser: currentUser);
      return;
    }
    showToast(context, 'Room saved. Pull to refresh if it does not appear.');
  }

  static void openRoom({
    required BuildContext context,
    required HomeRoom room,
    required CurrentUser? currentUser,
  }) {
    final mode = room.mode.toLowerCase();
    if (mode.contains('secret')) {
      showToast(context, 'No permission to enter this Secret Vibe room');
      return;
    }
    if (mode.contains('member')) {
      showToast(context, 'Members Only room. Membership approval required.');
      return;
    }
    if (mode.contains('lock')) {
      openLockedRoomSheet(context: context, room: room, currentUser: currentUser);
      return;
    }
    enterRoom(context: context, room: room, currentUser: currentUser);
  }

  static void enterRoom({
    required BuildContext context,
    required HomeRoom room,
    required CurrentUser? currentUser,
  }) {
    VmNavigator.openLiveRoom(
      context,
      roomName: room.name,
      roomId: room.id,
      language: room.language,
      modeTitle: room.mode,
      onlineCount: room.onlineCount,
      currentUser: currentUser,
    );
  }

  static void openLockedRoomSheet({
    required BuildContext context,
    required HomeRoom room,
    required CurrentUser? currentUser,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => HomeLockedRoomSheet(
        room: room,
        onWrongPassword: () => showToast(context, 'Wrong password.'),
        onPasswordAccepted: () => enterRoom(context: context, room: room, currentUser: currentUser),
      ),
    );
  }

  static void openLanguageSheet({
    required BuildContext context,
    required HomeController controller,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => HomeLanguageSheet(
        languages: controller.languages,
        selectedLanguage: controller.selectedLanguage,
        onLanguageSelected: (language) {
          controller.selectLanguage(language);
          Navigator.pop(context);
        },
      ),
    );
  }

  static void seeAllRooms({
    required BuildContext context,
    required HomeController controller,
  }) {
    controller.seeAllRooms();
    if (controller.selectedCategory == 'Following') {
      showToast(context, 'Showing all rooms where followed users are active');
      return;
    }
    showToast(context, 'Showing all public open rooms');
  }

  static void handleBannerTap(BuildContext context, HomeBanner banner) {
    switch (banner.target) {
      case 'event':
        VmNavigator.openEvents(context);
        return;
      case 'recharge':
        VmNavigator.openWallet(context);
        return;
      case 'promo':
        VmNavigator.openStore(context);
        return;
      default:
        VmNavigator.openEvents(context);
        return;
    }
  }

  static void handlePolicyBannerTap(BuildContext context, HomeBanner banner) {
    if (banner.target == 'policy') {
      VmNavigator.openSettings(context);
      return;
    }
    showToast(context, banner.title);
  }
}
