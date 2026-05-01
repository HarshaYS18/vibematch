import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class VibeImageSourceSheet extends StatelessWidget {
  const VibeImageSourceSheet({
    super.key,
    this.title = 'Choose image',
    this.subtitle = 'Use camera or gallery. Upload limits are checked before preview.',
    this.showRemove = false,
    this.removeLabel = 'Remove current image',
  });

  final String title;
  final String subtitle;
  final bool showRemove;
  final String removeLabel;

  static Future<VibeImageSourceAction?> show({
    required BuildContext context,
    String title = 'Choose image',
    String subtitle = 'Use camera or gallery. Upload limits are checked before preview.',
    bool showRemove = false,
    String removeLabel = 'Remove current image',
  }) {
    return showModalBottomSheet<VibeImageSourceAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => VibeImageSourceSheet(
        title: title,
        subtitle: subtitle,
        showRemove: showRemove,
        removeLabel: removeLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFE0D5CB),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF12C7B7),
                    Color(0xFF8C5CF6),
                  ],
                ),
              ),
              child: const Icon(
                Icons.add_photo_alternate_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF251538),
                fontSize: 21,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF7B6A86),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            _SourceTile(
              icon: Icons.photo_library_rounded,
              title: 'Gallery',
              subtitle: 'Pick an existing image',
              color: const Color(0xFF12C7B7),
              onTap: () => Navigator.pop(
                context,
                const VibeImageSourceAction.pick(ImageSource.gallery),
              ),
            ),
            const SizedBox(height: 9),
            _SourceTile(
              icon: Icons.photo_camera_rounded,
              title: 'Camera',
              subtitle: 'Take a new photo',
              color: const Color(0xFF8C5CF6),
              onTap: () => Navigator.pop(
                context,
                const VibeImageSourceAction.pick(ImageSource.camera),
              ),
            ),
            if (showRemove) ...[
              const SizedBox(height: 9),
              _SourceTile(
                icon: Icons.delete_outline_rounded,
                title: removeLabel,
                subtitle: 'Clear the selected preview',
                color: const Color(0xFFE84C72),
                onTap: () => Navigator.pop(
                  context,
                  const VibeImageSourceAction.remove(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFF7B6A86),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VibeImageSourceAction {
  const VibeImageSourceAction._({this.source, required this.remove});

  const VibeImageSourceAction.pick(ImageSource source)
      : this._(source: source, remove: false);

  const VibeImageSourceAction.remove() : this._(remove: true);

  final ImageSource? source;
  final bool remove;
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFAF7F1),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFEDE3D7)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(icon, color: color, size: 23),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF251538),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF7B6A86),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF4A2A63),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
