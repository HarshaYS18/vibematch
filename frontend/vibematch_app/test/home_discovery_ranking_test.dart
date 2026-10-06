import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/features/home/controllers/home_controller.dart';
import 'package:vibematch_app/features/home/models/home_room.dart';

HomeRoom room(
  String id, {
  required int online,
  required int trending,
}) {
  return HomeRoom(
    id: id,
    name: 'Room $id',
    subtitle: 'Room $id',
    language: 'English',
    mode: 'Open',
    type: 'Voice',
    onlineCount: online,
    trendingScore: trending,
    followedFriendsInside: const <String>[],
  );
}

void main() {
  test('Trending preserves recommendation order ahead of generic popularity', () {
    final state = HomeState(
      backendRooms: <HomeRoom>[
        room('popular', online: 500, trending: 900),
        room('recommended', online: 5, trending: 10),
      ],
      recommendedRoomIds: const <String>['recommended'],
    );

    expect(
      state.filteredRooms.map((item) => item.id).toList(),
      const <String>['recommended', 'popular'],
    );
  });

  test('refresh errors preserve already loaded room content', () {
    final state = HomeState(
      backendRooms: <HomeRoom>[
        room('still-visible', online: 12, trending: 20),
      ],
      loadErrorMessage: 'Could not refresh rooms.',
    );

    expect(state.filteredRooms.map((item) => item.id), contains('still-visible'));
  });
}
