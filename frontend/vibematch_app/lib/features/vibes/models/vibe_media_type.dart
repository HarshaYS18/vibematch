import 'package:flutter/material.dart';

enum VibeMediaType {
  photo,
  video,
  text,
}

extension VibeMediaTypeX on VibeMediaType {
  String get label {
    switch (this) {
      case VibeMediaType.photo:
        return 'Photo';
      case VibeMediaType.video:
        return 'Video';
      case VibeMediaType.text:
        return 'Text';
    }
  }

  IconData get icon {
    switch (this) {
      case VibeMediaType.photo:
        return Icons.photo_rounded;
      case VibeMediaType.video:
        return Icons.play_circle_fill_rounded;
      case VibeMediaType.text:
        return Icons.notes_rounded;
    }
  }

  List<Color> get colors {
    switch (this) {
      case VibeMediaType.photo:
        return const [Color(0xFF6D5DF6), Color(0xFFE84C72)];
      case VibeMediaType.video:
        return const [Color(0xFF12C7B7), Color(0xFF6D5DF6)];
      case VibeMediaType.text:
        return const [Color(0xFFC99A3B), Color(0xFFE84C72)];
    }
  }
}
