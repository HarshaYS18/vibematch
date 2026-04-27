import 'package:flutter/material.dart';

import '../../auth/models/current_user.dart';
import 'me_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.currentUser,
    required this.onLogoutPressed,
    required this.onRefreshPressed,
  });

  final CurrentUser currentUser;
  final Future<void> Function() onLogoutPressed;
  final Future<void> Function() onRefreshPressed;

  @override
  Widget build(BuildContext context) {
    return MePage(
      user: currentUser,
      onLogoutPressed: onLogoutPressed,
      onRefreshPressed: onRefreshPressed,
    );
  }
}