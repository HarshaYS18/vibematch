import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('room game entry launches the remote GameRuntime path', () {
    final actions = File(
      'lib/features/rooms/presentation/modules/live_room_games_actions_module.dart',
    ).readAsStringSync();

    expect(actions, contains('RemoteGamePlayerPage'));
    expect(actions, isNot(contains('JungleHuntGlobalGamePage')));
    expect(actions, isNot(contains('JungleHuntGamePage')));
  });

  test('game platform owns the only game WebView controller access', () {
    final root = Directory('lib/game_platform');
    final dartFiles = root
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in dartFiles) {
      final source = file.readAsStringSync();
      if (source.contains('InAppWebViewController') ||
          source.contains(
            'package:flutter_inappwebview/flutter_inappwebview.dart',
          )) {
        expect(
          file.path.replaceAll('\\', '/'),
          endsWith(
            'lib/game_platform/runtime/web/in_app_webview_game_runtime.dart',
          ),
        );
      }
      expect(source, isNot(contains('WebSocketChannel')));
      expect(source, isNot(contains('WebSocket.connect')));
    }
  });

  test('Flutter no longer bundles gameplay assets', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('assets/games/')));
    expect(pubspec, isNot(contains('games_raw/')));
  });

  test('remote runtime does not receive the app access token', () {
    final runtime = File(
      'lib/game_platform/runtime/web/in_app_webview_game_runtime.dart',
    ).readAsStringSync();

    expect(runtime, isNot(contains('accessToken')));
    expect(runtime, isNot(contains('Authorization')));
  });
}
