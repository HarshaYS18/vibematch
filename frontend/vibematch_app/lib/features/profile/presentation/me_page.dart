import 'package:flutter/material.dart';

import '../../auth/models/current_user.dart';
import 'widgets/me_page_content.dart';

class MePage extends StatelessWidget {
  const MePage({
    super.key,
    required this.user,
    required this.onLogoutPressed,
    required this.onRefreshPressed,
  });

  final CurrentUser user;
  final Future<void> Function() onLogoutPressed;
  final Future<void> Function() onRefreshPressed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: MePageContent(
          user: user,
          onLogoutPressed: onLogoutPressed,
          onRefreshPressed: onRefreshPressed,
        ),
      ),
    );
  }
}
