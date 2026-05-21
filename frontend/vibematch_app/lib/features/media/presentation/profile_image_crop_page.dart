import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import 'manual_image_crop_page.dart';

class ProfileImageCropPage extends StatefulWidget {
  const ProfileImageCropPage({
    super.key,
    required this.imageBytes,
    required this.title,
    required this.aspectRatio,
    required this.helpText,
    required this.outputWidth,
    required this.outputHeight,
  });

  final Uint8List imageBytes;
  final String title;
  final double aspectRatio;
  final String helpText;
  final int outputWidth;
  final int outputHeight;

  @override
  State<ProfileImageCropPage> createState() => _ProfileImageCropPageState();
}

class _ProfileImageCropPageState extends State<ProfileImageCropPage> {
  final GlobalKey _cropKey = GlobalKey();
  late final img.Image _decodedImage;
  double _scale = 1;
  Offset _offset = Offset.zero;
  Offset? _lastFocalPoint;
  double _startScale = 1;
  Offset _startOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    final decoded = img.decodeImage(widget.imageBytes);
    if (decoded == null) throw StateError('Selected image could not be decoded.');
    _decodedImage = decoded;
  }

  bool get _isAvatar => (widget.aspectRatio - 1).abs() < 0.01;

  void _handleScaleStart(ScaleStartDetails details) {
    _lastFocalPoint = details.localFocalPoint;
    _startScale = _scale;
    _startOffset = _offset;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    final delta = _lastFocalPoint == null ? Offset.zero : details.localFocalPoint - _lastFocalPoint!;
    setState(() {
      _scale = (_startScale * details.scale).clamp(1.0, 6.0).toDouble();
      _offset = _startOffset + delta;
    });
  }

  void _zoomBy(double delta) => setState(() => _scale = (_scale + delta).clamp(1.0, 6.0).toDouble());

  void _resetCrop() {
    setState(() {
      _scale = 1;
      _offset = Offset.zero;
    });
  }

  ManualImageCropResult _buildResult(Size cropSize) {
    final sourceWidth = _decodedImage.width.toDouble();
    final sourceHeight = _decodedImage.height.toDouble();
    final baseScale = max(cropSize.width / sourceWidth, cropSize.height / sourceHeight);
    final totalScale = baseScale * _scale;
    final displayedWidth = sourceWidth * totalScale;
    final displayedHeight = sourceHeight * totalScale;
    final left = (cropSize.width - displayedWidth) / 2 + _offset.dx;
    final top = (cropSize.height - displayedHeight) / 2 + _offset.dy;
    final rawX = (-left / totalScale).clamp(0.0, sourceWidth - 1);
    final rawY = (-top / totalScale).clamp(0.0, sourceHeight - 1);
    final rawWidth = (cropSize.width / totalScale).clamp(1.0, sourceWidth - rawX);
    final rawHeight = (cropSize.height / totalScale).clamp(1.0, sourceHeight - rawY);
    return ManualImageCropResult(
      x: rawX.round(),
      y: rawY.round(),
      width: max(1, rawWidth.round()),
      height: max(1, rawHeight.round()),
      outputWidth: widget.outputWidth,
      outputHeight: widget.outputHeight,
    );
  }

  void _useCrop() {
    final box = _cropKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || box.size.isEmpty) return;
    Navigator.pop(context, _buildResult(box.size));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: const Color(0xFF070611),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 14, 8),
              child: Row(
                children: [
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28)),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
                      const Text('Pinch, drag, zoom and frame it perfectly', style: TextStyle(color: Color(0xFFB9ADC8), fontSize: 12, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  InkWell(
                    onTap: _useCrop,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFFD36E), Color(0xFFFF9A5C)]),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [BoxShadow(color: const Color(0xFFFFD36E).withValues(alpha: 0.22), blurRadius: 18)],
                      ),
                      child: const Text('Use', style: TextStyle(color: Color(0xFF251538), fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: AspectRatio(
                    aspectRatio: widget.aspectRatio,
                    child: ClipRRect(
                      key: _cropKey,
                      borderRadius: BorderRadius.circular(_isAvatar ? 999 : 28),
                      child: LayoutBuilder(builder: (context, constraints) {
                        final cropSize = Size(constraints.maxWidth, constraints.maxHeight);
                        final sourceWidth = _decodedImage.width.toDouble();
                        final sourceHeight = _decodedImage.height.toDouble();
                        final baseScale = max(cropSize.width / sourceWidth, cropSize.height / sourceHeight);
                        final totalScale = baseScale * _scale;
                        final displayWidth = sourceWidth * totalScale;
                        final displayHeight = sourceHeight * totalScale;
                        return GestureDetector(
                          onScaleStart: _handleScaleStart,
                          onScaleUpdate: _handleScaleUpdate,
                          child: Stack(fit: StackFit.expand, children: [
                            Container(color: Colors.black),
                            Positioned(
                              left: (cropSize.width - displayWidth) / 2 + _offset.dx,
                              top: (cropSize.height - displayHeight) / 2 + _offset.dy,
                              width: displayWidth,
                              height: displayHeight,
                              child: Image.memory(widget.imageBytes, fit: BoxFit.fill, filterQuality: FilterQuality.high),
                            ),
                            const _DimEdges(),
                            _BigoCropOverlay(isAvatar: _isAvatar),
                          ]),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _CropToolButton(icon: Icons.remove_rounded, onTap: () => _zoomBy(-0.2)),
                const SizedBox(width: 10),
                _CropToolButton(icon: Icons.restart_alt_rounded, onTap: _resetCrop),
                const SizedBox(width: 10),
                _CropToolButton(icon: Icons.add_rounded, onTap: () => _zoomBy(0.2)),
              ]),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 18 + bottom),
              child: Text(widget.helpText, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFB9ADC8), fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.35)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CropToolButton extends StatelessWidget {
  const _CropToolButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Container(
      width: 48,
      height: 44,
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withValues(alpha: 0.14))),
      child: Icon(icon, color: Colors.white, size: 23),
    ),
  );
}

