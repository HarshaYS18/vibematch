import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibematch_app/features/auth/data/auth_api_service.dart';
import 'package:vibematch_app/features/auth/models/current_user.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('restoring persisted cache does not publish identity before backend validation', () async {
    final cachedUser = CurrentUser.mockNormalUser();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'vm_auth_access_token': 'cached-token',
      'vm_auth_user_json': jsonEncode(cachedUser.toJson()),
      'vm_auth_device_id': 'cached-device',
    });

    final published = <CurrentUser>[];
    final subscription = AuthUserRealtimeService.instance.users.listen(published.add);
    addTearDown(subscription.cancel);

    const service = AuthApiService();
    await service.restoreSavedSession();
    await Future<void>.delayed(Duration.zero);

    expect(service.cachedUser?.publicUserId, cachedUser.publicUserId);
    expect(published, isEmpty);
  });
}
