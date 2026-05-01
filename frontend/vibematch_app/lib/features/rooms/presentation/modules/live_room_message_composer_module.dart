import 'package:flutter/material.dart';

import '../../../../core/media/image_picker_service.dart';
import '../../../../core/media/image_source_sheet.dart';
import '../widgets/room_seats.dart';
import '../widgets/room_theme.dart';

class LiveRoomMessageComposerModule extends StatefulWidget {
  const LiveRoomMessageComposerModule({
    super.key,
    required this.controller,
    this.focusNode,
    required this.imagesEnabled,
    required this.onSendText,
    required this.onImageTap,
    required this.onSendFloatingText,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool imagesEnabled;
  final VoidCallback onSendText;
  final VoidCallback onImageTap;
  final VoidCallback onSendFloatingText;

  static const int floatingTextCoinCost = 1000;
  static const int floatingTextCharacterLimit = 50;

  @override
  State<LiveRoomMessageComposerModule> createState() =>
      _LiveRoomMessageComposerModuleState();
}

class _LiveRoomMessageComposerModuleState
    extends State<LiveRoomMessageComposerModule> {
  final VibeImagePickerService _imagePickerService = VibeImagePickerService();

  bool _floatingMode = false;

  bool get _hasText => widget.controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.focusNode?.requestFocus();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChanged);
    super.dispose();
  }

  void _handleTextChanged() {
    if (mounted) setState(() {});
  }

  void _toggleFloatingMode() {
    dismissRoomSeatActionPill();
    setState(() {
      _floatingMode = !_floatingMode;
      if (_floatingMode &&
          widget.controller.text.length >
              LiveRoomMessageComposerModule.floatingTextCharacterLimit) {
        widget.controller.text = widget.controller.text.substring(
          0,
          LiveRoomMessageComposerModule.floatingTextCharacterLimit,
        );
        widget.controller.selection = TextSelection.collapsed(
          offset: widget.controller.text.length,
        );
      }
    });
  }

  void _send() {
    dismissRoomSeatActionPill();

    final text = widget.controller.text.trim();
    if (text.isEmpty) {
      RoomToast.show(context, 'Type a message first');
      return;
    }

    if (_floatingMode) {
      if (text.length >
          LiveRoomMessageComposerModule.floatingTextCharacterLimit) {
        RoomToast.show(
          context,
          'Floating message limit is ${LiveRoomMessageComposerModule.floatingTextCharacterLimit} characters',
        );
        return;
      }

      RoomToast.show(
        context,
        'Floating message • ${LiveRoomMessageComposerModule.floatingTextCoinCost} coins',
      );
      widget.onSendFloatingText();
      Navigator.maybePop(context);
      return;
    }

    widget.onSendText();
    Navigator.maybePop(context);
  }

  Future<void> _handleImageTap() async {
    dismissRoomSeatActionPill();

    if (!widget.imagesEnabled) {
      RoomToast.show(context, 'Image messages are disabled in this room');
      return;
    }

    widget.focusNode?.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();

    final action = await VibeImageSourceSheet.show(
      context: context,
      title: 'Send image',
      subtitle:
          'Choose an image for room chat. Local image bubbles work now; backend CDN upload is next.',
    );

    if (!mounted || action == null || action.remove) return;

    final source = action.source;
    if (source == null) return;

    final result = await _imagePickerService.pickImage(
      source: source,
      maxBytes: VibeImagePickerService.roomImageMaxBytes,
    );

    if (!mounted) return;

    if (result.cancelled) return;

    if (result.hasError) {
      RoomToast.show(context, result.errorMessage!);
      return;
    }

    final image = result.image;
    if (image == null) return;

    widget.controller.text = _localImageMessagePayload(image);
    widget.onSendText();
    widget.controller.clear();

    Navigator.maybePop(context);
  }

