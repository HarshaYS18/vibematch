import 'package:flutter/material.dart';

import 'live_room_minimized_bubble.dart';

class LiveRoomMinimizedOverlayService {
  LiveRoomMinimizedOverlayService._();

  static OverlayEntry? _entry;
  static Offset _offset = const Offset(24, 120);

  static bool get isShowing => _entry != null;

  static void show({
    required BuildContext context,
    required VoidCallback onRestore,
  }) {
    hide();

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

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
  }

  static void hide() {
    _entry?.remove();
    _entry = null;
  }
}
