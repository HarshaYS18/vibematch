part of 'public_profile_view_page.dart';

PublicVibeItem _publicVibeItemFromDto(ProfileVibeDto dto) {
  final mediaType = dto.mediaType.trim().toLowerCase();
  final icon = switch (mediaType) {
    'photo' => Icons.photo_rounded,
    'video' => Icons.play_circle_fill_rounded,
    _ => Icons.notes_rounded,
  };

  final colors = switch (mediaType) {
    'photo' => const <Color>[Color(0xFF6D5DF6), Color(0xFFE84C72)],
    'video' => const <Color>[Color(0xFF12C7B7), Color(0xFF6D5DF6)],
    _ => const <Color>[Color(0xFF251538), Color(0xFFC99A3B)],
  };

  return PublicVibeItem(
    title: dto.title,
    mediaType: mediaType.isEmpty ? 'text' : mediaType,
    timeAgo: dto.timeAgo,
    body: dto.caption.trim().isEmpty ? 'Shared a Vibe.' : dto.caption.trim(),
    likes: dto.likesLabel,
    comments: dto.commentsLabel,
    icon: icon,
    colors: colors,
    mediaUrl: dto.mediaUrl,
  );
}

class _PublicVibesEmptyState extends StatelessWidget {
  const _PublicVibesEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 28),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFECE2D8)),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, color: Color(0xFF6D5DF6), size: 34),
          SizedBox(height: 8),
          Text(
            'No Vibes yet',
            style: TextStyle(
              color: Color(0xFF251538),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'When this user posts real Vibes, they will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF7B6A86),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _PublicProfileBackendError extends StatelessWidget {
  const _PublicProfileBackendError({
    required this.message,
    required this.onRetry,
  });
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(18, 8, 18, 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE8C77C)),
    ),
    child: Row(
      children: [
        const Icon(Icons.wifi_off_rounded, color: Color(0xFFC99A3B), size: 19),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF7B6A86),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        TextButton(
          onPressed: onRetry,
          child: const Text(
            'Retry',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    ),
  );
}
