import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../foundation/runtime/media_resource_lifecycle.dart';

export '../../foundation/runtime/media_resource_lifecycle.dart';

/// Session-scoped coordinator for heavyweight Flutter runtime resources.
///
/// This is deliberately not a domain-state store and never decides room,
/// Watch Party, game, gift, or playback truth. It only coordinates lifecycle
/// signals across resources registered by their owning feature.
///
/// The coordinator is created by [mediaResourceCoordinatorProvider], which is
/// auto-disposed with the authenticated AppShell/session. No process-global
/// singleton is allowed.
class MediaResourceCoordinator implements MediaResourceRegistry {
  final Map<String, MediaResourceParticipant> _participants =
      <String, MediaResourceParticipant>{};

  bool _isForeground = true;
  bool _disposed = false;

  bool get isForeground => _isForeground;
  bool get isDisposed => _disposed;
  int get registeredResourceCount => _participants.length;

  Set<MediaResourceKind> get registeredKinds => Set<MediaResourceKind>.unmodifiable(
        _participants.values.map((participant) => participant.kind),
      );

  /// Registers one feature-owned resource adapter.
  ///
  /// Re-registering the same object is idempotent and returns false. A new
  /// registration returns true. Reusing an id for a different participant is
  /// rejected so two heavy resources cannot silently share one lifecycle
  /// identity.
  bool register(MediaResourceParticipant participant) {
    _ensureOpen();
    final id = participant.resourceId.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(
        participant.resourceId,
        'participant.resourceId',
        'Resource id must not be empty.',
      );
    }

    final existing = _participants[id];
    if (existing != null && !identical(existing, participant)) {
      throw StateError('Media resource id already registered: $id');
    }
    if (identical(existing, participant)) return false;
    _participants[id] = participant;
    return true;
  }

  /// Removes a registration without disposing the feature-owned resource.
  ///
  /// [expectedParticipant] protects against a stale widget unregistering a
  /// newer participant that reused the same stable id after remount.
  bool unregister(
    String resourceId, {
    MediaResourceParticipant? expectedParticipant,
  }) {
    if (_disposed) return false;
    final id = resourceId.trim();
    final current = _participants[id];
    if (current == null) return false;
    if (expectedParticipant != null &&
        !identical(current, expectedParticipant)) {
      return false;
    }
    _participants.remove(id);
    return true;
  }

  /// Broadcasts foreground/background transitions once per actual transition.
  Future<void> setForeground(bool isForeground) async {
    _ensureOpen();
    if (_isForeground == isForeground) return;
    _isForeground = isForeground;
    await _broadcast(
      (participant) => participant.onForegroundChanged(isForeground),
    );
  }

  /// Asks every currently registered heavy resource to trim warm/reconstructable
  /// memory without changing any canonical domain state.
  Future<void> handleMemoryPressure() async {
    _ensureOpen();
    await _broadcast((participant) => participant.onMemoryPressure());
  }

  /// Releases every resource still registered when the authenticated runtime
  /// ends. This is terminal and idempotent.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final participants = List<MediaResourceParticipant>.of(
      _participants.values,
      growable: false,
    );
    _participants.clear();
    await Future.wait<void>(
      participants.map((participant) async {
        await participant.release();
      }),
    );
  }

  Future<void> _broadcast(
    Future<void> Function(MediaResourceParticipant participant) operation,
  ) async {
    final participants = List<MediaResourceParticipant>.of(
      _participants.values,
      growable: false,
    );
    await Future.wait<void>(
      participants.map((participant) => operation(participant)),
    );
  }

  void _ensureOpen() {
    if (_disposed) {
      throw StateError('MediaResourceCoordinator has been disposed.');
    }
  }
}

/// Authenticated-session resource runtime.
///
/// AppShell will keep this provider alive while signed in. Auto-dispose ensures
/// no heavy-resource registry leaks across logout/session replacement.
final mediaResourceCoordinatorProvider =
    Provider.autoDispose<MediaResourceCoordinator>((ref) {
      final coordinator = MediaResourceCoordinator();
      ref.onDispose(() => unawaited(coordinator.dispose()));
      return coordinator;
    });
