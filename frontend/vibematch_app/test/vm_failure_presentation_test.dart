import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/core/network/api_exception.dart';
import 'package:vibematch_app/core/network/vm_failure.dart';

void main() {
  group('VmFailurePresentation', () {
    test('normalizes offline transport failures', () {
      final failure = VmFailurePresentation.from(
        const ApiException(message: 'Network request failed: connectionError'),
        contentLabel: 'rooms',
      );

      expect(failure.kind, VmFailureKind.offline);
      expect(failure.retryable, isTrue);
      expect(
        failure.message,
        'You appear to be offline. Check your connection and try again.',
      );
    });

    test('normalizes timeouts without exposing transport internals', () {
      final failure = VmFailurePresentation.from(
        const ApiException(message: 'Network request failed: receiveTimeout'),
      );

      expect(failure.kind, VmFailureKind.timeout);
      expect(failure.retryable, isTrue);
      expect(failure.message.toLowerCase(), contains('taking longer'));
      expect(failure.message.toLowerCase(), isNot(contains('receivetimeout')));
    });

    test('session expiry is explicit and not locally retryable', () {
      final failure = VmFailurePresentation.from(
        const ApiException(message: 'Request failed', statusCode: 401),
      );

      expect(failure.kind, VmFailureKind.unauthenticated);
      expect(failure.retryable, isFalse);
      expect(failure.title, 'Session expired');
    });

    test('server errors use one safe retry message', () {
      final failure = VmFailurePresentation.from(
        const ApiException(
          message: 'Request failed',
          statusCode: 503,
          body: 'internal upstream unavailable',
        ),
        contentLabel: 'Vibes',
      );

      expect(failure.kind, VmFailureKind.server);
      expect(failure.retryable, isTrue);
      expect(failure.message, contains('FunKey'));
      expect(failure.message, contains('Vibes'));
      expect(failure.message, isNot(contains('upstream')));
    });

    test('safe validation detail remains visible', () {
      final failure = VmFailurePresentation.from(
        const ApiException(
          message: 'Request failed',
          statusCode: 422,
          body: <String, Object?>{'detail': 'Username is already taken.'},
        ),
        contentLabel: 'profile',
      );

      expect(failure.kind, VmFailureKind.unknown);
      expect(failure.message, 'Username is already taken.');
    });
  });
}
