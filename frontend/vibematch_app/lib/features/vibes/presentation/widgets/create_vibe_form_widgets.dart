import 'package:flutter/material.dart';

import '../../controllers/vibe_mention_controller.dart';

enum CreateVibeMode { media, text }

class CreateVibeTypeTabs extends StatelessWidget {
  const CreateVibeTypeTabs({super.key, required this.selectedMode, required this.onSelected});

  final CreateVibeMode selectedMode;
  final ValueChanged<CreateVibeMode> onSelected;

  @override
  Widget build(BuildContext context) {
    const items = [CreateVibeMode.media, CreateVibeMode.text];
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: items.map((mode) {
          final selected = mode == selectedMode;
          final label = mode == CreateVibeMode.media ? 'Media' : 'Text';
          return Expanded(
            child: InkWell(
              onTap: () => onSelected(mode),
              borderRadius: BorderRadius.circular(999),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF111015) : const Color(0xFFF7F3EF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF111015),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class CreateVibeCaptionBox extends StatelessWidget {
  const CreateVibeCaptionBox({
    super.key,
    required this.controller,
    required this.commentsEnabled,
    required this.onToggleComments,
  });

  final VibeMentionTextController controller;
  final bool commentsEnabled;
  final VoidCallback onToggleComments;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFECE2D8)))),
      child: Column(
        children: [
          TextField(
            controller: controller,
            maxLines: 5,
            minLines: 3,
            style: const TextStyle(color: Color(0xFF111015), fontSize: 15, fontWeight: FontWeight.w600, height: 1.35),
            decoration: const InputDecoration(
              hintText: 'Write a caption... use @name or @all',
              hintStyle: TextStyle(color: Color(0xFFAAA1AE), fontWeight: FontWeight.w600),
              border: InputBorder.none,
            ),
          ),
          Row(
            children: [
              const Icon(Icons.mode_comment_outlined, color: Color(0xFF111015), size: 18),
              const SizedBox(width: 8),
              const Expanded(child: Text('Allow comments', style: TextStyle(color: Color(0xFF111015), fontSize: 13, fontWeight: FontWeight.w900))),
              Switch(value: commentsEnabled, onChanged: (_) => onToggleComments(), activeThumbColor: const Color(0xFF111015)),
            ],
          ),
        ],
      ),
    );
  }
}

class CreateVibeMentionRow extends StatelessWidget {
  const CreateVibeMentionRow({
    super.key,
    required this.usesMentionAll,
    required this.mentions,
    required this.commentsEnabled,
    required this.canUseMentionAllToday,
  });

  final bool usesMentionAll;
  final List<String> mentions;
  final bool commentsEnabled;
  final bool canUseMentionAllToday;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (usesMentionAll) _SmallChip(text: canUseMentionAllToday ? '@all' : '@all limit reached'),
          ...mentions.map((mention) => _SmallChip(text: '@$mention')),
          _SmallChip(text: commentsEnabled ? 'Comments on' : 'Comments off'),
        ],
      ),
    );
  }
}

class CreateVibeShareButton extends StatelessWidget {
  const CreateVibeShareButton({super.key, required this.enabled, required this.busy, required this.onTap});

  final bool enabled;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFF111015) : const Color(0xFFE4DFE8),
          borderRadius: BorderRadius.circular(14),
        ),
        child: busy
            ? const SizedBox(width: 19, height: 19, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2))
            : Text(
                'Share Vibe',
                style: TextStyle(color: enabled ? Colors.white : const Color(0xFF8C8198), fontWeight: FontWeight.w900),
              ),
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: const Color(0xFFF2EEF4), borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: const TextStyle(color: Color(0xFF111015), fontSize: 11, fontWeight: FontWeight.w900)),
    );
  }
}
