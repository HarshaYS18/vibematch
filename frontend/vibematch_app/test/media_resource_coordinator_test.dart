import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/app/runtime/media_resource_coordinator.dart';
import 'package:vibematch_app/foundation/runtime/media_resource_budget.dart';

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

    expect(coordinator.register(first), isTrue);
    expect(coordinator.register(first), isFalse);

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

  test('M14 budget policy covers every resource kind', () {
    for (final kind in MediaResourceKind.values) {
      expect(
        MediaResourceBudgetPolicy.forKind(kind).recommendedMaxActive,
        greaterThan(0),
      );
    }
  });

  test('M14 pressure reclaims speculative work before realtime media', () async {
    final order = <String>[];
    final coordinator = MediaResourceCoordinator()
      ..register(
        _FakeResource(
          resourceId: 'room:critical',
          kind: MediaResourceKind.roomWebRtc,
          onPressure: () => order.add('room'),
        ),
      )
      ..register(
        _FakeResource(
          resourceId: 'prefetch:reclaim',
          kind: MediaResourceKind.imagePrefetch,
          onPressure: () => order.add('prefetch'),
        ),
      );

    await coordinator.handleMemoryPressure();

    expect(order, <String>['prefetch', 'room']);
  });

  test('M14 participant failures do not block healthy cleanup', () async {
    final healthy = _FakeResource(
      resourceId: 'healthy',
      kind: MediaResourceKind.gameBundleCache,
    );
    final coordinator = MediaResourceCoordinator()
      ..register(
        _FakeResource(
          resourceId: 'failing',
          kind: MediaResourceKind.giftVideo,
          throwOnPressure: true,
          throwOnRelease: true,
        ),
      )
      ..register(healthy);

    await coordinator.handleMemoryPressure();
    await coordinator.dispose();

    expect(healthy.memoryPressureCount, 1);
    expect(healthy.releaseCount, 1);
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
    this.onPressure,
    this.throwOnPressure = false,
    this.throwOnRelease = false,
  });

  @override
  final String resourceId;

  @override
  final MediaResourceKind kind;

  final List<bool> foregroundTransitions = <bool>[];
  final void Function()? onPressure;
  final bool throwOnPressure;
  final bool throwOnRelease;
  int memoryPressureCount = 0;
  int releaseCount = 0;

  @override
  Future<void> onForegroundChanged(bool isForeground) async {
    foregroundTransitions.add(isForeground);
  }

  @override
  Future<void> onMemoryPressure() async {
    memoryPressureCount += 1;
    onPressure?.call();
    if (throwOnPressure) throw StateError('pressure failure');
  }

  @override
  Future<void> release() async {
    releaseCount += 1;
    if (throwOnRelease) throw StateError('release failure');
  }
}
