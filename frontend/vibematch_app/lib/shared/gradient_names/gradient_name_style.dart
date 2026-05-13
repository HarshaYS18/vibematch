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
    label: 'Ocean',
    colors: <Color>[Color(0xFF12C7B7), Color(0xFF3B82F6)],
  );

  static const GradientNameStyle royal = GradientNameStyle(
    id: 'royal',
    label: 'Royal',
    colors: <Color>[Color(0xFF8C5CF6), Color(0xFFE84C72)],
  );

  static const GradientNameStyle gold = GradientNameStyle(
    id: 'gold',
    label: 'Gold',
    colors: <Color>[Color(0xFFFFC857), Color(0xFFFF8A00)],
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
