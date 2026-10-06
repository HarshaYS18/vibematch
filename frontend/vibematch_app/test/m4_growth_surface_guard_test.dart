import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native shells register FunKey growth links without duplicate Flutter handling', () {
    final android = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final ios = File('ios/Runner/Info.plist').readAsStringSync();

    expect(android.contains('android:scheme="funkey"'), isTrue);
    expect(android.contains('flutter_deeplinking_enabled'), isTrue);
    expect(ios.contains('<string>funkey</string>'), isTrue);
    expect(ios.contains('<key>FlutterDeepLinkingEnabled</key>'), isTrue);
  });

  test('existing profile share affordance is backed by growth sharing', () {
    final source = File(
      'lib/features/profile/presentation/public_profile_view_page.dart',
    ).readAsStringSync();

    expect(source.contains('Profile share sheet will open.'), isFalse);
    expect(source.contains('VmGrowthCoordinator.instance.shareText'), isTrue);
    expect(source.contains('VmGrowthLinks.profile'), isTrue);
  });

  test('M4 does not add new visible share controls to unrelated surfaces', () {
    final files = <String>[
      'lib/features/home/presentation/home_page_modular.dart',
      'lib/features/games/presentation/games_page.dart',
      'lib/features/events/presentation/events_page.dart',
      'lib/features/family/presentation/family_modular_page.dart',
    ];

    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(
        source.contains('Icons.share_rounded'),
        isFalse,
        reason: '$path added a new visible share control during UI-stable M4.',
      );
    }
  });
}
