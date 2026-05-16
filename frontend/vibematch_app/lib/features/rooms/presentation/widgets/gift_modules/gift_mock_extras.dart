import 'package:flutter/material.dart';

import '../../live_room_models.dart';

class GiftMockExtras {
  const GiftMockExtras._();

  static List<GiftItem> mergeWith(List<GiftItem> gifts) {
    const extras = <GiftItem>[
      GiftItem(
        id: 'romantic_proposal',
        name: 'Proposal',
        category: GiftCategory.premium,
        coins: 1999,
        icon: Icons.favorite_rounded,
        chatSymbol: '💍',
        videoAssetPath: 'assets/videos/gifts/boy_proposing_girl_d_romantic.mp4',
        colors: [Color(0xFFFF5F7E), Color(0xFFFFC857)],
      ),
      GiftItem(
        id: 'butterfly_girl',
        name: 'Butterfly',
        category: GiftCategory.premium,
        coins: 1499,
        icon: Icons.flutter_dash_rounded,
        chatSymbol: '🦋',
        videoAssetPath: 'assets/videos/gifts/pretty_girl_butterfly_animation.mp4',
        colors: [Color(0xFF12C7B7), Color(0xFF8C5CF6)],
      ),
      GiftItem(
        id: 'premium_magic_1',
        name: 'Magic 1',
        category: GiftCategory.premium,
        coins: 999,
        icon: Icons.auto_awesome_rounded,
        chatSymbol: '✨',
        videoAssetPath: 'assets/videos/gifts/premium_magic_1.mp4',
        colors: [Color(0xFFFF2D95), Color(0xFF6D5DF6)],
      ),
      GiftItem(
        id: 'premium_magic_2',
        name: 'Magic 2',
        category: GiftCategory.premium,
        coins: 1299,
        icon: Icons.diamond_rounded,
        chatSymbol: '💎',
        videoAssetPath: 'assets/videos/gifts/premium_magic_2.mp4',
        colors: [Color(0xFF22D3EE), Color(0xFFFFD166)],
      ),
      GiftItem(
        id: 'premium_magic_3',
        name: 'Magic 3',
        category: GiftCategory.premium,
        coins: 1599,
        icon: Icons.workspace_premium_rounded,
        chatSymbol: '👑',
        videoAssetPath: 'assets/videos/gifts/premium_magic_3.mp4',
        colors: [Color(0xFFFFB545), Color(0xFFE84C72)],
      ),
      GiftItem(
        id: 'lucky_packet',
        name: 'Lucky Packet',
        category: GiftCategory.lucky,
        coins: 39,
        icon: Icons.redeem_rounded,
        chatSymbol: '🧧',
        assetPath: 'assets/images/gifts/lucky_packet.png',
        colors: [Color(0xFFE84C72), Color(0xFFFFB545)],
      ),
    ];

    final seen = gifts.map((gift) => gift.id).toSet();
    return <GiftItem>[
      ...gifts,
      ...extras.where((gift) => seen.add(gift.id)),
    ];
  }
}
