import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'gradient_name_style.dart';
import 'gradient_name_text.dart';

class EquippedGradientNameText extends StatefulWidget {
  const EquippedGradientNameText(
    this.text, {
    super.key,
    this.role,
    this.fallbackStyle,
    this.textStyle,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.textAlign,
    this.semanticsLabel,
    this.useEquippedStoreStyle = true,
  });

  final String text;
  final String? role;
  final GradientNameStyle? fallbackStyle;
  final TextStyle? textStyle;
  final int? maxLines;
  final TextOverflow overflow;
  final TextAlign? textAlign;
  final String? semanticsLabel;
  final bool useEquippedStoreStyle;

  @override
  State<EquippedGradientNameText> createState() => _EquippedGradientNameTextState();
}

class _EquippedGradientNameTextState extends State<EquippedGradientNameText> {
  static const String _inventoryKey = 'vm_store.inventory';
  GradientNameStyle? _equippedStyle;

  @override
  void initState() {
    super.initState();
    _loadEquippedStyle();
  }

  @override
  void didUpdateWidget(covariant EquippedGradientNameText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.useEquippedStoreStyle != widget.useEquippedStoreStyle) {
      _loadEquippedStyle();
    }
  }

  Future<void> _loadEquippedStyle() async {
    if (!widget.useEquippedStoreStyle) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_inventoryKey);
    final style = _resolveEquippedGradient(raw);
    if (!mounted) return;
    setState(() => _equippedStyle = style);
  }

  GradientNameStyle? _resolveEquippedGradient(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      for (final item in decoded.reversed) {
        if (item is! Map) continue;
        final entry = Map<String, dynamic>.from(item);
        final itemId = entry['item_id']?.toString() ?? '';
        final equipped = entry['is_equipped'] == true;
        if (!equipped || !itemId.startsWith('gradient_name_')) continue;
        final expiresRaw = entry['expires_at']?.toString();
        if (expiresRaw != null && expiresRaw.trim().isNotEmpty) {
          final expiresAt = DateTime.tryParse(expiresRaw);
          if (expiresAt != null && DateTime.now().isAfter(expiresAt)) continue;
        }
        final styleId = itemId.replaceFirst('gradient_name_', '').replaceFirst('_30d', '');
        final style = GradientNameStyle.byId(styleId);
        if (style.id != GradientNameStyle.defaultName.id) return style;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final fallback = widget.fallbackStyle ?? GradientNameStyle.byRole(widget.role);
    return GradientNameText(
      widget.text,
      style: _equippedStyle ?? fallback,
      textStyle: widget.textStyle,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      textAlign: widget.textAlign,
      semanticsLabel: widget.semanticsLabel,
    );
  }
}
