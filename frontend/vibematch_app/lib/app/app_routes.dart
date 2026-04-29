enum VmMainTab {
  home(
    index: 0,
    route: VmRoutes.home,
    label: 'Home',
  ),
  vibes(
    index: 1,
    route: VmRoutes.vibes,
    label: 'Vibes',
  ),
  create(
    index: 2,
    route: VmRoutes.create,
    label: 'Create',
  ),
  inbox(
    index: 3,
    route: VmRoutes.inbox,
    label: 'Inbox',
  ),
  me(
    index: 4,
    route: VmRoutes.me,
    label: 'Me',
  );

  const VmMainTab({
    required this.index,
    required this.route,
    required this.label,
  });

  final int index;
  final String route;
  final String label;

  static VmMainTab fromIndex(int index) {
    return VmMainTab.values.firstWhere(
      (tab) => tab.index == index,
      orElse: () => VmMainTab.home,
    );
  }

  static VmMainTab fromRoute(String? route) {
    return VmMainTab.values.firstWhere(
      (tab) => tab.route == route,
      orElse: () => VmMainTab.home,
    );
  }
}

class VmRoutes {
  const VmRoutes._();

  static const String auth = '/';

  static const String home = '/home';
  static const String vibes = '/vibes';
  static const String create = '/create';
  static const String inbox = '/inbox';
  static const String me = '/me';

  static const String liveRoom = '/rooms/live';
  static const String roomPreview = '/rooms/preview';

  static const String profile = '/profile';
  static const String events = '/events';
  static const String rankings = '/rankings';
  static const String wallet = '/wallet';
  static const String store = '/store';
  static const String settings = '/settings';

  static const String family = '/family';
  static const String vip = '/vip';
  static const String notifications = '/notifications';
  static const String search = '/search';
  static const String controlCenter = '/control-center';

  static bool isMainTabRoute(String? route) {
    if (route == null) return false;
    return VmMainTab.values.any((tab) => tab.route == route);
  }
}

class LiveRoomRouteArgs {
  final String roomName;
  final String roomId;
  final String language;
  final String modeTitle;
  final int onlineCount;

  const LiveRoomRouteArgs({
    required this.roomName,
    required this.roomId,
    required this.language,
    required this.modeTitle,
    required this.onlineCount,
  });
}

class RoomPreviewRouteArgs {
  final String roomName;
  final String roomId;
  final String language;
  final String modeTitle;
  final int onlineCount;

  const RoomPreviewRouteArgs({
    required this.roomName,
    required this.roomId,
    required this.language,
    required this.modeTitle,
    required this.onlineCount,
  });
}

class PublicProfileRouteArgs {
  final String userId;
  final String displayName;
  final String? username;

  const PublicProfileRouteArgs({
    required this.userId,
    required this.displayName,
    this.username,
  });
}
