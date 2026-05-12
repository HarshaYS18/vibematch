import 'package:flutter/material.dart';

import '../../../data/love_bond_realtime_service.dart';
import '../models/love_bond_models.dart';

List<LoveBondCardData> loveBondCardsForProfile(int publicUserId) {
  final activeRequests = LoveBondRealtimeService.activeBondsFor(publicUserId);
  final cards = <LoveBondCardData>[
    _openSlot(type: LoveBondType.lover),
    _openSlot(type: LoveBondType.bestie),
    _openSlot(type: LoveBondType.brother),
    _openSlot(type: LoveBondType.sister),
  ];

  for (final request in activeRequests) {
    final partner = request.partnerFor(publicUserId);
    if (partner == null) continue;

    final profileTitle = request.profileTitleFor(publicUserId);
    final slotType = _slotTypeForRequest(request: request, profileTitle: profileTitle);
    final slotIndex = cards.indexWhere((card) => card.type == slotType);
    if (slotIndex < 0) continue;

    cards[slotIndex] = _activeCard(
      type: slotType,
      title: profileTitle,
      partnerName: partner.displayName,
      partnerInitial: partner.avatarInitial,
    );
  }

  return cards;
}

LoveBondType _slotTypeForRequest({
  required LoveBondRequest request,
  required String profileTitle,
}) {
  if (request.cardType == LoveBondType.lover) return LoveBondType.lover;
  if (request.cardType == LoveBondType.bestie) return LoveBondType.bestie;

  final normalizedTitle = profileTitle.trim().toLowerCase();
  if (normalizedTitle == 'sister') return LoveBondType.sister;
  return LoveBondType.brother;
}

LoveBondCardData _openSlot({required LoveBondType type}) {
  final style = _styleFor(type);
  return LoveBondCardData(
    type: type,
    title: _titleFor(type),
    level: 0,
    displayName: 'Open',
    partnerName: 'Open slot',
    primaryColor: style.primary,
    secondaryColor: style.secondary,
    icon: style.icon,
    badgeIcon: style.badgeIcon,
    leftAvatarInitial: '+',
    rightAvatarInitial: '+',
  );
}

LoveBondCardData _activeCard({
  required LoveBondType type,
  required String title,
  required String partnerName,
  required String partnerInitial,
}) {
  final style = _styleFor(type);
  return LoveBondCardData(
    type: type,
    title: title,
    level: 1,
    displayName: title,
    partnerName: partnerName,
    primaryColor: style.primary,
    secondaryColor: style.secondary,
    icon: style.icon,
    badgeIcon: style.badgeIcon,
    leftAvatarInitial: 'V',
    rightAvatarInitial: partnerInitial,
    loveScore: 0,
    nextLevelLoveScore: 500,
  );
}

String _titleFor(LoveBondType type) {
  return switch (type) {
    LoveBondType.lover => 'Love',
    LoveBondType.bestie => 'Bestie',
    LoveBondType.brother => 'Brother',
    LoveBondType.sister => 'Sister',
  };
}

_LoveBondCardStyle _styleFor(LoveBondType type) {
  return switch (type) {
    LoveBondType.lover => const _LoveBondCardStyle(
        primary: Color(0xFFFF5AAA),
        secondary: Color(0xFFFFC2DC),
        icon: Icons.favorite_rounded,
        badgeIcon: Icons.favorite_rounded,
      ),
    LoveBondType.bestie => const _LoveBondCardStyle(
        primary: Color(0xFF9C5CFF),
        secondary: Color(0xFFE2CCFF),
        icon: Icons.auto_awesome_rounded,
        badgeIcon: Icons.stars_rounded,
      ),
    LoveBondType.brother => const _LoveBondCardStyle(
        primary: Color(0xFF4C8DFF),
        secondary: Color(0xFFCFE2FF),
        icon: Icons.shield_rounded,
        badgeIcon: Icons.bolt_rounded,
      ),
    LoveBondType.sister => const _LoveBondCardStyle(
        primary: Color(0xFFFFA93D),
        secondary: Color(0xFFFFE0A8),
        icon: Icons.local_florist_rounded,
        badgeIcon: Icons.local_florist_rounded,
      ),
  };
}

class _LoveBondCardStyle {
  const _LoveBondCardStyle({
    required this.primary,
    required this.secondary,
    required this.icon,
    required this.badgeIcon,
  });

  final Color primary;
  final Color secondary;
  final IconData icon;
  final IconData badgeIcon;
}
