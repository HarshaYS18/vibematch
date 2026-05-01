import 'package:flutter/material.dart';

import '../models/vibe_item.dart';
import '../models/vibe_media_type.dart';
import 'widgets/vibes_ui_helpers.dart';

class CreateVibePage extends StatefulWidget {
  const CreateVibePage({
    super.key,
    required this.onPublish,
  });

  final ValueChanged<VibeItem> onPublish;

  @override
  State<CreateVibePage> createState() => _CreateVibePageState();
}

class _CreateVibePageState extends State<CreateVibePage> {
  final TextEditingController _captionController = TextEditingController();

  VibeMediaType _selectedType = VibeMediaType.photo;
  bool _commentsEnabled = true;
  bool _usesMentionAll = false;
  final List<String> _mentions = [];

  @override
  void initState() {
    super.initState();
    _captionController.addListener(_handleCaptionChanged);
  }

  @override
  void dispose() {
    _captionController.removeListener(_handleCaptionChanged);
    _captionController.dispose();
    super.dispose();
  }

  void _handleCaptionChanged() {
    final text = _captionController.text;
    final mentionRegex = RegExp(r'(^|\s)@(?!all\b)([a-zA-Z0-9_]{2,24})');
    final extracted = mentionRegex
        .allMatches(text)
        .map((match) => match.group(2))
        .whereType<String>()
        .map((name) {
          if (name.isEmpty) return name;
          return '${name[0].toUpperCase()}${name.substring(1)}';
        })
        .toSet()
        .toList();
    final hasAll = RegExp(r'(^|\s)@all\b', caseSensitive: false).hasMatch(text);

    setState(() {
      _mentions
        ..clear()
        ..addAll(extracted);
      _usesMentionAll = hasAll;
    });
  }

