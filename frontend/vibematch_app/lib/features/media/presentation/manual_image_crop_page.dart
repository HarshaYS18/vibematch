import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class ManualImageCropResult {
  const ManualImageCropResult({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.outputWidth,
    required this.outputHeight,
  });

  final int x;
  final int y;
  final int width;
  final int height;
  final int outputWidth;
  final int outputHeight;
}

class ManualImageCropPage extends StatefulWidget {
  const ManualImageCropPage({
    super.key,
    required this.imageBytes,
    required this.title,
    required this.aspectRatio,
    required this.outputWidth,
    required this.outputHeight,
    required this.helpText,
  });

  final Uint8List imageBytes;
  final String title;
  final double aspectRatio;
  final int outputWidth;
  final int outputHeight;
  final String helpText;

  @override
  State<ManualImageCropPage> createState() => _ManualImageCropPageState();
}

class _ManualImageCropPageState extends State<ManualImageCropPage> {
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
    if (decoded == null) {
      throw StateError('Selected image could not be decoded.');
    }
    _decodedImage = decoded;
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _lastFocalPoint = details.localFocalPoint;
    _startScale = _scale;
    _startOffset = _offset;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    final nextScale = (_startScale * details.scale).clamp(1.0, 5.0);
    final delta = _lastFocalPoint == null ? Offset.zero : details.localFocalPoint - _lastFocalPoint!;
    setState(() {
      _scale = nextScale;
      _offset = _startOffset + delta;
    });
  }

  void _zoomBy(double delta) {
    setState(() => _scale = (_scale + delta).clamp(1.0, 5.0));
  }

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
    return Scaffold(
      backgroundColor: const Color(0xFF12101D),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 14, 10),
              child: Row(
                children: [
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28)),
                  Expanded(child: Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900))),
                  TextButton(onPressed: _useCrop, child: const Text('Use Crop', style: TextStyle(color: Color(0xFF12C7B7), fontWeight: FontWeight.w900))),
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
                      borderRadius: BorderRadius.circular(widget.aspectRatio == 1 ? 999 : 22),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
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
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Container(color: Colors.black),
                                Positioned(
                                  left: (cropSize.width - displayWidth) / 2 + _offset.dx,
                                  top: (cropSize.height - displayHeight) / 2 + _offset.dy,
                                  width: displayWidth,
                                  height: displayHeight,
                                  child: Image.memory(widget.imageBytes, fit: BoxFit.fill, filterQuality: FilterQuality.high),
                                ),
                                const _CropGridOverlay(),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _CropToolButton(icon: Icons.remove_rounded, onTap: () => _zoomBy(-0.2)),
                  const SizedBox(width: 10),
                  _CropToolButton(icon: Icons.restart_alt_rounded, onTap: _resetCrop),
                  const SizedBox(width: 10),
                  _CropToolButton(icon: Icons.add_rounded, onTap: () => _zoomBy(0.2)),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 18 + MediaQuery.paddingOf(context).bottom),
              child: Text(widget.helpText, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.35)),
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
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 46,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _CropGridOverlay extends StatelessWidget {
  const _CropGridOverlay();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _CropGridPainter());
  }
}

class _CropGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.62)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;
    canvas.drawRect(Offset.zero & size, paint);
    canvas.drawLine(Offset(size.width / 3, 0), Offset(size.width / 3, size.height), paint);
    canvas.drawLine(Offset(size.width * 2 / 3, 0), Offset(size.width * 2 / 3, size.height), paint);
    canvas.drawLine(Offset(0, size.height / 3), Offset(size.width, size.height / 3), paint);
    canvas.drawLine(Offset(0, size.height * 2 / 3), Offset(size.width, size.height * 2 / 3), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
