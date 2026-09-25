import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/app/runtime/media_resource_coordinator.dart';

/// Chunk 34-M1 contract tests.
///
/// These tests intentionally exercise lifecycle coordination only. Feature
/// resources remain authoritative for their own playback/media/domain state.
void main() {
  test('registration is idempotent for the same participant and rejects id reuse', () {
    final coordinator = MediaResourceCoordinator();
    final first = _FakeResource(
      resourceId: 'vibes:feed',
      kind: MediaResourceKind.vibesVideoDecoder,
    );
    final duplicateId = _FakeResource(
      resourceId: 'vibes:feed',
      kind: MediaResourceKind.vibesVideoDecoder,
    );

    coordinator.register(first);
    coordinator.register(first);

    expect(coordinator.registeredResourceCount, 1);
    expect(
      coordinator.registeredKinds,
      <MediaResourceKind>{MediaResourceKind.vibesVideoDecoder},
    );
    expect(() => coordinator.register(duplicateId), throwsStateError);
  });

  test('foreground transitions and memory pressure fan out deterministically', () async {
    final coordinator = MediaResourceCoordinator();
    final video = _FakeResource(
      resourceId: 'vibes:active',
      kind: MediaResourceKind.vibesVideoDecoder,
    );
    final game = _FakeResource(
      resourceId: 'game:room-1',
      kind: MediaResourceKind.gameWebView,
    );
    coordinator
      ..register(video)
      ..register(game);

    await coordinator.setForeground(false);
    await coordinator.setForeground(false);
    await coordinator.handleMemoryPressure();
    await coordinator.setForeground(true);

    expect(video.foregroundTransitions, <bool>[false, true]);
    expect(game.foregroundTransitions, <bool>[false, true]);
    expect(video.memoryPressureCount, 1);
    expect(game.memoryPressureCount, 1);
  });

  test('stale unregister cannot remove a replacement resource', () {
    final coordinator = MediaResourceCoordinator();
    final original = _FakeResource(
      resourceId: 'watch:webview',
      kind: MediaResourceKind.watchPartyWebView,
    );
    final replacement = _FakeResource(
      resourceId: 'watch:webview-next',
      kind: MediaResourceKind.watchPartyWebView,
    );

    coordinator.register(original);
    expect(
      coordinator.unregister(
        original.resourceId,
        expectedParticipant: replacement,
      ),
      isFalse,
    );
    expect(coordinator.registeredResourceCount, 1);
    expect(
      coordinator.unregister(
        original.resourceId,
        expectedParticipant: original,
      ),
      isTrue,
    );
    expect(coordinator.registeredResourceCount, 0);
  });

  test('dispose releases registered resources once and is terminal', () async {
    final coordinator = MediaResourceCoordinator();
    final room = _FakeResource(
      resourceId: 'room:media',
      kind: MediaResourceKind.roomWebRtc,
    );
    final gift = _FakeResource(
      resourceId: 'gift:video',
      kind: MediaResourceKind.giftVideo,
    );
    coordinator
      ..register(room)
      ..register(gift);

    await coordinator.dispose();
    await coordinator.dispose();

    expect(room.releaseCount, 1);
    expect(gift.releaseCount, 1);
    expect(coordinator.registeredResourceCount, 0);
    expect(coordinator.isDisposed, isTrue);
    expect(() => coordinator.register(room), throwsStateError);
    await expectLater(coordinator.handleMemoryPressure(), throwsStateError);
  });

  test('coordinator provider remains auto-disposed and non-global by source guard', () {
    final source = File(
      'lib/app/runtime/media_resource_coordinator.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('Provider.autoDispose<MediaResourceCoordinator>'),
    );
    expect(source, isNot(contains('MediaResourceCoordinator.instance')));
    expect(source, isNot(contains('static final MediaResourceCoordinator')));
  });
}

class _FakeResource implements MediaResourceParticipant {
  _FakeResource({
    required this.resourceId,
    required this.kind,
  });

  @override
  final String resourceId;

  @override
  final MediaResourceKind kind;

  final List<bool> foregroundTransitions = <bool>[];
  int memoryPressureCount = 0;
  int releaseCount = 0;

  @override
  Future<void> onForegroundChanged(bool isForeground) async {
    foregroundTransitions.add(isForeground);
  }

  @override
  Future<void> onMemoryPressure() async {
    memoryPressureCount += 1;
  }

  @override
  Future<void> release() async {
    releaseCount += 1;
  }
}
