import 'package:flutter/material.dart';

class LeaveSeatIcon extends StatelessWidget {
  const LeaveSeatIcon({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 3,
            top: 1,
            child: Icon(Icons.mic_external_on_rounded, color: color, size: 20),
          ),
          Positioned(
            right: 1,
            bottom: 1,
            child: Icon(Icons.keyboard_arrow_down_rounded, color: color, size: 18),
          ),
        ],
      ),
    );
  }
}
