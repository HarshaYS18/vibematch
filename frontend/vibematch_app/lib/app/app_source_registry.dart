class AppSourceEndpoint {
  const AppSourceEndpoint({
    required this.path,
    required this.purpose,
  });

  final String path;
  final String purpose;

  factory AppSourceEndpoint.fromJson(Map<String, dynamic> json) {
    return AppSourceEndpoint(
      path: json['path']?.toString().trim() ?? '',
      purpose: json['purpose']?.toString().trim() ?? '',
    );
  }
}

class AppTabSourceRegistry {
  const AppTabSourceRegistry({
    required this.tabKey,
    required this.masterRead,
    required this.childReads,
    required this.realtimeChannels,
  });

  final String tabKey;
  final String masterRead;
  final List<AppSourceEndpoint> childReads;
  final List<String> realtimeChannels;

  factory AppTabSourceRegistry.fromJson(Map<String, dynamic> json) {
    final rawReads = json['child_reads'];
    final rawRealtime = json['realtime_channels'];
    return AppTabSourceRegistry(
      tabKey: json['tab_key']?.toString().trim() ?? '',
      masterRead: json['master_read']?.toString().trim() ?? '',
      childReads: rawReads is List
          ? rawReads
                .whereType<Map>()
                .map(
                  (item) => AppSourceEndpoint.fromJson(
                    item.cast<String, dynamic>(),
                  ),
                )
                .toList(growable: false)
          : const <AppSourceEndpoint>[],
      realtimeChannels: rawRealtime is List
          ? rawRealtime
                .map((item) => item.toString().trim())
                .where((item) => item.isNotEmpty)
                .toList(growable: false)
          : const <String>[],
    );
  }
}

class AppSourceRegistry {
  const AppSourceRegistry({
    required this.version,
    required this.masterApiPath,
    required this.tabs,
  });

  static const String canonicalMasterRead = '/users/me/master-state';
  static const Set<String> mainShellTabKeys = <String>{
    'home',
    'vibes',
    'inbox',
    'profile',
  };

  final int version;
  final String masterApiPath;
  final Map<String, AppTabSourceRegistry> tabs;

  factory AppSourceRegistry.fromJson(Map<String, dynamic> json) {
    final masterApi = json['master_api'];
    final rawTabs = json['tabs'];
    final parsedTabs = <String, AppTabSourceRegistry>{};

    if (rawTabs is List) {
      for (final rawTab in rawTabs.whereType<Map>()) {
        final tab = AppTabSourceRegistry.fromJson(
          rawTab.cast<String, dynamic>(),
        );
        if (tab.tabKey.isNotEmpty) {
          parsedTabs[tab.tabKey] = tab;
        }
      }
    }

    return AppSourceRegistry(
      version: _int(json['version']),
      masterApiPath: masterApi is Map
          ? masterApi['path']?.toString().trim() ?? ''
          : '',
      tabs: Map<String, AppTabSourceRegistry>.unmodifiable(parsedTabs),
    );
  }

  void validateMainShellContract() {
    if (masterApiPath != canonicalMasterRead) {
      throw StateError(
        'App source registry master API must be $canonicalMasterRead, '
        'got $masterApiPath.',
      );
    }

    for (final tabKey in mainShellTabKeys) {
      final tab = tabs[tabKey];
      if (tab == null) {
        throw StateError('App source registry is missing main tab: $tabKey.');
      }
      if (tab.masterRead != canonicalMasterRead) {
        throw StateError(
          'Main tab $tabKey must read master state from '
          '$canonicalMasterRead, got ${tab.masterRead}.',
        );
      }
    }
  }
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
