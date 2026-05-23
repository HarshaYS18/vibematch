import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../features/auth/models/current_user.dart';

class VmNavigator {
  const VmNavigator._();

  static Future<T?> openLiveRoom<T>(
    BuildContext context, {
    required String roomName,
    required String roomId,
    required String language,
    required String modeTitle,
    required int onlineCount,
    CurrentUser? currentUser,
    String? lockPassword,
    LiveRoomEntryTransition entryTransition = LiveRoomEntryTransition.standard,
  }) {
    return Navigator.pushNamed<T>(
      context,
      VmRoutes.liveRoom,
      arguments: LiveRoomRouteArgs(
        roomName: roomName,
        roomId: roomId,
        language: language,
        modeTitle: modeTitle,
        onlineCount: onlineCount,
        currentUser: currentUser,
        lockPassword: lockPassword,
        entryTransition: entryTransition,
      ),
    );
  }

  static Future<T?> openPublicProfile<T>(
    BuildContext context, {
    required String userId,
    required String displayName,
    String? username,
  }) {
    return Navigator.pushNamed<T>(
      context,
      VmRoutes.profile,
      arguments: PublicProfileRouteArgs(
        userId: userId,
        displayName: displayName,
        username: username,
      ),
    );
  }

  static Future<T?> openEvents<T>(BuildContext context) {
    return Navigator.pushNamed<T>(context, VmRoutes.events);
  }

  static Future<T?> openRankings<T>(BuildContext context) {
    return Navigator.pushNamed<T>(context, VmRoutes.rankings);
  }

  static Future<T?> openWallet<T>(BuildContext context) {
    return Navigator.pushNamed<T>(context, VmRoutes.wallet);
  }

  static Future<T?> openStore<T>(BuildContext context) {
    return Navigator.pushNamed<T>(context, VmRoutes.store);
  }

  static Future<T?> openSettings<T>(BuildContext context) {
    return Navigator.pushNamed<T>(context, VmRoutes.settings);
  }

  static Future<T?> openFamily<T>(BuildContext context) {
    return Navigator.pushNamed<T>(context, VmRoutes.family);
  }

  static Future<T?> openLoveBond<T>(BuildContext context) {
    return Navigator.pushNamed<T>(context, VmRoutes.loveBond);
  }

  static Future<T?> openVip<T>(BuildContext context) {
    return Navigator.pushNamed<T>(context, VmRoutes.vip);
  }

  static Future<T?> openNotifications<T>(BuildContext context) {
    return Navigator.pushNamed<T>(context, VmRoutes.notifications);
  }

  static Future<T?> openSearch<T>(BuildContext context) {
    return Navigator.pushNamed<T>(context, VmRoutes.search);
  }

  static Future<T?> openControlCenter<T>(BuildContext context) {
    return Navigator.pushNamed<T>(context, VmRoutes.controlCenter);
  }

  static Future<T?> openBannerManager<T>(BuildContext context) {
    return Navigator.pushNamed<T>(context, VmRoutes.bannerManager);
  }
}