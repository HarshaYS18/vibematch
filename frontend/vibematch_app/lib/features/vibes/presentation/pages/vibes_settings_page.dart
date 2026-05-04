import 'package:flutter/material.dart';

import '../../models/vibe_models.dart';

class VibesSettingsPage extends StatefulWidget {
  const VibesSettingsPage({
    super.key,
    required this.whoCanMention,
    required this.whoCanComment,
    required this.onMentionChanged,
    required this.onCommentChanged,
  });

  final VibePrivacyAudience whoCanMention;
  final VibePrivacyAudience whoCanComment;
  final ValueChanged<VibePrivacyAudience> onMentionChanged;
  final ValueChanged<VibePrivacyAudience> onCommentChanged;

  @override
  State<VibesSettingsPage> createState() => _VibesSettingsPageState();
}

class _VibesSettingsPageState extends State<VibesSettingsPage> {
  late VibePrivacyAudience _whoCanMention;
  late VibePrivacyAudience _whoCanComment;

  @override
  void initState() {
    super.initState();
    _whoCanMention = widget.whoCanMention;
    _whoCanComment = widget.whoCanComment;
  }

  void _setWhoCanMention(VibePrivacyAudience audience) {
    setState(() => _whoCanMention = audience);
    widget.onMentionChanged(audience);
    _showFeedback('Mention privacy set to ${audience.label}');
  }

  void _setWhoCanComment(VibePrivacyAudience audience) {
    setState(() => _whoCanComment = audience);
    widget.onCommentChanged(audience);
    _showFeedback('Comment privacy set to ${audience.label}');
  }

  void _showFeedback(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF251538),
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Vibes Settings',
                    style: TextStyle(
                      color: Color(0xFF251538),
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _PrivacyCard(
              title: 'Who can mention you',
              subtitle: 'Controls @name mentions in Vibes and Vibe comments.',
              value: _whoCanMention,
              onChanged: _setWhoCanMention,
            ),
            const SizedBox(height: 12),
            _PrivacyCard(
              title: 'Who can comment',
              subtitle: 'Controls who can comment on your Vibes.',
              value: _whoCanComment,
              onChanged: _setWhoCanComment,
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final VibePrivacyAudience value;
  final ValueChanged<VibePrivacyAudience> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFECE2D8)),
      ),
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
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF7B6A86),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: VibePrivacyAudience.values.map((audience) {
              final selected = value == audience;
              return InkWell(
                onTap: () => onChanged(audience),
                borderRadius: BorderRadius.circular(999),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFF251538) : const Color(0xFFFAF7F1),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: selected ? const Color(0xFF251538) : const Color(0xFFECE2D8)),
                  ),
                  child: Text(
                    audience.label,
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF4A2A63),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
