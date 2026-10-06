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

  test('room registry accepts only canonical Chunk 5 lifecycle paths', () {
    final registry = AppSourceRegistry.fromJson(<String, dynamic>{
      'version': 3,
      'master_api': <String, dynamic>{
        'path': AppSourceRegistry.canonicalMasterRead,
        'purpose': 'master',
      },
      'tabs': <Map<String, dynamic>>[
        <String, dynamic>{
          'tab_key': 'rooms',
          'master_read': AppSourceRegistry.canonicalMasterRead,
          'child_reads': <Map<String, dynamic>>[
            <String, dynamic>{
              'path': AppSourceRegistry.canonicalRoomSnapshot,
              'purpose': 'snapshot',
            },
          ],
          'child_writes': AppSourceRegistry.canonicalRoomLifecycleWrites
              .map(
                (path) => <String, dynamic>{
                  'path': path,
                  'purpose': 'lifecycle',
                },
              )
              .toList(),
          'realtime_channels': <String>[
            AppSourceRegistry.canonicalRoomRealtimeChannel,
          ],
        },
      ],
    });

    expect(registry.validateRoomSessionContract, returnsNormally);
  });


  test('Chunk 7 registry requires canonical Watch Party command at v4', () {
    final writes = <String>{
      ...AppSourceRegistry.canonicalRoomLifecycleWrites,
      AppSourceRegistry.canonicalWatchPartyCommand,
    };
    final registry = AppSourceRegistry.fromJson(<String, dynamic>{
      'version': 4,
      'master_api': <String, dynamic>{
        'path': AppSourceRegistry.canonicalMasterRead,
        'purpose': 'master',
      },
      'tabs': <Map<String, dynamic>>[
        <String, dynamic>{
          'tab_key': 'rooms',
          'master_read': AppSourceRegistry.canonicalMasterRead,
          'child_reads': <Map<String, dynamic>>[
            <String, dynamic>{
              'path': AppSourceRegistry.canonicalRoomSnapshot,
              'purpose': 'snapshot',
            },
          ],
          'child_writes': writes
              .map(
                (path) => <String, dynamic>{
                  'path': path,
                  'purpose': 'canonical room command',
                },
              )
              .toList(),
          'realtime_channels': <String>[
            AppSourceRegistry.canonicalRoomRealtimeChannel,
          ],
        },
      ],
    });

    expect(registry.validateRoomSessionContract, returnsNormally);
  });

  test('room registry rejects legacy lifecycle endpoints', () {
    final registry = AppSourceRegistry.fromJson(<String, dynamic>{
      'version': 3,
      'master_api': <String, dynamic>{
        'path': AppSourceRegistry.canonicalMasterRead,
        'purpose': 'master',
      },
      'tabs': <Map<String, dynamic>>[
        <String, dynamic>{
          'tab_key': 'rooms',
          'master_read': AppSourceRegistry.canonicalMasterRead,
          'child_reads': <Map<String, dynamic>>[
            <String, dynamic>{
              'path': AppSourceRegistry.canonicalRoomSnapshot,
              'purpose': 'snapshot',
            },
          ],
          'child_writes': <Map<String, dynamic>>[
            <String, dynamic>{
              'path': '/rooms/{room_public_id}/join',
              'purpose': 'legacy join',
            },
          ],
          'realtime_channels': <String>[
            AppSourceRegistry.canonicalRoomRealtimeChannel,
          ],
        },
      ],
    });

    expect(
      registry.validateRoomSessionContract,
      throwsA(isA<StateError>()),
    );
  });

}
