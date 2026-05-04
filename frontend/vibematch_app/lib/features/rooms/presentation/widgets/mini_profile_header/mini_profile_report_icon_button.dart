import 'package:flutter/material.dart';

import '../mini_profile_decoration.dart';
import '../room_theme.dart';

class MiniProfileReportIconButton extends StatelessWidget {
  const MiniProfileReportIconButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MiniProfileCornerButton(
      icon: Icons.report_gmailerrorred_rounded,
      color: RoomColors.coral,
      size: 32,
      iconSize: 17,
      onTap: onTap,
    );
  }
}
