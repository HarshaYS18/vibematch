import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/features/auth/data/auth_api_service.dart';

void main() {
  const auth = AuthApiService();

  test('classifies backend auth rejection as authoritative', () {
    expect(
      auth.isAuthoritativeSessionFailure(
        Exception('Failed to load backend master user state (401): expired'),
      ),
      isTrue,
    );
    expect(
      auth.isAuthoritativeSessionFailure(
        Exception('ApiException [403]: Request failed'),
      ),
      isTrue,
    );
    expect(
      auth.isAuthoritativeSessionFailure(
        Exception('Session replaced. Please login again.'),
      ),
      isTrue,
    );
  });

  test('does not classify a network outage as authoritative logout', () {
    expect(
      auth.isAuthoritativeSessionFailure(
        Exception('SocketException: Connection refused'),
      ),
      isFalse,
    );
  });
}
