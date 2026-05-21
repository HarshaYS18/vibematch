import 'package:flutter/material.dart';

class FunKeyChatInputBar extends StatelessWidget {
  const FunKeyChatInputBar({
    super.key,
    required this.readOnly,
    this.driftMode = false,
    this.showDriftHint = false,
    this.onDriftSwipe,
    required this.controller,
    required this.recordingVoice,
    required this.sendingVoice,
    required this.onAttachTap,
    required this.onEmojiTap,
    required this.onVoiceTap,
    required this.onVoiceLongPressStart,
    required this.onVoiceLongPressEnd,
    required this.onVoiceLongPressCancel,
    required this.onSendTap,
  });

  final bool readOnly;
  final bool driftMode;
  final bool showDriftHint;
  final VoidCallback? onDriftSwipe;
  final TextEditingController controller;
  final bool recordingVoice;
  final bool sendingVoice;
  final VoidCallback onAttachTap;
  final VoidCallback onEmojiTap;
  final VoidCallback onVoiceTap;
  final VoidCallback onVoiceLongPressStart;
  final VoidCallback onVoiceLongPressEnd;
  final VoidCallback onVoiceLongPressCancel;
  final VoidCallback onSendTap;

  static const _ink = Color(0xFF111114);
  static const _muted = Color(0xFF71717A);
  static const _line = Color(0xFFEDEDEF);
  static const _blue = Color(0xFF3797F0);
  static const _rose = Color(0xFFE84C72);

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.trim().isNotEmpty;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(8, 7, 8, 7 + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (driftMode && showDriftHint)
            GestureDetector(
              onHorizontalDragEnd: (_) => onDriftSwipe?.call(),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 7),
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFDBA74)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.timer_rounded, color: Color(0xFFEA580C), size: 16),
                    SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Secret Drift is on. Swipe this hint to refresh the timer.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF7C2D12),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(Icons.swipe_rounded, color: Color(0xFFEA580C), size: 15),
                  ],
                ),
              ),
            ),
          Row(
            children: [
              _InputIcon(
                icon: Icons.emoji_emotions_outlined,
                onTap: readOnly ? null : onEmojiTap,
              ),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 42, maxHeight: 96),
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F4F5),
                    borderRadius: BorderRadius.circular(21),
                  ),
                  child: TextField(
                    controller: controller,
                    enabled: !readOnly,
                    minLines: 1,
                    maxLines: 4,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: readOnly ? 'Replies disabled' : 'Message...',
                      hintStyle: const TextStyle(
                        color: _muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              _InputIcon(
                icon: Icons.add_circle_outline_rounded,
                onTap: readOnly ? null : onAttachTap,
              ),
              GestureDetector(
                onTap: readOnly ? null : onVoiceTap,
                onLongPressStart: readOnly || sendingVoice
                    ? null
                    : (_) => onVoiceLongPressStart(),
                onLongPressEnd: readOnly || sendingVoice
                    ? null
                    : (_) => onVoiceLongPressEnd(),
                onLongPressCancel:
                    readOnly || sendingVoice ? null : onVoiceLongPressCancel,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: recordingVoice ? _rose : const Color(0xFFF4F4F5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    sendingVoice
                        ? Icons.hourglass_top_rounded
                        : recordingVoice
                            ? Icons.stop_rounded
                            : Icons.mic_rounded,
                    color: recordingVoice ? Colors.white : _ink,
                    size: 20,
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: readOnly || !hasText ? null : onSendTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: readOnly || !hasText ? const Color(0xFFE4E4E7) : _blue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InputIcon extends StatelessWidget {
  const _InputIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
      icon: Icon(
        icon,
        color: onTap == null ? const Color(0xFFD4D4D8) : FunKeyChatInputBar._ink,
        size: 22,
      ),
    );
  }
}
