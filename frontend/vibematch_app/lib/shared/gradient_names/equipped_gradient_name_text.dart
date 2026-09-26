import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'gradient_name_style.dart';
import 'gradient_name_sync_service.dart';
import 'gradient_name_text.dart';

/// Displays a user name using the session-scoped equipped gradient when enabled.
///
/// The equipped style is read from [equippedGradientNameStyleProvider]. This
/// widget owns no persistence or global cache; while the provider is loading or
/// unavailable it renders the supplied role/fallback style.
class EquippedGradientNameText extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final fallback =
        fallbackStyle ?? GradientNameStyle.byRole(role);
    final syncedStyle = useEquippedStoreStyle
        ? ref.watch(equippedGradientNameStyleProvider).asData?.value
        : null;

    return GradientNameText(
      text,
      style: syncedStyle ?? fallback,
      textStyle: textStyle,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      semanticsLabel: semanticsLabel,
    );
  }
}
