import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/features/rooms/data/live_room_membership_service.dart';

void main() {
  setUp(LiveRoomMembershipService.clearAll);
  tearDown(LiveRoomMembershipService.clearAll);

  test('normalizes room participant aliases to one membership identity', () {
    LiveRoomMembershipService.applyBackendMembershipSnapshot(
      roomId: 'VM100',
      roomMemberByUserId: const {'user_6418001001': true},
    );

    expect(
      LiveRoomMembershipService.isRoomMember(
        roomId: 'VM100',
        userId: '6418001001',
      ),
      isTrue,
    );
    expect(
      LiveRoomMembershipService.isRoomMember(
        roomId: 'VM100',
        userId: 'USER_6418001001',
      ),
      isTrue,
    );
  });

  test('backend removal replaces previously confirmed room-member state', () {
    LiveRoomMembershipService.applyBackendMembershipSnapshot(
      roomId: 'VM100',
      roomMemberByUserId: const {'6418001001': true},
    );
    LiveRoomMembershipService.applyBackendMembershipSnapshot(
      roomId: 'VM100',
      roomMemberByUserId: const {'user_6418001001': false},
    );

    expect(
      LiveRoomMembershipService.statusFor(
        roomId: 'VM100',
        userId: '6418001001',
      ),
      LiveRoomMembershipStatus.guest,
    );
  });

  test('participant snapshot does not erase a temporary pending request', () {
    LiveRoomMembershipService.markPending(
      roomId: 'VM100',
      userId: '6418001001',
    );
    LiveRoomMembershipService.applyBackendMembershipSnapshot(
      roomId: 'VM100',
      roomMemberByUserId: const {'user_6418001001': false},
    );

    expect(
      LiveRoomMembershipService.isPending(
        roomId: 'VM100',
        userId: '6418001001',
      ),
      isTrue,
    );

    LiveRoomMembershipService.applyBackendMembershipSnapshot(
      roomId: 'VM100',
      roomMemberByUserId: const {'user_6418001001': true},
    );
    expect(
      LiveRoomMembershipService.isRoomMember(
        roomId: 'VM100',
        userId: '6418001001',
      ),
      isTrue,
    );
  });

  test('complete backend roster clears stale confirmed membership', () {
    LiveRoomMembershipService.applyBackendMembershipSnapshot(
      roomId: 'VM100',
      roomMemberByUserId: const {'6418001001': true},
    );

    LiveRoomMembershipService.applyBackendMembershipSnapshot(
      roomId: 'VM100',
      roomMemberByUserId: const <String, bool>{},
      completeRoster: true,
    );

    expect(
      LiveRoomMembershipService.statusFor(
        roomId: 'VM100',
        userId: '6418001001',
      ),
      LiveRoomMembershipStatus.guest,
    );
  });

  test('complete backend roster preserves pending request UI state', () {
    LiveRoomMembershipService.markPending(
      roomId: 'VM100',
      userId: '6418001001',
    );

    LiveRoomMembershipService.applyBackendMembershipSnapshot(
      roomId: 'VM100',
      roomMemberByUserId: const <String, bool>{},
      completeRoster: true,
    );

    expect(
      LiveRoomMembershipService.isPending(
        roomId: 'VM100',
        userId: '6418001001',
      ),
      isTrue,
    );
  });

  test('authoritative pending snapshot clears a resolved pending request', () {
    LiveRoomMembershipService.markPending(
      roomId: 'VM100',
      userId: '6418001001',
    );

    LiveRoomMembershipService.applyBackendPendingSnapshot(
      roomId: 'VM100',
      pendingUserIds: const <String>{},
    );

    expect(
      LiveRoomMembershipService.statusFor(
        roomId: 'VM100',
        userId: '6418001001',
      ),
      LiveRoomMembershipStatus.guest,
    );
  });

  test('authoritative pending snapshot does not downgrade confirmed membership', () {
    LiveRoomMembershipService.applyBackendMembershipSnapshot(
      roomId: 'VM100',
      roomMemberByUserId: const {'6418001001': true},
    );

    LiveRoomMembershipService.applyBackendPendingSnapshot(
      roomId: 'VM100',
      pendingUserIds: const <String>{},
    );

    expect(
      LiveRoomMembershipService.isRoomMember(
        roomId: 'VM100',
        userId: 'user_6418001001',
      ),
      isTrue,
    );
  });

  test('authoritative pending snapshot normalizes public user aliases', () {
    LiveRoomMembershipService.applyBackendPendingSnapshot(
      roomId: 'VM100',
      pendingUserIds: const {'user_6418001001'},
    );

    expect(
      LiveRoomMembershipService.isPending(
        roomId: 'VM100',
        userId: '6418001001',
      ),
      isTrue,
    );
  });

  test('clearAll removes account-scoped room membership projection', () {
    LiveRoomMembershipService.applyBackendMembershipSnapshot(
      roomId: 'VM100',
      roomMemberByUserId: const {'6418001001': true},
    );

    LiveRoomMembershipService.clearAll();

    expect(LiveRoomMembershipService.snapshots.value, isEmpty);
  });
}
