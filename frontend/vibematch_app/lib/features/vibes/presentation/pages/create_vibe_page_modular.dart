import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

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

  bool get _isTextMode => _selectedType == VibeMediaType.text;
  bool get _isMediaMode => !_isTextMode;

  bool get _canPublish {
    final hasCaption = _captionController.text.trim().isNotEmpty;
    final hasMedia = _isTextMode || _selectedMediaFile != null;
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
    if (_isTextMode || _pickingMedia || _uploadingMedia || _publishing) return;
    final sourceType = await _openMediaSourceSheet();
    if (sourceType == null || !mounted) return;
    setState(() => _pickingMedia = true);
    try {
      final picked = sourceType == VibeMediaType.video ? await _picker.pickVideo(source: ImageSource.gallery) : await _picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
      if (picked == null) return;
      final file = File(picked.path);
      final size = await file.length();
      if (size > 20 * 1024 * 1024) {
        _showAction('Vibe media must be 20 MB or smaller.');
        return;
      }
      setState(() {
        _selectedType = sourceType;
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

  Future<VibeMediaType?> _openMediaSourceSheet() {
    return showModalBottomSheet<VibeMediaType>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _MediaSourceSheet(),
    );
  }

  Future<String?> _uploadSelectedMediaIfNeeded() async {
    final file = _selectedMediaFile;
    if (_isTextMode || file == null) return null;
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
    if (_isMediaMode && _selectedMediaFile == null) return _showAction('Choose photo or video before sharing.');
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

  void _selectMode(_CreateVibeMode mode) {
    setState(() {
      _selectedType = mode == _CreateVibeMode.text ? VibeMediaType.text : (_selectedMediaFile == null ? VibeMediaType.photo : _selectedType == VibeMediaType.text ? VibeMediaType.photo : _selectedType);
      if (mode == _CreateVibeMode.text) {
        _selectedMediaFile = null;
        _uploadedMediaUrl = null;
        _selectedMediaName = null;
        _selectedMediaBytes = null;
      }
    });
  }

  void _clearMedia() {
    setState(() {
      _selectedMediaFile = null;
      _uploadedMediaUrl = null;
      _selectedMediaName = null;
      _selectedMediaBytes = null;
      if (_selectedType != VibeMediaType.text) _selectedType = VibeMediaType.photo;
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
            _TypeTabs(selectedMode: _isTextMode ? _CreateVibeMode.text : _CreateVibeMode.media, onSelected: _selectMode),
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

enum _CreateVibeMode { media, text }

class _TypeTabs extends StatelessWidget {
  const _TypeTabs({required this.selectedMode, required this.onSelected});
  final _CreateVibeMode selectedMode;
  final ValueChanged<_CreateVibeMode> onSelected;
  @override
  Widget build(BuildContext context) {
    const items = [_CreateVibeMode.media, _CreateVibeMode.text];
    return Container(height: 48, padding: const EdgeInsets.symmetric(horizontal: 14), margin: const EdgeInsets.symmetric(vertical: 12), child: Row(children: items.map((mode) { final selected = mode == selectedMode; final label = mode == _CreateVibeMode.media ? 'Media' : 'Text'; return Expanded(child: InkWell(onTap: () => onSelected(mode), borderRadius: BorderRadius.circular(999), child: AnimatedContainer(duration: const Duration(milliseconds: 160), margin: const EdgeInsets.symmetric(horizontal: 3), decoration: BoxDecoration(color: selected ? const Color(0xFF111015) : const Color(0xFFF7F3EF), borderRadius: BorderRadius.circular(999)), child: Center(child: Text(label, style: TextStyle(color: selected ? Colors.white : const Color(0xFF111015), fontSize: 12.5, fontWeight: FontWeight.w900)))))); }).toList()));
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: InkWell(
        onTap: isText || uploading ? null : onTap,
        borderRadius: BorderRadius.circular(22),
        child: AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Container(
              color: const Color(0xFFF6F2EE),
              child: isText
                  ? const Center(child: Text('Text Vibe', style: TextStyle(color: Color(0xFF111015), fontSize: 18, fontWeight: FontWeight.w900)))
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        if (hasFile && type == VibeMediaType.photo)
                          Image.file(selectedFile!, fit: BoxFit.cover)
                        else if (hasFile && type == VibeMediaType.video)
                          _LocalVideoPreview(file: selectedFile!)
                        else
                          _MediaPrompt(type: type, picking: picking, uploading: uploading),
                        if (hasFile) const _PreviewGradient(),
                        if (hasFile) Positioned(left: 12, bottom: 12, child: _SelectedMediaBadge(type: type, bytes: selectedBytes)),
                        if (!hasFile) Positioned(left: 12, bottom: 12, right: 12, child: _ChooseMediaHint(picking: picking, uploading: uploading)),
                        if (hasFile) Positioned(right: 12, top: 12, child: InkWell(onTap: uploading ? null : onClear, borderRadius: BorderRadius.circular(999), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.48), shape: BoxShape.circle), child: const Icon(Icons.close_rounded, color: Colors.white, size: 18)))),
                        if (hasFile) Positioned(right: 12, bottom: 12, child: InkWell(onTap: uploading ? null : onTap, borderRadius: BorderRadius.circular(999), child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.54), borderRadius: BorderRadius.circular(999)), child: const Text('Change', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900))))),
                        if (uploadedUrl != null && uploadedUrl!.trim().isNotEmpty) Positioned(left: 12, top: 12, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: const Color(0xFF111015).withValues(alpha: 0.80), borderRadius: BorderRadius.circular(999)), child: const Text('Uploaded', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)))),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LocalVideoPreview extends StatefulWidget {
  const _LocalVideoPreview({required this.file});
  final File file;
  @override
  State<_LocalVideoPreview> createState() => _LocalVideoPreviewState();
}

class _LocalVideoPreviewState extends State<_LocalVideoPreview> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file)
      ..setLooping(true)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
        _controller?.play();
      }).catchError((_) {
        if (mounted) setState(() => _hasError = true);
      });
  }

  @override
  void didUpdateWidget(covariant _LocalVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      _controller?.dispose();
      _ready = false;
      _hasError = false;
      _controller = VideoPlayerController.file(widget.file)
        ..setLooping(true)
        ..initialize().then((_) {
          if (!mounted) return;
          setState(() => _ready = true);
          _controller?.play();
        }).catchError((_) {
          if (mounted) setState(() => _hasError = true);
        });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_hasError) return const Center(child: Icon(Icons.movie_creation_rounded, color: Color(0xFF111015), size: 54));
    if (controller == null || !_ready) return const Center(child: CircularProgressIndicator(color: Color(0xFF111015), strokeWidth: 2.6));
    return FittedBox(fit: BoxFit.cover, child: SizedBox(width: controller.value.size.width, height: controller.value.size.height, child: VideoPlayer(controller)));
  }
}

