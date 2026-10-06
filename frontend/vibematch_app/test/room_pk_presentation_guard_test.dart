import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PK keeps FunKey room shell and uses transient presentation surfaces', () {
    final modes = File(
      'lib/features/rooms/presentation/widgets/room_settings/room_settings_modes_section.dart',
    ).readAsStringSync();
    final body = File(
      'lib/features/rooms/presentation/widgets/live_room_body.dart',
    ).readAsStringSync();
    final dock = File(
      'lib/features/rooms/presentation/widgets/live_room_input_dock.dart',
    ).readAsStringSync();
    final overlay = File(
      'lib/features/rooms/presentation/widgets/pk/live_room_pk_overlay.dart',
    ).readAsStringSync();

    expect(modes.contains("'Room PK'"), isTrue);
    expect(body.contains('pkScoreModule'), isTrue);
    expect(dock.contains('PK'), isFalse);
    expect(overlay.contains("'VS'"), isTrue);
    expect(overlay.contains("'VICTORY'"), isTrue);
    expect(overlay.contains('disableAnimations'), isTrue);
  });

  test('PK UI never writes a winner', () {
    final frontend = Directory('lib/features/rooms')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    expect(frontend.contains('winnerRoomId ='), isFalse);
    expect(frontend.contains('winner_room_id ='), isFalse);
  });
}
