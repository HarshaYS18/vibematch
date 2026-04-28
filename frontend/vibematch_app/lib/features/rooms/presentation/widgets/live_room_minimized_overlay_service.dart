import 'dart:async';

import 'package:flutter/material.dart';

import 'live_room_minimized_bubble.dart';

class LiveRoomMinimizedOverlayService {
  LiveRoomMinimizedOverlayService._();

  static OverlayEntry? _entry;
  static Timer? _insertTimer;
  static Offset _offset = const Offset(24, 120);

  static bool get isShowing => _entry != null || _insertTimer != null;

  static void show({
    required BuildContext context,
    required VoidCallback onRestore,
  }) {
    hide();

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    // The leave bottom sheet is being dismissed at the same moment Stay is tapped.
    // Insert the bubble after that pop finishes so the overlay is placed above
    // the previous active tab/screen, not inside the closing room sheet stack.
    _insertTimer = Timer(const Duration(milliseconds: 180), () {
      _insertTimer = null;

      _entry = OverlayEntry(
        builder: (overlayContext) {
          final size = MediaQuery.sizeOf(overlayContext);

          return Material(
            type: MaterialType.transparency,
            child: Stack(
              children: [
                LiveRoomMinimizedBubble(
                  offset: _offset,
                  onRestore: () {
                    hide();
                    onRestore();
                  },
                  onDrag: (details) {
                    _offset = Offset(
                      (_offset.dx + details.delta.dx).clamp(
                        8.0,
                        size.width - 86,
                      ),
                      (_offset.dy + details.delta.dy).clamp(
                        40.0,
                        size.height - 120,
                      ),
                    );

                    _entry?.markNeedsBuild();
                  },
                ),
              ],
            ),
          );
        },
      );

      overlay.insert(_entry!);
    });
  }

  static void hide() {
    _insertTimer?.cancel();
    _insertTimer = null;
    _entry?.remove();
    _entry = null;
  }
}
