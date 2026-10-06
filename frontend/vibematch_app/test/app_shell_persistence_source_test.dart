import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppShell keeps persistent main branches without refresh nonces', () {
    final source = File('lib/app/app_shell.dart').readAsStringSync();

    expect(source, contains('_PersistentTabStage'));
    expect(source, contains("PageStorageKey<String>('main-home')"));
    expect(source, contains("PageStorageKey<String>('main-vibes')"));
    expect(source, contains("PageStorageKey<String>('main-inbox')"));
    expect(source, contains("PageStorageKey<String>('main-me')"));
    expect(source, isNot(contains('_homeRefreshNonce')));
    expect(source, isNot(contains('Timer.periodic')));
    expect(source, isNot(contains('PresenceApiService')));
    expect(source, isNot(contains('WalletRealtimeSyncService')));
  });
}
