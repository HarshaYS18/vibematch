import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../runtime/media_resource_lifecycle.dart';
import 'app_image.dart';

/// Bounded speculative image prefetch work for one authenticated UI subtree.
class AppImagePrefetchQueue implements MediaResourceParticipant {
  AppImagePrefetchQueue({
    this.maxConcurrent = 2,
    this.maxQueued = 12,
  });

  final int maxConcurrent;
  final int maxQueued;

  final Queue<_PrefetchRequest> _pending = Queue<_PrefetchRequest>();
  final Set<String> _keys = <String>{};

  int _activeCount = 0;
  int _generation = 0;
  bool _foreground = true;
  bool _released = false;

  int get queuedCount => _pending.length;
  int get activeCount => _activeCount;

  @override
  String get resourceId => 'image-prefetch:session';

  @override
  MediaResourceKind get kind => MediaResourceKind.imagePrefetch;

  Future<void> prefetchNetwork(
    BuildContext context,
    String rawUrl, {
    double? logicalWidth,
    double? logicalHeight,
  }) {
    final url = rawUrl.trim();
    final uri = Uri.tryParse(url);
    if (_released ||
        !_foreground ||
        !context.mounted ||
        uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return Future<void>.value();
    }

    final cacheWidth = AppImageDecodePolicy.pixelDimension(
      context,
      logicalWidth,
    );
    final cacheHeight = AppImageDecodePolicy.pixelDimension(
      context,
      logicalHeight,
    );
    ImageProvider<Object> provider = NetworkImage(url);
    provider = ResizeImage.resizeIfNeeded(cacheWidth, cacheHeight, provider);

    final key = '$url|${cacheWidth ?? 0}x${cacheHeight ?? 0}';
    if (_keys.contains(key) || _pending.length >= maxQueued) {
      return Future<void>.value();
    }

    final completer = Completer<void>();
    _keys.add(key);
    _pending.add(
      _PrefetchRequest(
        key: key,
        provider: provider,
        context: context,
        generation: _generation,
        completer: completer,
      ),
    );
    _drain();
    return completer.future;
  }

  @override
  Future<void> onForegroundChanged(bool isForeground) async {
    if (_released) return;
    _foreground = isForeground;
    if (!isForeground) _invalidateQueuedWork();
  }

  @override
  Future<void> onMemoryPressure() async {
    if (_released) return;
    _invalidateQueuedWork();
  }

  @override
  Future<void> release() async {
    if (_released) return;
    _released = true;
    _foreground = false;
    _invalidateQueuedWork();
  }

  void _invalidateQueuedWork() {
    _generation += 1;
    while (_pending.isNotEmpty) {
      final request = _pending.removeFirst();
      _keys.remove(request.key);
      if (!request.completer.isCompleted) request.completer.complete();
    }
  }

  void _drain() {
    while (!_released &&
        _foreground &&
        _activeCount < maxConcurrent &&
        _pending.isNotEmpty) {
      final request = _pending.removeFirst();
      _activeCount += 1;
      unawaited(_run(request));
    }
  }

  Future<void> _run(_PrefetchRequest request) async {
    try {
      if (request.context.mounted &&
          request.generation == _generation &&
          !_released &&
          _foreground) {
        await precacheImage(
          request.provider,
          request.context,
          onError: (Object _, StackTrace? __) {},
        );
      }

      if (_released ||
          !_foreground ||
          request.generation != _generation) {
        await request.provider.evict();
      }
    } catch (_) {
      // Prefetch is best effort and never blocks visible image loading.
    } finally {
      _activeCount -= 1;
      _keys.remove(request.key);
      if (!request.completer.isCompleted) request.completer.complete();
      _drain();
    }
  }
}

class _PrefetchRequest {
  const _PrefetchRequest({
    required this.key,
    required this.provider,
    required this.context,
    required this.generation,
    required this.completer,
  });

  final String key;
  final ImageProvider<Object> provider;
  final BuildContext context;
  final int generation;
  final Completer<void> completer;
}

/// Lazy session/subtree queue. Inside AppShell this sees the overridden
/// MediaResourceRegistry and registers itself as imagePrefetch.
final appImagePrefetchQueueProvider = Provider<AppImagePrefetchQueue>((ref) {
  final queue = AppImagePrefetchQueue();
  final registry = ref.watch(mediaResourceRegistryProvider);
  if (registry != null) {
    registry.register(queue);
  }

  ref.onDispose(() {
    registry?.unregister(
      queue.resourceId,
      expectedParticipant: queue,
    );
    unawaited(queue.release());
  });
  return queue;
});
