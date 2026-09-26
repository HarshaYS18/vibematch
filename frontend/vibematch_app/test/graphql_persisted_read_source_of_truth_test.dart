import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Chunk 36 Flutter sends persisted ids without query text', () {
    final operations = File(
      'lib/foundation/graphql/persisted_operations.dart',
    ).readAsStringSync();
    final client = File(
      'lib/foundation/graphql/persisted_graphql_client.dart',
    ).readAsStringSync();
    final home = File(
      'lib/features/home/controllers/home_controller.dart',
    ).readAsStringSync();

    expect(operations, contains('49caa7816c5a823071f7b812cfcc35b6'));
    expect(client, contains("'id': operationId"));
    expect(client, contains("'variables': variables"));
    expect(client, isNot(contains("'query':")));
    expect(home, contains('fetchHomeChromeComposite'));
    expect(home, isNot(contains('Future.wait<Object?>')));
  });
}
