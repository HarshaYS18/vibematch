import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../auth/data/auth_api_service.dart';
import '../../../media/data/media_upload_api_service.dart';
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
  final Future<void> Function(VibeItem) onPublish;

  @override
  State<CreateVibePageModular> createState() => _CreateVibePageModularState();
}

class _CreateVibePageModularState extends State<CreateVibePageModular> {
  final VibeMentionTextController _captionController = VibeMentionTextController();
  final ImagePicker _picker = ImagePicker();
  final MediaUploadApiService _uploadApi = const MediaUploadApiService();
  final AuthApiService _authApi = const AuthApiService();

  VibeMediaType _selectedType = VibeMediaType.photo;
  bool _commentsEnabled = true;
  bool _pickingMedia = false;
  bool _uploadingMedia = false;
  bool _publishing = false;
  File? _selectedMediaFile;
  String? _uploadedMediaUrl;
  String? _selectedMediaName;
  int? _selectedMediaBytes;

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

  Future<void> _pickMedia() async {
    if (_selectedType == VibeMediaType.text || _pickingMedia || _uploadingMedia || _publishing) return;
    setState(() => _pickingMedia = true);
    try {
      final picked = _selectedType == VibeMediaType.video
          ? await _picker.pickVideo(source: ImageSource.gallery)
          : await _picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
      if (picked == null) return;
      final file = File(picked.path);
      final size = await file.length();
      final maxSize = 20 * 1024 * 1024;
      if (size > maxSize) {
        _showAction('Vibe media must be 20 MB or smaller.');
        return;
      }
      setState(() {
        _selectedMediaFile = file;
        _uploadedMediaUrl = null;
        _selectedMediaName = picked.name;
        _selectedMediaBytes = size;
      });
    } catch (error) {
      _showAction(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _pickingMedia = false);
    }
  }

  void _clearMedia() {
    setState(() {
      _selectedMediaFile = null;
      _uploadedMediaUrl = null;
      _selectedMediaName = null;
      _selectedMediaBytes = null;
    });
  }

  void _changeType(VibeMediaType type) {
    setState(() {
      _selectedType = type;
      _selectedMediaFile = null;
      _uploadedMediaUrl = null;
      _selectedMediaName = null;
      _selectedMediaBytes = null;
    });
  }

  Future<String?> _uploadSelectedMediaIfNeeded() async {
    final file = _selectedMediaFile;
    if (_selectedType == VibeMediaType.text || file == null) return null;
    final existingUrl = _uploadedMediaUrl;
    if (existingUrl != null && existingUrl.trim().isNotEmpty) return existingUrl;

    setState(() => _uploadingMedia = true);
    try {
      final result = await _uploadApi.uploadVibeMedia(file);
      if (result.url.trim().isEmpty) throw Exception('Upload completed without a media URL.');
      if (mounted) setState(() => _uploadedMediaUrl = result.url);
      return result.url;
    } finally {
      if (mounted) setState(() => _uploadingMedia = false);
    }
  }

