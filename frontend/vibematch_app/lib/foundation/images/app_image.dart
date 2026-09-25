import 'package:flutter/material.dart';

/// Shared decode policy for network and asset images.
///
/// Small UI surfaces should decode close to their physical render size instead
/// of retaining full-resolution user uploads in the Flutter image cache.
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

enum _AppImageSourceType { network, asset }

/// Canonical image widget for high-frequency FunKey presentation surfaces.
///
/// AppImage intentionally relies on Flutter's native ImageCache. Chunk 34-M5
/// coordinates shared cache pressure; this widget adds bounded decode sizing
/// and consistent fallback behavior.
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
  }) : source = url,
       _sourceType = _AppImageSourceType.network;

  const AppImage.asset(
    String assetPath, {
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
  }) : source = assetPath,
       _sourceType = _AppImageSourceType.asset;

  final String source;
  final _AppImageSourceType _sourceType;
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

    final cacheWidth = AppImageDecodePolicy.pixelDimension(
      context,
      decodeWidth ?? width,
    );
    final cacheHeight = AppImageDecodePolicy.pixelDimension(
      context,
      decodeHeight ?? height,
    );

    Widget onError(BuildContext _, Object __, StackTrace? ___) =>
        fallback ?? const SizedBox.shrink();

    switch (_sourceType) {
      case _AppImageSourceType.network:
        final uri = Uri.tryParse(normalized);
        if (uri == null ||
            (uri.scheme != 'http' && uri.scheme != 'https')) {
          return fallback ?? const SizedBox.shrink();
        }
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
          errorBuilder: onError,
        );
      case _AppImageSourceType.asset:
        return Image.asset(
          normalized,
          width: width,
          height: height,
          fit: fit,
          alignment: alignment,
          filterQuality: filterQuality,
          gaplessPlayback: gaplessPlayback,
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
          errorBuilder: onError,
        );
    }
  }
}
