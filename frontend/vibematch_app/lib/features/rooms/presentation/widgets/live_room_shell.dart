import 'package:flutter/material.dart';

import 'room_theme.dart';

class LiveRoomShell extends StatelessWidget {
  const LiveRoomShell({
    super.key,
    required this.canPop,
    required this.onPopInvokedWithResult,
    required this.backgroundTheme,
    required this.onDismissOverlays,
    required this.children,
  });

  final bool canPop;
  final PopInvokedWithResultCallback<void> onPopInvokedWithResult;
  final RoomBackgroundTheme backgroundTheme;
  final VoidCallback onDismissOverlays;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: canPop,
      onPopInvokedWithResult: onPopInvokedWithResult,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: RoomColors.deep,
        body: Stack(
          children: [
            Positioned.fill(child: RoomBackground(theme: backgroundTheme)),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: onDismissOverlays,
                child: const SizedBox.expand(),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class LiveRoomMinimizedPassthrough extends StatelessWidget {
  const LiveRoomMinimizedPassthrough({
    super.key,
    required this.canPop,
    required this.onPopInvokedWithResult,
  });

  final bool canPop;
  final PopInvokedWithResultCallback<void> onPopInvokedWithResult;

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: canPop,
      onPopInvokedWithResult: onPopInvokedWithResult,
      child: const IgnorePointer(child: SizedBox.expand()),
    );
  }
}
