class AppSourceTruthRegistry {
  const AppSourceTruthRegistry({
    required this.version,
    required this.masterApi,
    required this.rules,
    required this.tabs,
    required this.deferredWork,
  });

  final int version;
  final SourceEndpoint masterApi;
  final Map<String, dynamic> rules;
  final List<AppSourceTruthTab> tabs;
  final List<String> deferredWork;

  factory AppSourceTruthRegistry.fromJson(Map<String, dynamic> json) {
    return AppSourceTruthRegistry(
      version: _int(json['version']),
      masterApi: SourceEndpoint.fromJson(_map(json['master_api'])),
      rules: _map(json['rules']),
      tabs: _list(json['tabs'])
          .map((item) => AppSourceTruthTab.fromJson(_map(item)))
          .toList(growable: false),
      deferredWork: _stringList(json['deferred_work']),
    );
  }
}

class AppSourceTruthTab {
  const AppSourceTruthTab({
    required this.tabKey,
    required this.label,
    required this.masterRead,
    required this.canonicalOwner,
    required this.childReads,
    required this.childWrites,
    required this.configSources,
    required this.controlCenterModules,
    required this.realtimeChannels,
    required this.protectedFlows,
    required this.duplicateSourcesToRetire,
    required this.migrationStatus,
  });

  final String tabKey;
  final String label;
  final String masterRead;
  final String canonicalOwner;
  final List<SourceEndpoint> childReads;
  final List<SourceEndpoint> childWrites;
  final List<SourceEndpoint> configSources;
  final List<String> controlCenterModules;
  final List<String> realtimeChannels;
  final List<String> protectedFlows;
  final List<String> duplicateSourcesToRetire;
  final String migrationStatus;

  factory AppSourceTruthTab.fromJson(Map<String, dynamic> json) {
    return AppSourceTruthTab(
      tabKey: _text(json['tab_key']) ?? '',
      label: _text(json['label']) ?? '',
      masterRead: _text(json['master_read']) ?? '',
      canonicalOwner: _text(json['canonical_owner']) ?? 'backend',
      childReads: _endpoints(json['child_reads']),
      childWrites: _endpoints(json['child_writes']),
      configSources: _endpoints(json['config_sources']),
      controlCenterModules: _stringList(json['control_center_modules']),
      realtimeChannels: _stringList(json['realtime_channels']),
      protectedFlows: _stringList(json['protected_flows']),
      duplicateSourcesToRetire: _stringList(
        json['duplicate_sources_to_retire'],
      ),
      migrationStatus: _text(json['migration_status']) ?? 'foundation',
    );
  }
}

class SourceEndpoint {
  const SourceEndpoint({
    required this.path,
    required this.purpose,
    required this.owner,
    required this.realtimeSafe,
  });

  final String path;
  final String purpose;
  final String owner;
  final bool realtimeSafe;

  factory SourceEndpoint.fromJson(Map<String, dynamic> json) {
    return SourceEndpoint(
      path: _text(json['path']) ?? '',
      purpose: _text(json['purpose']) ?? '',
      owner: _text(json['owner']) ?? 'backend',
      realtimeSafe: json['realtime_safe'] != false,
    );
  }
}

List<SourceEndpoint> _endpoints(Object? value) {
  return _list(
    value,
  ).map((item) => SourceEndpoint.fromJson(_map(item))).toList(growable: false);
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return const <String, dynamic>{};
}

List<dynamic> _list(Object? value) {
  if (value is List) return value;
  return const <dynamic>[];
}

List<String> _stringList(Object? value) {
  return _list(value)
      .map((item) => item.toString())
      .where((item) => item.trim().isNotEmpty)
      .toList(growable: false);
}

String? _text(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty || text == 'null') return null;
  return text;
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
