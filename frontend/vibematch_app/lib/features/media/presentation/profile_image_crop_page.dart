import 'dart:typed_data';

import 'package:flutter/material.dart';

class ProfileImageCropPage extends StatelessWidget {
  const ProfileImageCropPage({
    super.key,
    required this.imageBytes,
    required this.title,
    required this.aspectRatio,
    required this.helpText,
  });

  final Uint8List imageBytes;
  final String title;
  final double aspectRatio;
  final String helpText;

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
                  IconButton(onPressed: () => Navigator.pop(context, false), icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28)),
                  Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900))),
                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Use Crop', style: TextStyle(color: Color(0xFF12C7B7), fontWeight: FontWeight.w900))),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: AspectRatio(
                    aspectRatio: aspectRatio,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(aspectRatio == 1 ? 999 : 22),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(imageBytes, fit: BoxFit.cover, alignment: Alignment.center, filterQuality: FilterQuality.high),
                          const _CropGridOverlay(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 18 + MediaQuery.paddingOf(context).bottom),
              child: Text(helpText, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.35)),
            ),
          ],
        ),
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
