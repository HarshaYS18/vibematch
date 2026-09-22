import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Chunk 0 baseline manifest keeps every frozen product surface', () {
    final file = File('tool/frontend_baseline_manifest.json');
    expect(file.existsSync(), isTrue);

    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    expect(json['ui_contract'], 'existing_funkey_ui_no_redesign');
    expect(json['version'], 2);

    final reference = json['reference'] as Map<String, dynamic>;
    expect(reference['commit'], 'b8189636eacda323cabcf2b07a2bedf94853737d');
    expect(reference['phase'], 'post_chunk_5_pre_chunk_6');
    expect(
      reference['historical_pre_chunk_0_visual_evidence_available'],
      isFalse,
    );
    expect(json['evidence_status'], 'capture_required');

    final screens = (json['screens'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map((item) => item['id'])
        .toSet();

    expect(
      screens,
      containsAll(<String>{
        'login',
        'onboarding',
        'home',
        'room',
        'room_sheets',
        'profile',
        'vibes',
        'inbox',
        'wallet',
        'store',
        'games',
        'control_center',
      }),
    );

    final budgets = json['performance_budgets'] as Map<String, dynamic>;
    expect(budgets['frame_60hz_ms'], 16.67);
    expect(budgets['frame_120hz_ms'], 8.33);
  });
}
