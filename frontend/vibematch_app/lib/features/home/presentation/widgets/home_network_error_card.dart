import 'package:flutter/material.dart';

import '../../../../core/presentation/vm_async_state.dart';

class HomeNetworkErrorCard extends StatelessWidget {
  const HomeNetworkErrorCard({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return VmInlineFailure(
      message: message,
      onRetry: onRetry,
    );
  }
}
