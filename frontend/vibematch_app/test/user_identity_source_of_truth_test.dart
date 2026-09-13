import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/features/auth/models/current_user.dart';
import 'package:vibematch_app/features/auth/models/user_identity_snapshot.dart';
import 'package:vibematch_app/features/profile/models/vip_wallet_models.dart';
import 'package:vibematch_app/features/rooms/data/live_room_presence_repository.dart';

void main() {
  group('canonical user identity', () {
    final payload = <String, dynamic>{
      'id': 44,
      'public_user_id': 6418000044,
      'display_custom_id': 4518000044,
      'username': 'canonical_user',
      'display_name': 'Canonical User',
      'avatar_url': 'https://cdn.example/avatar.webp',
      'primary_role': 'monitor',
      'primary_role_badge': <String, dynamic>{
        'role': 'monitor',
        'display_title': 'Monitor',
        'badge_label': 'Monitor Team',
        'pill_label': 'Monitor',
        'group': 'moderation',
        'priority': 60,
        'icon': 'health_and_safety',
        'background_color': '#2C1725',
        'text_color': '#FF9CB3',
        'border_color': '#E84C72',
        'show_verified_tick': false,
      },
      'role_badges': <Map<String, dynamic>>[],
      'vip': <String, dynamic>{
        'vip_level': 25,
        'svip_level': 4,
        'vip_is_active': true,
        'svip_is_active': true,
        'name_gradient_key': 'svip_4_emerald_neon',
        'name_gradient_colors': <String>['#00F5A0', '#00D9F5'],
      },
      'sending_level': 17,
      'receiving_level': 13,
      'sent_exp': 9000,
      'received_exp': 7000,
      'equipped_items': <String, dynamic>{
        'avatar_frame': <String, dynamic>{
          'item_id': 'frame_test',
          'category': 'avatar_frame',
          'asset_path': 'assets/frame.webp',
          'cdn_asset_url': 'https://cdn.example/frame.webp',
        },
        'chat_bubble': <String, dynamic>{
          'item_id': 'bubble_test',
          'category': 'chat_bubble',
          'asset_path': 'assets/bubble.webp',
          'image_url': 'https://cdn.example/bubble.webp',
        },
      },
    };

    test('normalizes identity, VIP, levels, roles and equipped items', () {
      final identity = UserIdentitySnapshot.fromJson(payload);

      expect(identity.backendUserId, 44);
      expect(identity.publicUserId, 6418000044);
      expect(identity.visibleId, '4518000044');
      expect(identity.visibleName, 'Canonical User');
      expect(identity.avatarUrl, 'https://cdn.example/avatar.webp');
      expect(identity.roleDisplayLabel, 'Monitor');
      expect(identity.vip.vipLevel, 25);
      expect(identity.vip.svipLevel, 4);
      expect(identity.sendLevel, 17);
      expect(identity.receiveLevel, 13);
      expect(identity.sentExp, 9000);
      expect(identity.receivedExp, 7000);
      expect(
        identity.equippedItems.avatarFrame?.bestImageUrl,
        'https://cdn.example/frame.webp',
      );
      expect(
        identity.equippedItems.chatBubble?.bestImageUrl,
        'https://cdn.example/bubble.webp',
      );
    });

    test('current user and live room consume the same core identity values', () {
      final currentUser = CurrentUser.fromJson(<String, dynamic>{
        ...payload,
        'roles': <String>['monitor', 'user'],
        'wallet': <String, dynamic>{
          'sent_level': 17,
          'receive_level': 13,
        },
        'is_active': true,
        'is_banned': false,
      });
      final roomUser = LiveRoomPresenceSnapshot.participantToSeatUser(
        <String, dynamic>{
          ...payload,
          'is_owner': false,
          'is_room_admin': false,
          'is_member': false,
          'is_online': true,
        },
      );

      expect(currentUser.displayName, roomUser.name);
      expect(currentUser.avatarUrl, roomUser.avatarUrl);
      expect(currentUser.vip.vipLevel, roomUser.vipLevel);
      expect(currentUser.vip.svipLevel, roomUser.svipLevel);
      expect(currentUser.wallet.sendLevel, roomUser.sendingLevel);
      expect(currentUser.wallet.receiveLevel, roomUser.receivingLevel);
      expect(currentUser.roleDisplayLabel, roomUser.roleLabel);
    });

    test('preserves VIP from an already-extracted identity VIP object', () {
      final identity = UserIdentitySnapshot.fromJson(<String, dynamic>{
        'id': 44,
        'public_user_id': 6418000044,
        'display_name': 'Canonical User',
        'vip': <String, dynamic>{'level': 25, 'is_active': true},
      });

      expect(identity.vip.vipLevel, 25);
      expect(identity.vip.vipIsActive, isTrue);
    });
  });

  group('VIP and wallet normalization', () {
    test('empty VIP is inactive', () {
      const vip = UserVipSummary.empty();
      expect(vip.vipLevel, 0);
      expect(vip.vipIsActive, isFalse);
      expect(vip.svipIsActive, isFalse);
    });

    test('missing active flag derives from level instead of defaulting true', () {
      final none = UserVipSummary.fromJson(<String, dynamic>{'vip_level': 0});
      final active = UserVipSummary.fromJson(<String, dynamic>{'vip_level': 12});

      expect(none.vipIsActive, isFalse);
      expect(active.vipIsActive, isTrue);
    });

    test('direct VIP payload normalizes level and active state', () {
      final direct = UserVipSummary.fromJson(<String, dynamic>{
        'level': 25,
        'is_active': true,
      });

      expect(direct.vipLevel, 25);
      expect(direct.vipIsActive, isTrue);
      expect(direct.svipLevel, 0);
      expect(direct.svipIsActive, isFalse);
    });

    test('all send and receive level aliases normalize consistently', () {
      expect(
        UserWalletSummary.fromJson(
          <String, dynamic>{'sent_level': 8, 'receive_level': 6},
        ).sendLevel,
        8,
      );
      expect(
        UserWalletSummary.fromJson(
          <String, dynamic>{'send_level': 8, 'receiving_level': 6},
        ).sendLevel,
        8,
      );
      expect(
        UserWalletSummary.fromJson(
          <String, dynamic>{'sending_level': 8, 'received_level': 6},
        ).receiveLevel,
        6,
      );
    });
  });
}
