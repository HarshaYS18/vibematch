import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../core/navigation/vm_navigator.dart';
import '../../../core/ui/vm_motion.dart';
import '../../auth/models/current_user.dart';
import '../../create/presentation/create_page.dart';
import '../../rooms/data/room_api_service.dart';
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
      if (primaryRole == 'founder_owner' ||
          primaryRole == 'super_owner' ||
          primaryRole == 'owner')
        return true;
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
      enterRoom(
        context: context,
        room: existingRoom,
        currentUser: currentUser,
        entryTransition: LiveRoomEntryTransition.homeTopRightRoomIcon,
      );
      return;
    }

    await Navigator.push<void>(
      context,
      VmMotion.pageRoute<void>(
        settings: const RouteSettings(name: 'create-room'),
        page: CreatePage(currentUser: currentUser),
      ),
    );
    if (!context.mounted) return;
    await controller.refreshAfterRoomCreation();
    if (!context.mounted) return;

    final createdRoom = controller.myCreatedRoom;
    if (createdRoom != null) {
      enterRoom(
        context: context,
        room: createdRoom,
        currentUser: currentUser,
        entryTransition: LiveRoomEntryTransition.homeTopRightRoomIcon,
      );
      return;
    }
    showToast(context, 'Room saved. Pull to refresh if it does not appear.');
  }

  static Future<void> quickMatch({
    required BuildContext context,
    required HomeController controller,
    required CurrentUser? currentUser,
  }) async {
    if (currentUser == null) {
      showToast(context, 'Login session not ready. Refresh and try again.');
      return;
    }
    try {
      final room = await controller.quickMatch();
      if (!context.mounted) return;
      if (room == null) {
        showToast(context, 'No public room is available right now.');
        return;
      }
      await _joinAndEnter(
        context: context,
        room: room,
        currentUser: currentUser,
      );
    } catch (error) {
      if (context.mounted) {
        showToast(context, error.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  static void openRoom({
    required BuildContext context,
    required HomeRoom room,
    required CurrentUser? currentUser,
  }) {
    unawaited(
      _joinAndEnter(context: context, room: room, currentUser: currentUser),
    );
  }

  static void enterRoom({
    required BuildContext context,
    required HomeRoom room,
    required CurrentUser? currentUser,
    String? lockPassword,
    LiveRoomEntryTransition entryTransition = LiveRoomEntryTransition.standard,
  }) {
    VmNavigator.openLiveRoom(
      context,
      roomName: room.name,
      roomId: room.id,
      language: room.language,
      modeTitle: room.mode,
      onlineCount: room.onlineCount,
      currentUser: currentUser,
      lockPassword: lockPassword,
      entryTransition: entryTransition,
    );
  }

  static Future<bool> _joinAndEnter({
    required BuildContext context,
    required HomeRoom room,
    required CurrentUser? currentUser,
    String? lockPassword,
  }) async {
    if (currentUser == null) {
      showToast(context, 'Login session not ready. Refresh and try again.');
      return false;
    }
    try {
      final snapshot = await const RoomApiService().joinRoom(
        room.id,
        lockPassword: lockPassword,
      );
      if (!context.mounted) return false;
      final joinedRoom = snapshot.room;
      enterRoom(
        context: context,
        room: HomeRoom(
          id: room.id,
          name: room.name,
          subtitle: room.subtitle,
          language: room.language,
          mode: joinedRoom.mode,
          type: room.type,
          onlineCount: joinedRoom.onlineCount,
          trendingScore: room.trendingScore,
          followedFriendsInside: room.followedFriendsInside,
          coverPhotoUrl: room.coverPhotoUrl,
        ),
        currentUser: currentUser,
        lockPassword: lockPassword,
      );
      return true;
    } catch (error) {
      if (!context.mounted) return false;
      final message = error.toString().replaceFirst('Exception: ', '');
      if (message.toLowerCase().contains('locked') &&
          (lockPassword == null || lockPassword.trim().isEmpty)) {
        openLockedRoomSheet(
          context: context,
          room: room,
          currentUser: currentUser,
        );
        return false;
      }
      showToast(context, _entryBlockedMessage(message));
      return false;
    }
  }

  static String _entryBlockedMessage(String backendMessage) {
    final normalized = backendMessage.toLowerCase();
    if (normalized.contains('kicked') || normalized.contains('blocked')) {
      return backendMessage
          .replaceFirst('You are currently', "You're currently")
          .replaceFirst('Take a breather', 'Take a breather')
          .trim();
    }
    if (normalized.contains('members-only') ||
        normalized.contains('members only')) {
      return 'Members Only room. Membership approval required.';
    }
    if (normalized.contains('secret')) {
      return 'This Secret Vibe room is private or invite-only.';
    }
    if (normalized.contains('incorrect') || normalized.contains('wrong')) {
      return 'Wrong password.';
    }
    return backendMessage;
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
        onSubmitPassword: (password) async {
          if (currentUser == null) {
            showToast(
              context,
              'Login session not ready. Refresh and try again.',
            );
            return false;
          }
          try {
            final snapshot = await const RoomApiService().joinRoom(
              room.id,
              lockPassword: password,
            );
            final joinedRoom = snapshot.room;
            Future<void>.delayed(const Duration(milliseconds: 120), () {
              if (!context.mounted) return;
              enterRoom(
                context: context,
                room: HomeRoom(
                  id: room.id,
                  name: room.name,
                  subtitle: room.subtitle,
                  language: room.language,
                  mode: joinedRoom.mode,
                  type: room.type,
                  onlineCount: joinedRoom.onlineCount,
                  trendingScore: room.trendingScore,
                  followedFriendsInside: room.followedFriendsInside,
                  coverPhotoUrl: room.coverPhotoUrl,
                ),
                currentUser: currentUser,
                lockPassword: password,
              );
            });
            return true;
          } catch (error) {
            if (context.mounted) {
              showToast(
                context,
                _entryBlockedMessage(
                  error.toString().replaceFirst('Exception: ', ''),
                ),
              );
            }
            return false;
          }
        },
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
        languages: controller.availableLanguages,
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