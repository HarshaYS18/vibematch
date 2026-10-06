import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/foundation/offline/offline_projection_store.dart';

void main() {
  test('authoritative commands are never queued offline', () {
    expect(OfflineMutationPolicy.mayQueue('wallet.debit'), isFalse);
    expect(OfflineMutationPolicy.mayQueue('gift.send'), isFalse);
    expect(OfflineMutationPolicy.mayQueue('room.seat.take'), isFalse);
    expect(OfflineMutationPolicy.mayQueue('game.settlement.commit'), isFalse);
  });

  test('read projection scopes stay explicitly bounded', () {
    expect(OfflineProjectionStore.allowedScopes, contains('room_preview'));
    expect(OfflineProjectionStore.allowedScopes, isNot(contains('wallet')));
    expect(OfflineProjectionStore.maxRows, lessThanOrEqualTo(64));
    expect(OfflineProjectionStore.maxPayloadBytes, lessThanOrEqualTo(65536));
  });
}