  Future<void> _publish() async {
    final caption = _captionController.text.trim();
    if (caption.isEmpty) {
      _showAction('Write a caption before publishing.');
      return;
    }

    if (_captionController.usesMentionAll && !widget.canUseMentionAllToday) {
      _showAction('@all is limited to 2 posts per day.');
      return;
    }

    if (_selectedType != VibeMediaType.text && _selectedMediaFile == null) {
      _showAction('Choose a ${_selectedType.label.toLowerCase()} before publishing.');
      return;
    }

    if (_publishing || _uploadingMedia) return;
    setState(() => _publishing = true);

    try {
      final mediaUrl = await _uploadSelectedMediaIfNeeded();
      final currentUser = _authApi.cachedUser;
      final visibleName = currentUser?.displayName?.trim().isNotEmpty == true
          ? currentUser!.displayName!.trim()
          : currentUser?.username?.trim().isNotEmpty == true
              ? currentUser!.username!.trim()
              : 'Vibe User';

      await widget.onPublish(
        VibeItem(
          authorName: visibleName,
          authorId: currentUser?.publicUserId.toString() ?? '',
          avatarText: visibleName.trim().isEmpty ? 'V' : visibleName.trim()[0].toUpperCase(),
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
          mediaUrl: mediaUrl,
        ),
      );

      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) _showAction(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final captionNotEmpty = _captionController.text.trim().isNotEmpty;
    final canPublish = captionNotEmpty && !_publishing && !_uploadingMedia && (_selectedType == VibeMediaType.text || _selectedMediaFile != null);

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
                  onTap: canPublish ? () => unawaited(_publish()) : null,
                  borderRadius: BorderRadius.circular(18),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                    decoration: BoxDecoration(
                      color: canPublish ? const Color(0xFF251538) : const Color(0xFFE2D9CF),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      _publishing || _uploadingMedia ? 'Wait...' : 'Publish',
                      style: TextStyle(
                        color: canPublish ? Colors.white : const Color(0xFF8C8198),
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
              onSelected: _changeType,
            ),
            const SizedBox(height: 16),
            _CreateMediaBox(
              type: _selectedType,
              selectedFile: _selectedMediaFile,
              selectedName: _selectedMediaName,
              selectedBytes: _selectedMediaBytes,
              picking: _pickingMedia,
              uploading: _uploadingMedia,
              uploadedUrl: _uploadedMediaUrl,
              onTap: () => unawaited(_pickMedia()),
              onClear: _clearMedia,
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
            _PublishWideButton(enabled: canPublish, busy: _publishing || _uploadingMedia, onTap: () => unawaited(_publish())),
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
  const _CreateMediaBox({required this.type, required this.selectedFile, required this.selectedName, required this.selectedBytes, required this.picking, required this.uploading, required this.uploadedUrl, required this.onTap, required this.onClear});
  final VibeMediaType type;
  final File? selectedFile;
  final String? selectedName;
  final int? selectedBytes;
  final bool picking;
  final bool uploading;
  final String? uploadedUrl;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final isText = type == VibeMediaType.text;
    final hasFile = selectedFile != null;
    return InkWell(
      onTap: isText || uploading ? null : onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: isText ? 104 : 202,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFECE2D8)),
        ),
        child: isText
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(type.icon, color: type.colors.first, size: 34),
                    const SizedBox(height: 8),
                    const Text('Text Vibe selected', style: TextStyle(color: Color(0xFF7B6A86), fontWeight: FontWeight.w800)),
                  ],
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  if (hasFile && type == VibeMediaType.photo)
                    Image.file(selectedFile!, fit: BoxFit.cover)
                  else
                    Container(
                      decoration: BoxDecoration(gradient: LinearGradient(colors: type.colors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (picking || uploading)
                              const SizedBox(width: 34, height: 34, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.6))
                            else
                              Icon(type == VibeMediaType.video && hasFile ? Icons.movie_creation_rounded : type.icon, color: Colors.white, size: 42),
                            const SizedBox(height: 9),
                            Text(
                              hasFile ? selectedName ?? '${type.label} selected' : 'Tap to choose ${type.label.toLowerCase()}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                            ),
                            if (selectedBytes != null) ...[
                              const SizedBox(height: 4),
                              Text(_formatBytes(selectedBytes!), style: TextStyle(color: Colors.white.withValues(alpha: 0.74), fontSize: 11, fontWeight: FontWeight.w800)),
                            ],
                          ],
                        ),
                      ),
                    ),
                  if (hasFile)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: InkWell(
                        onTap: uploading ? null : onClear,
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.46), shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  if (uploadedUrl != null && uploadedUrl!.trim().isNotEmpty)
                    Positioned(
                      left: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(color: const Color(0xFF12C7B7).withValues(alpha: 0.92), borderRadius: BorderRadius.circular(999)),
                        child: const Text('Uploaded', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                      ),
                    ),
                ],
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
  const _PublishWideButton({required this.enabled, required this.busy, required this.onTap});
  final bool enabled;
  final bool busy;
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
        child: busy
            ? const SizedBox(width: 19, height: 19, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2))
            : Text('Publish Vibe', style: TextStyle(color: enabled ? Colors.white : const Color(0xFF8C8198), fontWeight: FontWeight.w900)),
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

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '$bytes B';
}
