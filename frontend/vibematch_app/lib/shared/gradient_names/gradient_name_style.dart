import 'package:flutter/material.dart';

class GradientNameStyle {
  const GradientNameStyle({
    required this.id,
    required this.label,
    required this.colors,
    this.isAnimated = false,
  });

  final String id;
  final String label;
  final List<Color> colors;
  final bool isAnimated;

  static const GradientNameStyle defaultName = GradientNameStyle(
    id: 'default',
    label: 'Default',
    colors: <Color>[Color(0xFF251538), Color(0xFF251538)],
  );

  static const GradientNameStyle ocean = GradientNameStyle(
    id: 'ocean',
    label: 'Ocean Wave',
    colors: <Color>[Color(0xFF12C7B7), Color(0xFF3B82F6)],
  );

  static const GradientNameStyle royal = GradientNameStyle(
    id: 'royal',
    label: 'Royal Pop',
    colors: <Color>[Color(0xFF8C5CF6), Color(0xFFE84C72)],
  );

  static const GradientNameStyle gold = GradientNameStyle(
    id: 'gold',
    label: 'Golden Flame',
    colors: <Color>[Color(0xFFFFC857), Color(0xFFFF8A00)],
  );

  static const GradientNameStyle rainbow = GradientNameStyle(
    id: 'rainbow',
    label: 'Rainbow Rush',
    colors: <Color>[Color(0xFFFF2D55), Color(0xFFFFC857), Color(0xFF12C7B7), Color(0xFF3B82F6), Color(0xFF8C5CF6)],
    isAnimated: true,
  );

  static const GradientNameStyle aurora = GradientNameStyle(
    id: 'aurora',
    label: 'Aurora Night',
    colors: <Color>[Color(0xFF00F5A0), Color(0xFF00D9F5), Color(0xFF7C3AED)],
    isAnimated: true,
  );

  static const GradientNameStyle candy = GradientNameStyle(
    id: 'candy',
    label: 'Candy Mix',
    colors: <Color>[Color(0xFFFF8AA8), Color(0xFFFFD36A), Color(0xFF8C5CF6)],
  );

  static const GradientNameStyle fireIce = GradientNameStyle(
    id: 'fire_ice',
    label: 'Fire & Ice',
    colors: <Color>[Color(0xFFFF3B30), Color(0xFFFFC857), Color(0xFF53BDEB), Color(0xFF3B82F6)],
    isAnimated: true,
  );

  static const GradientNameStyle galaxy = GradientNameStyle(
    id: 'galaxy',
    label: 'Galaxy Beam',
    colors: <Color>[Color(0xFF251538), Color(0xFF6D5DF6), Color(0xFFE84C72), Color(0xFFFFC857)],
    isAnimated: true,
  );

  static const GradientNameStyle emerald = GradientNameStyle(
    id: 'emerald',
    label: 'Emerald Shine',
    colors: <Color>[Color(0xFF064E3B), Color(0xFF10B981), Color(0xFFA7F3D0)],
  );

  static const GradientNameStyle superOwner = GradientNameStyle(
    id: 'super_owner',
    label: 'Super Owner',
    colors: <Color>[Color(0xFFFFF1A8), Color(0xFFFFC857), Color(0xFFE84C72)],
    isAnimated: true,
  );

  static const GradientNameStyle owner = GradientNameStyle(
    id: 'owner',
    label: 'Owner',
    colors: <Color>[Color(0xFFFFC857), Color(0xFF8C5CF6)],
    isAnimated: true,
  );

  static const GradientNameStyle official = GradientNameStyle(
    id: 'official',
    label: 'Official',
    colors: <Color>[Color(0xFF53BDEB), Color(0xFF12C7B7)],
  );

  static const List<GradientNameStyle> storeStyles = <GradientNameStyle>[
    rainbow,
    aurora,
    galaxy,
    fireIce,
    candy,
    ocean,
    royal,
    gold,
    emerald,
    official,
  ];

  static GradientNameStyle byRole(String? role) {
    switch (role?.trim().toLowerCase()) {
      case 'founder_owner':
      case 'super_owner':
        return superOwner;
      case 'owner':
        return owner;
      case 'superadmin':
      case 'admin':
      case 'monitor':
      case 'cs':
        return official;
      default:
        return defaultName;
    }
  }

  static GradientNameStyle byId(String? id) {
    switch (id?.trim().toLowerCase()) {
      case 'ocean':
        return ocean;
      case 'royal':
        return royal;
      case 'gold':
        return gold;
      case 'rainbow':
        return rainbow;
      case 'aurora':
        return aurora;
      case 'candy':
        return candy;
      case 'fire_ice':
        return fireIce;
      case 'galaxy':
        return galaxy;
      case 'emerald':
        return emerald;
      case 'super_owner':
        return superOwner;
      case 'owner':
        return owner;
      case 'official':
        return official;
      default:
        return defaultName;
    }
  }
}
