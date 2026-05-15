import 'package:flutter/material.dart';

import 'gradient_name_style.dart';
import 'gradient_name_sync_service.dart';
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
  @override
  void initState() {
    super.initState();
    GradientNameSyncService.equippedStyle.addListener(_onGradientStyleChanged);
    if (widget.useEquippedStoreStyle) {
      GradientNameSyncService.ensureLoaded();
    }
  }

  @override
  void didUpdateWidget(covariant EquippedGradientNameText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.useEquippedStoreStyle != widget.useEquippedStoreStyle &&
        widget.useEquippedStoreStyle) {
      GradientNameSyncService.ensureLoaded();
    }
  }

  @override
  void dispose() {
    GradientNameSyncService.equippedStyle.removeListener(_onGradientStyleChanged);
    super.dispose();
  }

  void _onGradientStyleChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final fallback = widget.fallbackStyle ?? GradientNameStyle.byRole(widget.role);
    final syncedStyle = widget.useEquippedStoreStyle
        ? GradientNameSyncService.equippedStyle.value
        : null;
    return GradientNameText(
      widget.text,
      style: syncedStyle ?? fallback,
      textStyle: widget.textStyle,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      textAlign: widget.textAlign,
      semanticsLabel: widget.semanticsLabel,
    );
  }
}
