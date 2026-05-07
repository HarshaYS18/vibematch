import 'package:flutter/material.dart';

class SocialEmojiItem {
  const SocialEmojiItem({
    required this.id,
    required this.label,
    required this.emoji,
    required this.gradient,
  });

  final String id;
  final String label;
  final String emoji;
  final List<Color> gradient;
}

class PremiumSocialEmojiPack {
  const PremiumSocialEmojiPack._();

  // Future backend/CDN mapping:
  // GET /emoji-packs/social-premium
  // The server can return id, label, unicode fallback, animation asset url,
  // pack version, and active/inactive state without app update.
  static const List<SocialEmojiItem> items = [
    SocialEmojiItem(
      id: 'royal_love',
      label: 'Royal Love',
      emoji: '💖',
      gradient: [Color(0xFFFF5FA2), Color(0xFFFFD36A)],
    ),
    SocialEmojiItem(
      id: 'fire_vibe',
      label: 'Fire Vibe',
      emoji: '🔥',
      gradient: [Color(0xFFFF7A45), Color(0xFFE84C72)],
    ),
    SocialEmojiItem(
      id: 'sparkle_smile',
      label: 'Sparkle',
      emoji: '✨',
      gradient: [Color(0xFF6D5DF6), Color(0xFF12C7B7)],
    ),
    SocialEmojiItem(
      id: 'cool_cat',
      label: 'Cool',
      emoji: '😎',
      gradient: [Color(0xFF251538), Color(0xFF6D5DF6)],
    ),
    SocialEmojiItem(
      id: 'laugh_luxe',
      label: 'Laugh',
      emoji: '😂',
      gradient: [Color(0xFFFFD36A), Color(0xFFFF8C42)],
    ),
    SocialEmojiItem(
      id: 'blush_vibe',
      label: 'Blush',
      emoji: '😊',
      gradient: [Color(0xFFFFA6C8), Color(0xFFE84C72)],
    ),
    SocialEmojiItem(
      id: 'mind_blown',
      label: 'Wow',
      emoji: '🤯',
      gradient: [Color(0xFF12C7B7), Color(0xFF27B7FF)],
    ),
    SocialEmojiItem(
      id: 'respect_gold',
      label: 'Respect',
      emoji: '🙏',
      gradient: [Color(0xFFC99A3B), Color(0xFFFFD36A)],
    ),
    SocialEmojiItem(
      id: 'tear_pearl',
      label: 'Touched',
      emoji: '🥹',
      gradient: [Color(0xFFB8A8BD), Color(0xFF6D5DF6)],
    ),
    SocialEmojiItem(
      id: 'party_neon',
      label: 'Party',
      emoji: '🎉',
      gradient: [Color(0xFF20FF99), Color(0xFFD65AFF)],
    ),
    SocialEmojiItem(
      id: 'kiss_coral',
      label: 'Kiss',
      emoji: '😘',
      gradient: [Color(0xFFE84C72), Color(0xFFFFD36A)],
    ),
    SocialEmojiItem(
      id: 'crown_vibe',
      label: 'Royal',
      emoji: '👑',
      gradient: [Color(0xFF251538), Color(0xFFC99A3B)],
    ),
  ];
}
