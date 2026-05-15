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
  const CreateVibePageModular({super.key, required this.canUseMentionAllToday, required this.onPublish});

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

  bool get _canPublish {
    final hasCaption = _captionController.text.trim().isNotEmpty;
    final hasMedia = _selectedType == VibeMediaType.text || _selectedMediaFile != null;
    return hasCaption && hasMedia && !_publishing && !_uploadingMedia;
  }

  @override
  void initState() {
    super.initState();
    _captionController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  void _showAction(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)), behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF111015)));
  }

  Future<void> _pickMedia() async {
    if (_selectedType == VibeMediaType.text || _pickingMedia || _uploadingMedia || _publishing) return;
    setState(() => _pickingMedia = true);
    try {
      final picked = _selectedType == VibeMediaType.video ? await _picker.pickVideo(source: ImageSource.gallery) : await _picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
      if (picked == null) return;
      final file = File(picked.path);
      final size = await file.length();
      if (size > 20 * 1024 * 1024) {
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

  Future<String?> _uploadSelectedMediaIfNeeded() async {
    final file = _selectedMediaFile;
    if (_selectedType == VibeMediaType.text || file == null) return null;
    if (_uploadedMediaUrl != null && _uploadedMediaUrl!.trim().isNotEmpty) return _uploadedMediaUrl;
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
    if (caption.isEmpty) return _showAction('Write a caption before sharing.');
    if (_captionController.usesMentionAll && !widget.canUseMentionAllToday) return _showAction('@all is limited to 2 posts per day.');
    if (_selectedType != VibeMediaType.text && _selectedMediaFile == null) return _showAction('Choose a ${_selectedType.label.toLowerCase()} before sharing.');
    if (_publishing || _uploadingMedia) return;
    setState(() => _publishing = true);
    try {
      final mediaUrl = await _uploadSelectedMediaIfNeeded();
      final currentUser = _authApi.cachedUser;
      final visibleName = currentUser?.displayName?.trim().isNotEmpty == true ? currentUser!.displayName!.trim() : currentUser?.username?.trim().isNotEmpty == true ? currentUser!.username!.trim() : 'Vibe User';
      await widget.onPublish(VibeItem(authorName: visibleName, authorId: currentUser?.publicUserId.toString() ?? '', avatarText: visibleName.trim().isEmpty ? 'V' : visibleName.trim()[0].toUpperCase(), timeAgo: 'Just now', mediaType: _selectedType, caption: caption, tag: _selectedType.label, likes: 0, comments: 0, shares: 0, views: 1, isFollowing: true, usesMentionAll: _captionController.usesMentionAll, mentions: _captionController.validMentions, colors: _selectedType.colors, mediaUrl: mediaUrl, commentsEnabled: _commentsEnabled));
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) _showAction(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  void _selectType(VibeMediaType type) {
    setState(() {
      _selectedType = type;
      _selectedMediaFile = null;
      _uploadedMediaUrl = null;
      _selectedMediaName = null;
      _selectedMediaBytes = null;
    });
  }

  void _clearMedia() {
    setState(() {
      _selectedMediaFile = null;
      _uploadedMediaUrl = null;
      _selectedMediaName = null;
      _selectedMediaBytes = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Color(0xFF111015), size: 28)),
        title: const Text('New Vibe', style: TextStyle(color: Color(0xFF111015), fontSize: 18, fontWeight: FontWeight.w900)),
        actions: [TextButton(onPressed: _canPublish ? () => unawaited(_publish()) : null, child: Text(_publishing || _uploadingMedia ? 'Posting...' : 'Share', style: TextStyle(color: _canPublish ? const Color(0xFF1A5BEA) : const Color(0xFFB7AFBD), fontSize: 15, fontWeight: FontWeight.w900))), const SizedBox(width: 8)],
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: Color(0xFFECE2D8))),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 26),
          children: [
            _TypeTabs(selectedType: _selectedType, onSelected: _selectType),
            _MediaPicker(type: _selectedType, selectedFile: _selectedMediaFile, selectedName: _selectedMediaName, selectedBytes: _selectedMediaBytes, picking: _pickingMedia, uploading: _uploadingMedia, uploadedUrl: _uploadedMediaUrl, onTap: () => unawaited(_pickMedia()), onClear: _clearMedia),
            _CaptionBox(controller: _captionController, commentsEnabled: _commentsEnabled, onToggleComments: () => setState(() => _commentsEnabled = !_commentsEnabled)),
            if (_captionController.hasMentionTrigger) Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: SocialMentionPicker(query: _captionController.activeMentionQuery, onSelected: (user) => setState(() => _captionController.insertMention(user.username)))),
            _MentionRow(usesMentionAll: _captionController.usesMentionAll, mentions: _captionController.validMentions, commentsEnabled: _commentsEnabled, canUseMentionAllToday: widget.canUseMentionAllToday),
            Padding(padding: const EdgeInsets.fromLTRB(14, 16, 14, 0), child: _ShareButton(enabled: _canPublish, busy: _publishing || _uploadingMedia, onTap: () => unawaited(_publish()))),
          ],
        ),
      ),
    );
  }
}

class _TypeTabs extends StatelessWidget {
  const _TypeTabs({required this.selectedType, required this.onSelected});
  final VibeMediaType selectedType;
  final ValueChanged<VibeMediaType> onSelected;
  @override
  Widget build(BuildContext context) {
    final items = [VibeMediaType.photo, VibeMediaType.video, VibeMediaType.text];
    return Container(height: 48, padding: const EdgeInsets.symmetric(horizontal: 14), margin: const EdgeInsets.symmetric(vertical: 12), child: Row(children: items.map((type) { final selected = type == selectedType; return Expanded(child: InkWell(onTap: () => onSelected(type), borderRadius: BorderRadius.circular(999), child: AnimatedContainer(duration: const Duration(milliseconds: 160), margin: const EdgeInsets.symmetric(horizontal: 3), decoration: BoxDecoration(color: selected ? const Color(0xFF111015) : const Color(0xFFF7F3EF), borderRadius: BorderRadius.circular(999)), child: Center(child: Text(type.label, style: TextStyle(color: selected ? Colors.white : const Color(0xFF111015), fontSize: 12.5, fontWeight: FontWeight.w900)))))); }).toList()));
  }
}

