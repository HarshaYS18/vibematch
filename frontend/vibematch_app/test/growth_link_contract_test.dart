import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/core/growth/vm_growth_link.dart';

void main() {
  test('custom-scheme growth links round-trip supported destinations', () {
    final links = <Uri>[
      VmGrowthLinks.room('room-1', referrerId: '101'),
      VmGrowthLinks.vibe('vibe-2', referrerId: '101'),
      VmGrowthLinks.profile('6922001', referrerId: '101'),
      VmGrowthLinks.game('jungle-hunt', referrerId: '101'),
      VmGrowthLinks.event('event-4', referrerId: '101'),
      VmGrowthLinks.family(
        'family-5',
        referrerId: '101',
        inviteToken: 'invite-token',
      ),
    ];

    for (final uri in links) {
      final parsed = VmGrowthLinks.parse(uri);
      expect(parsed, isNotNull);
      expect(parsed!.referrerId, '101');
    }

    final family = VmGrowthLinks.parse(links.last)!;
    expect(family.destination, VmGrowthDestination.family);
    expect(family.id, 'family-5');
    expect(family.inviteToken, 'invite-token');
  });

  test('unknown schemes and destinations are rejected', () {
    expect(VmGrowthLinks.parse(Uri.parse('other://room/1')), isNull);
    expect(VmGrowthLinks.parse(Uri.parse('funkey://unknown/1')), isNull);
    expect(VmGrowthLinks.parse(Uri.parse('funkey://room/')), isNull);
  });
}
