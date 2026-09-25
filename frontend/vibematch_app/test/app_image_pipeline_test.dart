import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/foundation/images/app_image.dart';
import 'package:vibematch_app/foundation/images/app_image_prefetch.dart';
import 'package:vibematch_app/foundation/runtime/media_resource_lifecycle.dart';

void main() {
  testWidgets('decode policy scales logical pixels and caps giant images', (
    tester,
  ) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 3),
          child: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(AppImageDecodePolicy.pixelDimension(captured, 40), 120);
    expect(
      AppImageDecodePolicy.pixelDimension(captured, 5000),
      AppImageDecodePolicy.maxDecodeDimension,
    );
  });

  test('prefetch queue is bounded and has dedicated resource kind', () {
    final queue = AppImagePrefetchQueue();
    expect(queue.kind, MediaResourceKind.imagePrefetch);
    expect(queue.resourceId, 'image-prefetch:session');
    expect(queue.maxConcurrent, 2);
    expect(queue.maxQueued, 12);
  });

  testWidgets('invalid network prefetch is ignored without queueing', (
    tester,
  ) async {
    final queue = AppImagePrefetchQueue();
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    await queue.prefetchNetwork(captured, 'not-a-network-url');

    expect(queue.queuedCount, 0);
    expect(queue.activeCount, 0);
  });
}
