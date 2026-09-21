import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/features/rooms/data/seat_authority_gate.dart';

void main() {
  group('SeatAuthorityGate', () {
    test('does not revoke a pending seat from an older snapshot', () {
      final gate = SeatAuthorityGate()..requestSeat(3, micEnabled: true);

      final decision = gate.observe(
        authoritativeSeatIndex: null,
        authoritativeMicEnabled: false,
        adminMuted: false,
      );

      expect(decision.awaitSeatConfirmation, isTrue);
      expect(decision.shouldLeaveSeat, isFalse);
    });

    test('starts media only after an authoritative seat confirmation', () {
      final gate = SeatAuthorityGate()..requestSeat(3, micEnabled: true);

      final decision = gate.observe(
        authoritativeSeatIndex: 3,
        authoritativeMicEnabled: true,
        adminMuted: false,
      );

      expect(decision.confirmedSeatIndex, 3);
      expect(decision.micEnabled, isTrue);
      expect(gate.pendingSeatIndex, isNull);
    });

    test('admin mute wins over an authoritative enabled microphone', () {
      final decision = SeatAuthorityGate().observe(
        authoritativeSeatIndex: 1,
        authoritativeMicEnabled: true,
        adminMuted: true,
      );

      expect(decision.confirmedSeatIndex, 1);
      expect(decision.micEnabled, isFalse);
    });

    test('rejected pending seat is subsequently treated as a revocation', () {
      final gate = SeatAuthorityGate()..requestSeat(1);
      gate.rejectSeatRequest();

      final decision = gate.observe(
        authoritativeSeatIndex: null,
        authoritativeMicEnabled: false,
        adminMuted: false,
      );

      expect(decision.shouldLeaveSeat, isTrue);
    });
  });
}