  String _localImageMessagePayload(PickedVibeImage image) {
    return 'vm-local-image://${Uri.encodeComponent(image.file.path)}'
        '?name=${Uri.encodeComponent(image.displayName)}'
        '&size=${image.sizeBytes}';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final currentLength = widget.controller.text.length;
    final overLimit = _floatingMode &&
        currentLength >
            LiveRoomMessageComposerModule.floatingTextCharacterLimit;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          12,
          10,
          12,
          bottomInset > 0 ? 10 : bottomPadding + 10,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 24,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _QuickMessageRow(
              onPick: (text) {
                widget.controller.text = text;
                widget.controller.selection = TextSelection.collapsed(
                  offset: widget.controller.text.length,
                );

                if (_floatingMode) {
                  widget.onSendFloatingText();
                } else {
                  widget.onSendText();
                }

                Navigator.maybePop(context);
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _ComposerRoundButton(
                  icon: Icons.image_rounded,
                  enabled: widget.imagesEnabled,
                  active: widget.imagesEnabled,
                  disabledTooltip: 'Images disabled',
                  onTap: _handleImageTap,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 46),
                    padding: const EdgeInsets.only(left: 13, right: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F5F8),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: _floatingMode
                            ? RoomColors.gold.withValues(alpha: 0.36)
                            : const Color(0xFFE8E3EC),
                      ),
                    ),
                    child: Row(
                      children: [
                        _FloatingModeToggleButton(
                          selected: _floatingMode,
                          onTap: _toggleFloatingMode,
                          compact: true,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: TextField(
                            controller: widget.controller,
                            focusNode: widget.focusNode,
                            maxLength: _floatingMode
                                ? LiveRoomMessageComposerModule
                                    .floatingTextCharacterLimit
                                : null,
                            buildCounter: (
                              context, {
                              required currentLength,
                              required isFocused,
                              required maxLength,
                            }) =>
                                null,
                            minLines: 1,
                            maxLines: 3,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            style: const TextStyle(
                              color: RoomColors.plum,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                            decoration: InputDecoration(
                              hintText: _floatingMode
                                  ? 'Floating message...'
                                  : 'Send a message...',
                              hintStyle: const TextStyle(
                                color: Color(0xFFB0A8B7),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        if (_floatingMode)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              '$currentLength/${LiveRoomMessageComposerModule.floatingTextCharacterLimit}',
                              style: TextStyle(
                                color: overLimit
                                    ? RoomColors.coral
                                    : RoomColors.gold,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                _ComposerSendButton(
                  enabled: _hasText && !overLimit,
                  floatingMode: _floatingMode,
                  onTap: _send,
                ),
              ],
            ),
            if (_floatingMode) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: RoomColors.gold,
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Floating message costs ${LiveRoomMessageComposerModule.floatingTextCoinCost} coins • ${LiveRoomMessageComposerModule.floatingTextCharacterLimit} character limit',
                      style: const TextStyle(
                        color: RoomColors.plum,
                        fontSize: 11.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickMessageRow extends StatelessWidget {
  const _QuickMessageRow({required this.onPick});

  final ValueChanged<String> onPick;

  static const List<String> _items = [
    'vibe check ✨',
    'that was fire 🔥',
    'no wayyy 😭',
    'main character energy',
    'send the tea ☕',
    'W moment',
    'lowkey same',
    'mic drop 🎤',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final text = _items[index];
          return InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => onPick(text),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFE7E2EA)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.055),
                    blurRadius: 9,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                text,
                style: const TextStyle(
                  color: RoomColors.plum,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ComposerRoundButton extends StatelessWidget {
  const _ComposerRoundButton({
    required this.icon,
    required this.enabled,
    required this.active,
    required this.onTap,
    this.disabledTooltip,
  });

  final IconData icon;
  final bool enabled;
  final bool active;
  final VoidCallback onTap;
  final String? disabledTooltip;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? RoomColors.aqua : const Color(0xFFC8C2CC);

    return Tooltip(
      message: enabled ? '' : (disabledTooltip ?? 'Disabled'),
      child: Material(
        color: enabled
            ? RoomColors.aqua.withValues(alpha: 0.12)
            : const Color(0xFFF0EDF2),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: color, size: 22),
          ),
        ),
      ),
    );
  }
}

class _FloatingModeToggleButton extends StatelessWidget {
  const _FloatingModeToggleButton({
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 30.0 : 42.0;
    final iconSize = compact ? 18.0 : 22.0;

    return Material(
      color: selected
          ? RoomColors.gold.withValues(alpha: 0.18)
          : Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.text_fields_rounded,
                color: selected ? RoomColors.gold : const Color(0xFF8D8494),
                size: iconSize,
              ),
              Positioned(
                right: compact ? 4 : 9,
                bottom: compact ? 4 : 9,
                child: Container(
                  width: compact ? 7 : 10,
                  height: compact ? 7 : 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? RoomColors.gold : const Color(0xFFB9B2BF),
                    border: Border.all(color: Colors.white, width: compact ? 1.0 : 1.4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComposerSendButton extends StatelessWidget {
  const _ComposerSendButton({
    required this.enabled,
    required this.floatingMode,
    required this.onTap,
  });

  final bool enabled;
  final bool floatingMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = enabled
        ? floatingMode
            ? RoomColors.gold
            : RoomColors.aqua
        : const Color(0xFFE4E8EE);

    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            Icons.send_rounded,
            color: enabled ? Colors.white : const Color(0xFFADB5C2),
            size: 24,
          ),
        ),
      ),
    );
  }
}