  void _showAction(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF251538),
        ),
      );
  }

  void _insertMention(String mention) {
    final text = _captionController.text;
    final selection = _captionController.selection;
    final cursor = selection.baseOffset < 0 ? text.length : selection.baseOffset;
    final before = text.substring(0, cursor);
    final after = text.substring(cursor);
    final insert = '@$mention ';

    _captionController.value = TextEditingValue(
      text: '$before$insert$after',
      selection: TextSelection.collapsed(offset: before.length + insert.length),
    );
  }

  void _publish() {
    final caption = _captionController.text.trim();
    if (caption.isEmpty) {
      _showAction('Write a caption before publishing.');
      return;
    }

    widget.onPublish(
      VibeItem(
        authorName: 'Founder',
        authorId: '6922022',
        avatarText: 'F',
        timeAgo: 'Just now',
        mediaType: _selectedType,
        caption: caption,
        tag: _selectedType.label,
        likes: 0,
        comments: 0,
        shares: 0,
        views: 1,
        isFollowing: true,
        usesMentionAll: _usesMentionAll,
        mentions: List<String>.from(_mentions),
        colors: _selectedType.colors,
      ),
    );

    if (_usesMentionAll) {
      _showAction('All followers will be notified after backend is connected.');
    } else if (_mentions.isNotEmpty) {
      _showAction('Mention notifications will be sent after backend is connected.');
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final captionNotEmpty = _captionController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
          children: [
            Row(
              children: [
                VibesRoundIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Create Vibe',
                    style: TextStyle(
                      color: Color(0xFF251538),
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                _PublishChip(
                  enabled: captionNotEmpty,
                  onTap: _publish,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _CreateTypePicker(
              selectedType: _selectedType,
              onSelected: (type) => setState(() => _selectedType = type),
            ),
            const SizedBox(height: 16),
            _CreateMediaBox(
              type: _selectedType,
              onTap: () => _showAction(
                '${_selectedType.label} picker will open when media upload is connected.',
              ),
            ),
            const SizedBox(height: 16),
            _CaptionComposer(
              controller: _captionController,
              commentsEnabled: _commentsEnabled,
              onToggleComments: () {
                setState(() => _commentsEnabled = !_commentsEnabled);
              },
              onInsertMention: _insertMention,
            ),
            const SizedBox(height: 14),
            _MentionPreview(
              usesMentionAll: _usesMentionAll,
              mentions: _mentions,
              commentsEnabled: _commentsEnabled,
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: captionNotEmpty
                      ? const Color(0xFF251538)
                      : const Color(0xFFE2D9CF),
                  foregroundColor:
                      captionNotEmpty ? Colors.white : const Color(0xFF8C8198),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: captionNotEmpty ? _publish : null,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text(
                  'Publish Vibe',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublishChip extends StatelessWidget {
  const _PublishChip({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFF251538) : const Color(0xFFE2D9CF),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          'Publish',
          style: TextStyle(
            color: enabled ? Colors.white : const Color(0xFF8C8198),
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _CreateTypePicker extends StatelessWidget {
  const _CreateTypePicker({required this.selectedType, required this.onSelected});

  final VibeMediaType selectedType;
  final ValueChanged<VibeMediaType> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = [VibeMediaType.photo, VibeMediaType.video, VibeMediaType.text];

    return Row(
      children: items.map((type) {
        final selected = type == selectedType;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: type == items.last ? 0 : 9),
            child: InkWell(
              onTap: () => onSelected(type),
              borderRadius: BorderRadius.circular(22),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: selected
                      ? LinearGradient(
                          colors: type.colors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: selected ? null : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: selected ? Colors.transparent : const Color(0xFFECE2D8),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: type.colors.first.withValues(alpha: selected ? 0.18 : 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(type.icon, color: selected ? Colors.white : type.colors.first, size: 24),
                    const SizedBox(height: 6),
                    Text(
                      type.label,
                      style: TextStyle(
                        color: selected ? Colors.white : const Color(0xFF251538),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CreateMediaBox extends StatelessWidget {
  const _CreateMediaBox({required this.type, required this.onTap});

  final VibeMediaType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isText = type == VibeMediaType.text;

    return InkWell(
      onTap: isText ? null : onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: isText ? 104 : 178,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: type.colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: type.colors.first.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isText ? Icons.notes_rounded : Icons.add_photo_alternate_rounded,
                color: Colors.white,
                size: 40,
              ),
              const SizedBox(height: 8),
              Text(
                isText ? 'Text Vibe selected' : 'Tap to add ${type.label.toLowerCase()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptionComposer extends StatelessWidget {
  const _CaptionComposer({
    required this.controller,
    required this.commentsEnabled,
    required this.onToggleComments,
    required this.onInsertMention,
  });

  final TextEditingController controller;
  final bool commentsEnabled;
  final VoidCallback onToggleComments;
  final ValueChanged<String> onInsertMention;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: vibePanelDecoration(radius: 26),
      child: Column(
        children: [
          TextField(
            controller: controller,
            minLines: 5,
            maxLines: 8,
            maxLength: 280,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Write a caption... use @name or @all',
              hintStyle: TextStyle(
                color: Color(0xFF8C8198),
                fontWeight: FontWeight.w600,
              ),
              counterStyle: TextStyle(color: Color(0xFF8C8198)),
            ),
          ),
          const Divider(color: Color(0xFFECE2D8)),
          Row(
            children: [
              _ComposerAction(
                icon: Icons.alternate_email_rounded,
                label: '@all',
                onTap: () => onInsertMention('all'),
              ),
              const SizedBox(width: 8),
              _ComposerAction(
                icon: Icons.person_add_alt_1_rounded,
                label: '@Riya',
                onTap: () => onInsertMention('Riya'),
              ),
              const Spacer(),
              _ComposerAction(
                icon: commentsEnabled ? Icons.chat_rounded : Icons.comments_disabled_rounded,
                label: commentsEnabled ? 'Comments On' : 'Comments Off',
                onTap: onToggleComments,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ComposerAction extends StatelessWidget {
  const _ComposerAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF7F1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: const Color(0xFF6D5DF6)),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF4A2A63),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MentionPreview extends StatelessWidget {
  const _MentionPreview({
    required this.usesMentionAll,
    required this.mentions,
    required this.commentsEnabled,
  });

  final bool usesMentionAll;
  final List<String> mentions;
  final bool commentsEnabled;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      _PreviewChip(
        icon: commentsEnabled ? Icons.chat_rounded : Icons.comments_disabled_rounded,
        text: commentsEnabled ? 'Comments enabled' : 'Comments disabled',
      ),
    ];

    if (usesMentionAll) {
      chips.add(const _PreviewChip(icon: Icons.campaign_rounded, text: '@all notification'));
    }

    for (final mention in mentions) {
      chips.add(_PreviewChip(icon: Icons.alternate_email_rounded, text: mention));
    }

    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return VibesInfoChip(
      icon: icon,
      label: text,
      color: const Color(0xFF6D5DF6),
    );
  }
}
