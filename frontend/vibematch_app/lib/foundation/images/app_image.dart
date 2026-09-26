import 'package:flutter/material.dart';

/// Shared decode policy for CDN/network images.
///
/// Small UI surfaces should decode close to their physical render size instead
/// of retaining full-resolution uploads or CDN media in Flutter's image cache.
abstract final class AppImageDecodePolicy {
  static const int maxDecodeDimension = 4096;

  static int? pixelDimension(
    BuildContext context,
    double? logicalDimension,
  ) {
    if (logicalDimension == null ||
        !logicalDimension.isFinite ||
        logicalDimension <= 0) {
      return null;
    }
    final dpr = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 4.0);
    final pixels = (logicalDimension * dpr).round();
    return pixels.clamp(1, maxDecodeDimension).toInt();
  }
}

/// Canonical image widget for high-frequency FunKey presentation surfaces.
///
/// Product media is CDN/network-owned. The Flutter bundle intentionally keeps
/// only the FunKey logo, so this abstraction has no asset-backed constructor.
class AppImage extends StatelessWidget {
  const AppImage.network(
    String url, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.medium,
    this.gaplessPlayback = true,
    this.fallback,
    this.decodeWidth,
    this.decodeHeight,
  }) : source = url;

  final String source;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final FilterQuality filterQuality;
  final bool gaplessPlayback;
  final Widget? fallback;

  /// Optional logical decode dimensions when layout width/height are not the
  /// desired cache target.
  final double? decodeWidth;
  final double? decodeHeight;

  @override
  Widget build(BuildContext context) {
    final normalized = source.trim();
    if (normalized.isEmpty) return fallback ?? const SizedBox.shrink();

    final uri = Uri.tryParse(normalized);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return fallback ?? const SizedBox.shrink();
    }

    final cacheWidth = AppImageDecodePolicy.pixelDimension(
      context,
      decodeWidth ?? width,
    );
    final cacheHeight = AppImageDecodePolicy.pixelDimension(
      context,
      decodeHeight ?? height,
    );

    return Image.network(
      normalized,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      filterQuality: filterQuality,
      gaplessPlayback: gaplessPlayback,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      errorBuilder: (_, __, ___) => fallback ?? const SizedBox.shrink(),
    );
  }
}