class _MediaPicker extends StatelessWidget {
  const _MediaPicker({required this.type, required this.selectedFile, required this.selectedName, required this.selectedBytes, required this.picking, required this.uploading, required this.uploadedUrl, required this.onTap, required this.onClear});
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
    return InkWell(onTap: isText || uploading ? null : onTap, child: AspectRatio(aspectRatio: 1, child: Container(color: const Color(0xFFF6F2EE), child: isText ? const Center(child: Text('Text Vibe', style: TextStyle(color: Color(0xFF111015), fontSize: 18, fontWeight: FontWeight.w900))) : Stack(fit: StackFit.expand, children: [if (hasFile && type == VibeMediaType.photo) Image.file(selectedFile!, fit: BoxFit.cover) else _MediaPrompt(type: type, hasFile: hasFile, picking: picking, uploading: uploading, selectedName: selectedName, selectedBytes: selectedBytes), if (hasFile) Positioned(right: 12, top: 12, child: InkWell(onTap: uploading ? null : onClear, borderRadius: BorderRadius.circular(999), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.46), shape: BoxShape.circle), child: const Icon(Icons.close_rounded, color: Colors.white, size: 18)))), if (uploadedUrl != null && uploadedUrl!.trim().isNotEmpty) Positioned(left: 12, bottom: 12, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: const Color(0xFF111015).withValues(alpha: 0.80), borderRadius: BorderRadius.circular(999)), child: const Text('Uploaded', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900))))]))));
  }
}

class _MediaPrompt extends StatelessWidget {
  const _MediaPrompt({required this.type, required this.hasFile, required this.picking, required this.uploading, required this.selectedName, required this.selectedBytes});
  final VibeMediaType type;
  final bool hasFile;
  final bool picking;
  final bool uploading;
  final String? selectedName;
  final int? selectedBytes;
  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [if (picking || uploading) const SizedBox(width: 34, height: 34, child: CircularProgressIndicator(color: Color(0xFF111015), strokeWidth: 2.6)) else Icon(type == VibeMediaType.video && hasFile ? Icons.movie_creation_rounded : type.icon, color: const Color(0xFF111015), size: 44), const SizedBox(height: 10), Text(hasFile ? selectedName ?? '${type.label} selected' : 'Tap to choose ${type.label.toLowerCase()}', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF111015), fontWeight: FontWeight.w900)), if (selectedBytes != null) ...[const SizedBox(height: 4), Text(_formatBytes(selectedBytes!), style: const TextStyle(color: Color(0xFF8C8198), fontSize: 11, fontWeight: FontWeight.w800))]]));
  }
}

class _CaptionBox extends StatelessWidget {
  const _CaptionBox({required this.controller, required this.commentsEnabled, required this.onToggleComments});
  final VibeMentionTextController controller;
  final bool commentsEnabled;
  final VoidCallback onToggleComments;
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.fromLTRB(14, 12, 14, 6), decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFECE2D8)))), child: Column(children: [TextField(controller: controller, maxLines: 5, minLines: 3, style: const TextStyle(color: Color(0xFF111015), fontSize: 15, fontWeight: FontWeight.w600, height: 1.35), decoration: const InputDecoration(hintText: 'Write a caption... use @name or @all', hintStyle: TextStyle(color: Color(0xFFAAA1AE), fontWeight: FontWeight.w600), border: InputBorder.none)), Row(children: [const Icon(Icons.mode_comment_outlined, color: Color(0xFF111015), size: 18), const SizedBox(width: 8), const Expanded(child: Text('Allow comments', style: TextStyle(color: Color(0xFF111015), fontSize: 13, fontWeight: FontWeight.w900))), Switch(value: commentsEnabled, onChanged: (_) => onToggleComments(), activeThumbColor: const Color(0xFF111015))])]));
  }
}

class _MentionRow extends StatelessWidget {
  const _MentionRow({required this.usesMentionAll, required this.mentions, required this.commentsEnabled, required this.canUseMentionAllToday});
  final bool usesMentionAll;
  final List<String> mentions;
  final bool commentsEnabled;
  final bool canUseMentionAllToday;
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 0), child: Wrap(spacing: 8, runSpacing: 8, children: [if (usesMentionAll) _SmallChip(text: canUseMentionAllToday ? '@all' : '@all limit reached'), ...mentions.map((mention) => _SmallChip(text: '@$mention')), _SmallChip(text: commentsEnabled ? 'Comments on' : 'Comments off')]));
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: const Color(0xFFF2EEF4), borderRadius: BorderRadius.circular(999)), child: Text(text, style: const TextStyle(color: Color(0xFF111015), fontSize: 11, fontWeight: FontWeight.w900)));
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.enabled, required this.busy, required this.onTap});
  final bool enabled;
  final bool busy;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: enabled ? onTap : null, borderRadius: BorderRadius.circular(14), child: Container(height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: enabled ? const Color(0xFF111015) : const Color(0xFFE4DFE8), borderRadius: BorderRadius.circular(14)), child: busy ? const SizedBox(width: 19, height: 19, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2)) : Text('Share Vibe', style: TextStyle(color: enabled ? Colors.white : const Color(0xFF8C8198), fontWeight: FontWeight.w900))));
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '$bytes B';
}
