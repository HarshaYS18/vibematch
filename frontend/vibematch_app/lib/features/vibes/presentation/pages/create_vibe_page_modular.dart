import 'package:flutter/material.dart';

import '../../../social/widgets/social_mention_picker.dart';
import '../../controllers/vibe_mention_controller.dart';
import '../../models/vibe_models.dart';

class CreateVibePageModular extends StatefulWidget {
  const CreateVibePageModular({
    super.key,
    required this.canUseMentionAllToday,
    required this.onPublish,
  });

  final bool canUseMentionAllToday;
  final ValueChanged<VibeItem> onPublish;

  @override
  State<CreateVibePageModular> createState() => _CreateVibePageModularState();
}

class _CreateVibePageModularState extends State<CreateVibePageModular> {
  final VibeMentionTextController _captionController = VibeMentionTextController();
  VibeMediaType _selectedType = VibeMediaType.photo;
  bool _commentsEnabled = true;

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

  void _handleCaptionChanged() => setState(() {});

  void _showAction(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF251538),
        ),
      );
  }

  void _publish() {
    final caption = _captionController.text.trim();
    if (caption.isEmpty) {
      _showAction('Write a caption before publishing.');
      return;
    }

    if (_captionController.usesMentionAll && !widget.canUseMentionAllToday) {
      _showAction('@all is limited to 2 posts per day.');
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
        usesMentionAll: _captionController.usesMentionAll,
        mentions: _captionController.validMentions,
        colors: _selectedType.colors,
      ),
    );

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
                _RoundIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
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
                InkWell(
                  onTap: captionNotEmpty ? _publish : null,
                  borderRadius: BorderRadius.circular(18),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                    decoration: BoxDecoration(
                      color: captionNotEmpty ? const Color(0xFF251538) : const Color(0xFFE2D9CF),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      'Publish',
                      style: TextStyle(
                        color: captionNotEmpty ? Colors.white : const Color(0xFF8C8198),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
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
              onTap: () => _showAction('${_selectedType.label} picker will open when media upload is connected.'),
            ),
            const SizedBox(height: 16),
            _CaptionComposer(
              controller: _captionController,
              commentsEnabled: _commentsEnabled,
              onToggleComments: () => setState(() => _commentsEnabled = !_commentsEnabled),
            ),
            if (_captionController.hasMentionTrigger)
              SocialMentionPicker(
                query: _captionController.activeMentionQuery,
                onSelected: (user) => setState(() => _captionController.insertMention(user.username)),
              ),
            const SizedBox(height: 14),
            _MentionPreview(
              usesMentionAll: _captionController.usesMentionAll,
              mentions: _captionController.validMentions,
              commentsEnabled: _commentsEnabled,
              canUseMentionAllToday: widget.canUseMentionAllToday,
            ),
            const SizedBox(height: 18),
            _PublishWideButton(enabled: captionNotEmpty, onTap: _publish),
          ],
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
                  gradient: selected ? LinearGradient(colors: type.colors, begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
                  color: selected ? null : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: selected ? Colors.transparent : const Color(0xFFECE2D8)),
                  boxShadow: [BoxShadow(color: type.colors.first.withValues(alpha: selected ? 0.18 : 0.04), blurRadius: 16, offset: const Offset(0, 8))],
                ),
                child: Column(
                  children: [
                    Icon(type.icon, color: selected ? Colors.white : type.colors.first, size: 24),
                    const SizedBox(height: 6),
                    Text(type.label, style: TextStyle(color: selected ? Colors.white : const Color(0xFF251538), fontSize: 13, fontWeight: FontWeight.w900)),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFECE2D8)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(type.icon, color: type.colors.first, size: 34),
              const SizedBox(height: 8),
              Text(isText ? 'Text Vibe selected' : 'Tap to choose ${type.label.toLowerCase()}', style: const TextStyle(color: Color(0xFF7B6A86), fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptionComposer extends StatelessWidget {
  const _CaptionComposer({required this.controller, required this.commentsEnabled, required this.onToggleComments});
  final VibeMentionTextController controller;
  final bool commentsEnabled;
  final VoidCallback onToggleComments;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFECE2D8))),
      child: Column(
        children: [
          TextField(
            controller: controller,
            maxLines: 5,
            minLines: 3,
            decoration: const InputDecoration(
              hintText: 'Write caption with @name or @all...',
              border: InputBorder.none,
            ),
          ),
          const Divider(color: Color(0xFFECE2D8)),
          Row(
            children: [
              const Icon(Icons.mode_comment_rounded, color: Color(0xFF8C5CF6), size: 18),
              const SizedBox(width: 8),
              const Expanded(child: Text('Allow comments', style: TextStyle(color: Color(0xFF251538), fontWeight: FontWeight.w900))),
              Switch(value: commentsEnabled, onChanged: (_) => onToggleComments(), activeThumbColor: const Color(0xFF12C7B7)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MentionPreview extends StatelessWidget {
  const _MentionPreview({required this.usesMentionAll, required this.mentions, required this.commentsEnabled, required this.canUseMentionAllToday});
  final bool usesMentionAll;
  final List<String> mentions;
  final bool commentsEnabled;
  final bool canUseMentionAllToday;
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (usesMentionAll)
          _Chip(text: canUseMentionAllToday ? '@ all' : '@all limit reached', color: canUseMentionAllToday ? const Color(0xFFC99A3B) : const Color(0xFFE84C72)),
        ...mentions.map((mention) => _Chip(text: '@ $mention', color: const Color(0xFF6D5DF6))),
        _Chip(text: commentsEnabled ? 'Comments on' : 'Comments off', color: commentsEnabled ? const Color(0xFF12C7B7) : const Color(0xFFE84C72)),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
    );
  }
}

class _PublishWideButton extends StatelessWidget {
  const _PublishWideButton({required this.enabled, required this.onTap});
  final bool enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: enabled ? const Color(0xFF251538) : const Color(0xFFE2D9CF), borderRadius: BorderRadius.circular(20)),
        child: Text('Publish Vibe', style: TextStyle(color: enabled ? Colors.white : const Color(0xFF8C8198), fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(width: 42, height: 42, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFECE2D8))), child: Icon(icon, color: const Color(0xFF251538))),
    );
  }
}
