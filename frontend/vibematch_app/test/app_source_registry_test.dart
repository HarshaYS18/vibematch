import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/app/app_source_registry.dart';

void main() {
  Map<String, dynamic> registryJson({
    String masterPath = AppSourceRegistry.canonicalMasterRead,
    String? profileMasterPath,
  }) {
    Map<String, dynamic> tab(String key, {String? masterRead}) =>
        <String, dynamic>{
          'tab_key': key,
          'master_read': masterRead ?? masterPath,
          'child_reads': <Map<String, dynamic>>[],
          'realtime_channels': <String>[],
        };

    return <String, dynamic>{
      'version': 2,
      'master_api': <String, dynamic>{
        'path': masterPath,
        'purpose': 'master',
      },
      'tabs': <Map<String, dynamic>>[
        tab('home'),
        tab('vibes'),
        tab('inbox'),
        tab('profile', masterRead: profileMasterPath),
      ],
    };
  }

  test('main shell registry accepts one canonical master read', () {
    final registry = AppSourceRegistry.fromJson(registryJson());

    expect(registry.version, 2);
    expect(
      registry.tabs.keys,
      containsAll(AppSourceRegistry.mainShellTabKeys),
    );
    expect(registry.validateMainShellContract, returnsNormally);
  });

  test('main shell registry rejects a split master source', () {
    final registry = AppSourceRegistry.fromJson(
      registryJson(profileMasterPath: '/users/me'),
    );

    expect(
      registry.validateMainShellContract,
      throwsA(isA<StateError>()),
    );
  });

  test('main shell registry rejects a noncanonical master API', () {
    final registry = AppSourceRegistry.fromJson(
      registryJson(masterPath: '/users/me'),
    );

    expect(
      registry.validateMainShellContract,
      throwsA(isA<StateError>()),
    );
  });
}
