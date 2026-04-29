import 'package:flutter/material.dart';

class LiveRoomSheetController {
  const LiveRoomSheetController._();

  static Future<T?> showTransparentSheet<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isScrollControlled = false,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      builder: builder,
    );
  }

  static Future<T?> showTransparentStatefulSheet<T>({
    required BuildContext context,
    required Widget Function(BuildContext sheetContext, StateSetter setSheetState) builder,
    bool isScrollControlled = false,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) => builder(sheetContext, setSheetState),
        );
      },
    );
  }
}
