import 'package:flutter/material.dart';

import '../network/vm_failure.dart';
import '../ui/vm_motion.dart';

class VmLoadingState extends StatelessWidget {
  const VmLoadingState({
    super.key,
    this.message = 'Loading…',
    this.compact = false,
  });

  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: compact ? 22 : 30,
          height: compact ? 22 : 30,
          child: const CircularProgressIndicator(
            strokeWidth: 2.4,
            color: Color(0xFF6D5DF6),
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF7B6A86),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );

    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 10 : 24),
        child: VmFadeSlide(
          beginOffset: const Offset(0, 0.025),
          beginScale: 0.99,
          child: content,
        ),
      ),
    );
  }
}

class VmFailureState extends StatelessWidget {
  const VmFailureState({
    super.key,
    this.error,
    this.message,
    this.contentLabel = 'content',
    this.onRetry,
    this.compact = false,
  });

  final Object? error;
  final String? message;
  final String contentLabel;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final failure = VmFailurePresentation.from(
      error ?? message,
      contentLabel: contentLabel,
    );
    final retry = failure.retryable ? onRetry : null;

    if (compact) {
      return VmInlineFailure(
        message: failure.message,
        onRetry: retry,
        icon: _iconFor(failure.kind),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        physics: const BouncingScrollPhysics(),
        child: VmFadeSlide(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFEDE3D7)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF251538).withValues(alpha: 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4EEFF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      _iconFor(failure.kind),
                      color: const Color(0xFF6D5DF6),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    failure.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF251538),
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    failure.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF7B6A86),
                      fontSize: 12.5,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (retry != null) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: retry,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF251538),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 17,
                          vertical: 11,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text(
                        'Try again',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(VmFailureKind kind) {
    return switch (kind) {
      VmFailureKind.offline => Icons.wifi_off_rounded,
      VmFailureKind.timeout => Icons.schedule_rounded,
      VmFailureKind.unauthenticated => Icons.lock_clock_rounded,
      VmFailureKind.forbidden => Icons.lock_outline_rounded,
      VmFailureKind.notFound => Icons.search_off_rounded,
      VmFailureKind.rateLimited => Icons.hourglass_top_rounded,
      VmFailureKind.server => Icons.cloud_off_rounded,
      VmFailureKind.cancelled => Icons.cancel_outlined,
      VmFailureKind.unknown => Icons.refresh_rounded,
    };
  }
}

class VmInlineFailure extends StatelessWidget {
  const VmInlineFailure({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.wifi_off_rounded,
  });

  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return VmFadeSlide(
      beginOffset: const Offset(0, 0.018),
      beginScale: 0.995,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        padding: const EdgeInsets.fromLTRB(13, 11, 10, 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE8C77C)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFC99A3B), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                VmFailurePresentation.from(message).message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF7B6A86),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: const Text(
                  'Retry',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class VmEmptyState extends StatelessWidget {
  const VmEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: VmFadeSlide(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xFF6D5DF6).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(icon, color: const Color(0xFF6D5DF6), size: 31),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF251538),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF7B6A86),
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 14),
                TextButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
