import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/features/auth/models/current_user_master_state_mapper.dart';

void main() {
  test('master-state mapper preserves canonical profile fields', () {
    final user = currentUserFromMasterStateJson({
      'identity': {
        'backend_user_id': 7,
        'public_user_id': 6418001001,
        'display_custom_id': 123456,
        'username': 'funkey_user',
        'display_name': 'FunKey User',
        'avatar_url': 'https://cdn.example/avatar.jpg',
        'bio': 'Hello',
        'cover_photo_urls': ['https://cdn.example/cover.jpg'],
        'date_of_birth': '2000-01-02',
        'gender': 'other',
        'profession': 'Creator',
        'marital_status': 'single',
        'friend_gender_preference': 'both',
        'friend_marital_preference': 'any',
        'interests': ['music', 'games'],
        'is_active': true,
        'is_banned': false,
        'last_device_id': 'device-1',
        'last_login_at': '2026-09-22T10:00:00',
        'last_seen_at': '2026-09-22T10:05:00',
        'created_at': '2026-01-01T00:00:00',
        'updated_at': '2026-09-22T10:05:00',
      },
      'roles': {
        'roles': ['user'],
        'primary_role': 'user',
      },
      'profile_summary': {
        'vip': {'vip_level': 0, 'svip_level': 0},
        'wallet': {'coin_balance': 0, 'ruby_balance': 0},
      },
    });

    expect(user.publicUserId, 6418001001);
    expect(user.avatarUrl, 'https://cdn.example/avatar.jpg');
    expect(user.coverPhotoUrls, ['https://cdn.example/cover.jpg']);
    expect(user.dateOfBirth, DateTime(2000, 1, 2));
    expect(user.gender, 'other');
    expect(user.profession, 'Creator');
    expect(user.maritalStatus, 'single');
    expect(user.friendGenderPreference, 'both');
    expect(user.friendMaritalPreference, 'any');
    expect(user.interests, ['music', 'games']);
    expect(user.lastDeviceId, 'device-1');
    expect(user.lastLoginAt, DateTime(2026, 9, 22, 10));
  });
}
