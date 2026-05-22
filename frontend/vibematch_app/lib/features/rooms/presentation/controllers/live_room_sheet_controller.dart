import 'package:flutter/material.dart';

import '../../../../core/ui/vm_motion.dart';

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
      sheetAnimationStyle: VmMotion.sheetAnimationStyle,
      builder: (sheetContext) => VmFadeSlide(child: builder(sheetContext)),
    );
  }

  static Future<T?> showTransparentStatefulSheet<T>({
    required BuildContext context,
    required Widget Function(
      BuildContext sheetContext,
      StateSetter setSheetState,
    )
    builder,
    bool isScrollControlled = false,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: VmMotion.sheetAnimationStyle,
      builder: (sheetContext) {
        return VmFadeSlide(
          child: StatefulBuilder(
            builder: (context, setSheetState) =>
                builder(sheetContext, setSheetState),
          ),
        );
      },
    );
  }
}
