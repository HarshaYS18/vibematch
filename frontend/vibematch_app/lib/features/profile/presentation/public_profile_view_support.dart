part of 'public_profile_view_page.dart';

class _PublicProfileBackendError extends StatelessWidget {
  const _PublicProfileBackendError({
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
