import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/foundation/images/app_image.dart';

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

}
