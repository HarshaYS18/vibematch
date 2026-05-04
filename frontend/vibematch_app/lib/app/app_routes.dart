enum VmMainTab {
  home(
    tabIndex: 0,
    route: VmRoutes.home,
    label: 'Home',
  ),
  vibes(
    tabIndex: 1,
    route: VmRoutes.vibes,
    label: 'Vibes',
  ),
  create(
    tabIndex: 2,
    route: VmRoutes.create,
    label: 'Create',
  ),
  inbox(
    tabIndex: 3,
    route: VmRoutes.inbox,
    label: 'Inbox',
  ),
  me(
    tabIndex: 4,
    route: VmRoutes.me,
    label: 'Me',
  );

  const VmMainTab({
    required this.tabIndex,
    required this.route,
    required this.label,
  });

  final int tabIndex;
  final String route;
  final String label;

  static VmMainTab fromIndex(int index) {
    return VmMainTab.values.firstWhere(
      (tab) => tab.tabIndex == index,
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

  static const String profile = '/profile';
  static const String events = '/events';
  static const String rankings = '/rankings';
  static const String wallet = '/wallet';
  static const String store = '/store';
  static const String settings = '/settings';

  static const String family = '/family';
  static const String loveBond = '/love-bond';
  static const String vip = '/vip';
  static const String notifications = '/notifications';
  static const String search = '/search';
  static const String controlCenter = '/control-center';
  static const String bannerManager = '/banner-manager';

  static const String agency = '/agency';
  static const String gifts = '/gifts';
  static const String inventory = '/inventory';
  static const String recharge = '/recharge';
  static const String transactions = '/transactions';
  static const String earnings = '/earnings';
  static const String payouts = '/payouts';

  static const String admin = '/admin';
  static const String reports = '/reports';
  static const String privacy = '/privacy';
  static const String blockList = '/block-list';
  static const String security = '/security';
  static const String language = '/language';

  static const String games = '/games';
  static const String watchParty = '/watch-party';
  static const String cricketMode = '/cricket-mode';
  static const String vibeSync = '/vibesync';

  static const String vibeDetail = '/vibes/detail';
  static const String vibeComposer = '/vibes/composer';
  static const String vibeComments = '/vibes/comments';

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
