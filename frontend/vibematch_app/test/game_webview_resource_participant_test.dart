import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/foundation/runtime/media_resource_lifecycle.dart';
import 'package:vibematch_app/game_platform/runtime/game_runtime.dart';
import 'package:vibematch_app/game_platform/runtime/game_webview_resource_participant.dart';

/// Chunk 34-M7 behavioral coverage for remote game WebView lifecycle.
void main() {
  test('exposes stable game WebView resource kind', () {
    final runtime = _FakeGameRuntime();
    final participant = GameWebViewResourceParticipant(
      resourceId: 'game:webview:demo',
      runtime: runtime,
    );

    expect(participant.resourceId, 'game:webview:demo');
    expect(participant.kind, MediaResourceKind.gameWebView);
  });

  test('foreground transitions are forwarded as host lifecycle events', () async {
    final runtime = _FakeGameRuntime();
    final participant = GameWebViewResourceParticipant(
      resourceId: 'game:webview:demo',
      runtime: runtime,
    );

    await participant.onForegroundChanged(false);
    await participant.onForegroundChanged(true);

    expect(runtime.events, <_HostEvent>[
      const _HostEvent('app.lifecycle', <String, dynamic>{'foreground': false}),
      const _HostEvent('app.lifecycle', <String, dynamic>{'foreground': true}),
    ]);
  });

  test('memory pressure is advisory and does not dispose active runtime', () async {
    final runtime = _FakeGameRuntime();
    final participant = GameWebViewResourceParticipant(
      resourceId: 'game:webview:demo',
      runtime: runtime,
    );

    await participant.onMemoryPressure();

    expect(
      runtime.events,
      <_HostEvent>[
        const _HostEvent('app.memory_pressure', <String, dynamic>{}),
      ],
    );
    expect(runtime.disposeCount, 0);
  });

  test('session release disposes once and makes later signals inert', () async {
    final runtime = _FakeGameRuntime();
    final participant = GameWebViewResourceParticipant(
      resourceId: 'game:webview:demo',
      runtime: runtime,
    );

    await participant.release();
    await participant.release();
    await participant.onForegroundChanged(false);
    await participant.onMemoryPressure();

    expect(runtime.disposeCount, 1);
    expect(runtime.events, isEmpty);
  });
}

class _FakeGameRuntime implements GameRuntime {
  final List<_HostEvent> events = <_HostEvent>[];
  int disposeCount = 0;

  @override
  Widget buildView({Key? key}) => const SizedBox.shrink();

  @override
  Future<void> sendHostEvent(
    String event, {
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) async {
    events.add(_HostEvent(event, Map<String, dynamic>.from(payload)));
  }

  @override
  Future<void> reload() async {}

  @override
  Future<void> dispose() async {
    disposeCount += 1;
  }
}

class _HostEvent {
  const _HostEvent(this.event, this.payload);

  final String event;
  final Map<String, dynamic> payload;

  @override
  bool operator ==(Object other) {
    return other is _HostEvent &&
        other.event == event &&
        _mapsEqual(other.payload, payload);
  }

  @override
  int get hashCode => Object.hash(event, payload.length);
}

bool _mapsEqual(Map<String, dynamic> a, Map<String, dynamic> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}
