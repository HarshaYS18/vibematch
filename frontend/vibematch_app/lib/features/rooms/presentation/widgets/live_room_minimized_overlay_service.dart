import 'package:flutter/material.dart';

class LiveRoomMinimizedOverlayService extends ChangeNotifier {
  LiveRoomMinimizedOverlayService._();

  static final LiveRoomMinimizedOverlayService instance =
      LiveRoomMinimizedOverlayService._();

  Offset _offset = const Offset(24, 120);
  VoidCallback? _onRestore;

  Offset get offset => _offset;
  bool get isShowing => _onRestore != null;

  static void show({
    required BuildContext context,
    required VoidCallback onRestore,
    Offset? initialOffset,
  }) {
    instance._show(onRestore, initialOffset: initialOffset);
  }

  static void hide() {
    instance._hide();
  }

  void updateOffset(Offset offset) {
    _offset = offset;
    notifyListeners();
  }

  void restore() {
    final callback = _onRestore;
    _hide();
    callback?.call();
  }

  void _show(VoidCallback onRestore, {Offset? initialOffset}) {
    if (initialOffset != null) _offset = initialOffset;
    _onRestore = onRestore;
    notifyListeners();
  }

  void _hide() {
    if (_onRestore == null) return;
    _onRestore = null;
    notifyListeners();
  }
}