class _DimEdges extends StatelessWidget {
  const _DimEdges();
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(colors: [Colors.transparent, Colors.black.withValues(alpha: 0.15)], radius: 0.95),
    ),
  );
}

class _BigoCropOverlay extends StatelessWidget {
  const _BigoCropOverlay({required this.isAvatar});
  final bool isAvatar;
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _BigoCropPainter(isAvatar: isAvatar));
}

class _BigoCropPainter extends CustomPainter {
  _BigoCropPainter({required this.isAvatar});
  final bool isAvatar;
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = Colors.white.withValues(alpha: 0.42)..strokeWidth = 1;
    final border = Paint()..color = const Color(0xFFFFD36E)..strokeWidth = 2.2..style = PaintingStyle.stroke;
    final glow = Paint()..color = const Color(0xFFFFD36E).withValues(alpha: 0.22)..strokeWidth = 7..style = PaintingStyle.stroke;
    final rect = Offset.zero & size;
    if (isAvatar) {
      canvas.drawOval(rect.deflate(2), glow);
      canvas.drawOval(rect.deflate(2), border);
    } else {
      final rrect = RRect.fromRectAndRadius(rect.deflate(1), const Radius.circular(26));
      canvas.drawRRect(rrect, glow);
      canvas.drawRRect(rrect, border);
    }
    canvas.drawLine(Offset(size.width / 3, 0), Offset(size.width / 3, size.height), grid);
    canvas.drawLine(Offset(size.width * 2 / 3, 0), Offset(size.width * 2 / 3, size.height), grid);
    canvas.drawLine(Offset(0, size.height / 3), Offset(size.width, size.height / 3), grid);
    canvas.drawLine(Offset(0, size.height * 2 / 3), Offset(size.width, size.height * 2 / 3), grid);
  }
  @override
  bool shouldRepaint(covariant _BigoCropPainter oldDelegate) => oldDelegate.isAvatar != isAvatar;
}
