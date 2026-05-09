import 'package:flutter/material.dart';

import 'super_power_panel_page.dart';

class UltraControlCentrePage extends StatelessWidget {
  const UltraControlCentrePage({super.key, required this.currentRole});

  final String currentRole;

  @override
  Widget build(BuildContext context) {
    return SuperPowerPanelPage(currentRole: currentRole);
  }
}