class _PreviewGradient extends StatelessWidget {
  const _PreviewGradient();
  @override
  Widget build(BuildContext context) => IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withValues(alpha: 0.06), Colors.transparent, Colors.black.withValues(alpha: 0.56)], stops: const [0, 0.48, 1]))));
}

class _SelectedMediaBadge extends StatelessWidget {
  const _SelectedMediaBadge({required this.type, required this.bytes});
  final VibeMediaType type;
  final int? bytes;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.54), borderRadius: BorderRadius.circular(999)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(type == VibeMediaType.video ? Icons.play_circle_fill_rounded : Icons.photo_rounded, color: Colors.white, size: 15), const SizedBox(width: 6), Text('${type.label}${bytes == null ? '' : ' · ${_formatBytes(bytes!)}'}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900))]));
}

class _ChooseMediaHint extends StatelessWidget {
  const _ChooseMediaHint({required this.picking, required this.uploading});
  final bool picking;
  final bool uploading;
  @override
  Widget build(BuildContext context) => Center(child: Text(picking ? 'Opening gallery...' : uploading ? 'Uploading...' : 'Tap to choose photo or video', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF111015), fontSize: 13, fontWeight: FontWeight.w900)));
}

class _MediaSourceSheet extends StatelessWidget {
  const _MediaSourceSheet();
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.all(14),
        padding: EdgeInsets.fromLTRB(14, 12, 14, 14 + MediaQuery.paddingOf(context).bottom),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 24, offset: const Offset(0, 10))]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 42, height: 5, decoration: BoxDecoration(color: const Color(0xFFE0D5CB), borderRadius: BorderRadius.circular(999))),
          const SizedBox(height: 14),
          const Text('Choose media', style: TextStyle(color: Color(0xFF111015), fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          _MediaSourceTile(icon: Icons.photo_rounded, title: 'Photo', subtitle: 'Pick an image from gallery', onTap: () => Navigator.pop(context, VibeMediaType.photo)),
          _MediaSourceTile(icon: Icons.play_circle_fill_rounded, title: 'Video', subtitle: 'Pick a video from gallery', onTap: () => Navigator.pop(context, VibeMediaType.video)),
        ]),
      );
}

class _MediaSourceTile extends StatelessWidget {
  const _MediaSourceTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFAF7F1), borderRadius: BorderRadius.circular(18)), child: Row(children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFF111015), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: Colors.white, size: 22)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Color(0xFF111015), fontSize: 14, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(subtitle, style: const TextStyle(color: Color(0xFF8C8198), fontSize: 11.5, fontWeight: FontWeight.w700))])), const Icon(Icons.chevron_right_rounded, color: Color(0xFF8C8198))])));
}

class _MediaPrompt extends StatelessWidget {
  const _MediaPrompt({required this.type, required this.picking, required this.uploading});
  final VibeMediaType type;
  final bool picking;
  final bool uploading;
  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [if (picking || uploading) const SizedBox(width: 34, height: 34, child: CircularProgressIndicator(color: Color(0xFF111015), strokeWidth: 2.6)) else Container(width: 74, height: 74, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), border: Border.all(color: const Color(0xFFECE2D8))), child: const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF111015), size: 38)), const SizedBox(height: 14), const Text('Create Media Vibe', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF111015), fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 5), const Text('Photo or video preview will appear here', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF8C8198), fontSize: 12, fontWeight: FontWeight.w700))]));
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
