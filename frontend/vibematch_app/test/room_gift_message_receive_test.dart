import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/features/rooms/data/live_room_system_event_bus.dart';
import 'package:vibematch_app/features/rooms/presentation/controllers/live_room_message_controller.dart';
import 'package:vibematch_app/features/rooms/presentation/live_room_models.dart';
import 'package:vibematch_app/features/rooms/presentation/live_room_restore_state.dart';

void main() {
  test('received room gift event becomes a gift chat entry', () {
    var changes = 0;
    const currentUser = SeatUser(
      id: 'user_6418000022',
      name: 'Receiver',
      roleLabel: 'Member',
      familyName: '',
      relationshipText: '',
      vipLevel: 1,
      sendingLevel: 2,
      receivingLevel: 3,
      sentExp: 0,
      receivedExp: 0,
      medals: <String>[],
      avatarColors: <Color>[Colors.blue, Colors.purple],
      isCurrentUser: true,
    );
    final controller = LiveRoomMessageController(
      currentUser: currentUser,
      onChanged: () => changes++,
      restoreState: const LiveRoomMessageRestoreState(
        messages: <ChatEntry>[],
        joinRequestUsers: <SeatUser>[],
      ),
    );

    LiveRoomSystemEventBus.publish(
      LiveRoomSystemEvent.fromJson(<String, dynamic>{
        'id': 'gift_77_6418000022',
        'event_type': 'room_gift_sent',
        'room_id': 'VMGIFT',
        'actor_user_id': 'user_6418000011',
        'actor_name': 'Sender',
        'actor_avatar_url': 'https://cdn.example/sender.png',
        'actor_vip_level': 5,
        'actor_sending_level': 8,
        'actor_receiving_level': 3,
        'target_user_id': 'user_6418000022',
        'target_name': 'Receiver',
        'gift_id': 'golden_crown',
        'gift_name': 'Golden Crown',
        'gift_type': 'normal',
        'quantity': 3,
        'coin_value': 500,
        'total_coin_value': 1500,
        'asset_path': 'assets/gifts/normal/crown.webp',
        'created_at': '2026-09-13T10:00:00Z',
      }),
    );

    expect(changes, 1);
    expect(controller.messages, hasLength(1));
    final message = controller.messages.single;
    expect(message.isGift, isTrue);
    expect(message.senderName, 'Sender');
    expect(message.senderId, 'user_6418000011');
    expect(message.message, 'sent to Receiver Golden Crown x3');
    expect(message.vipLevel, 5);
    expect(message.sendingLevel, 8);
    expect(message.receivingLevel, 3);
    expect(message.giftAssetPath, 'assets/gifts/normal/crown.webp');
  });

  test('lucky receive entry includes multiplier and quantity', () {
    const currentUser = SeatUser(
      id: 'user_7000000002',
      name: 'Lucky Receiver',
      roleLabel: 'Member',
      familyName: '',
      relationshipText: '',
      vipLevel: 0,
      sendingLevel: 0,
      receivingLevel: 0,
      sentExp: 0,
      receivedExp: 0,
      medals: <String>[],
      avatarColors: <Color>[Colors.teal, Colors.indigo],
      isCurrentUser: true,
    );
    final controller = LiveRoomMessageController(
      currentUser: currentUser,
      onChanged: () {},
      restoreState: const LiveRoomMessageRestoreState(
        messages: <ChatEntry>[],
        joinRequestUsers: <SeatUser>[],
      ),
    );

    LiveRoomSystemEventBus.publish(
      LiveRoomSystemEvent.fromJson(<String, dynamic>{
        'id': 'gift_99_7000000002',
        'event_type': 'room_gift_sent',
        'room_id': 'LUCKYROOM',
        'actor_user_id': 'user_7000000001',
        'actor_name': 'Lucky Sender',
        'target_user_id': 'user_7000000002',
        'target_name': 'Lucky Receiver',
        'gift_id': 'lucky_star',
        'gift_name': 'Lucky Star',
        'gift_type': 'lucky',
        'quantity': 9,
        'coin_value': 100,
        'total_coin_value': 900,
        'is_lucky': true,
        'lucky_multiplier': 500,
        'lucky_reward_coin_amount': 450000,
        'created_at': '2026-09-13T10:00:01Z',
      }),
    );

    expect(controller.messages, hasLength(1));
    expect(
      controller.messages.single.message,
      'sent to Lucky Receiver Lucky Star x500 x9',
    );
  });
}
