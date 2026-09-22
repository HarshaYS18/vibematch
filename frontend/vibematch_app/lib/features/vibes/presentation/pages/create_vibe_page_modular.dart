import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../auth/data/auth_api_service.dart';
import '../../../media/data/media_upload_api_service.dart';
import '../../../social/widgets/social_mention_picker.dart';
import '../../controllers/vibe_mention_controller.dart';
import '../../models/vibe_models.dart';
import '../widgets/create_vibe_form_widgets.dart';
import '../widgets/create_vibe_media_picker.dart';
import '../widgets/vibe_media_playback_gate.dart';

class CreateVibePageModular extends StatefulWidget {
  const CreateVibePageModular({super.key, required this.canUseMentionAllToday, required this.onPublish, required this.playbackGate});

  final bool canUseMentionAllToday;
  final Future<void> Function(VibeItem) onPublish;
  final VibeMediaPlaybackGate playbackGate;

  @override
  State<CreateVibePageModular> createState() => _CreateVibePageModularState();
}

class _CreateVibePageModularState extends State<CreateVibePageModular> {
  static const String _composerPauseLockKey = 'vibes_composer_open';

  final VibeMentionTextController _captionController = VibeMentionTextController();
  final ImagePicker _picker = ImagePicker();
  final MediaUploadApiService _uploadApi = const MediaUploadApiService();
  final AuthApiService _authApi = const AuthApiService();

  VibeMediaType _selectedType = VibeMediaType.photo;
  bool _commentsEnabled = true;
  bool _pickingMedia = false;
  bool _uploadingMedia = false;
  bool _publishing = false;
  XFile? _selectedMediaFile;
  Uint8List? _selectedMediaPreviewBytes;
  String? _uploadedMediaUrl;
  String? _selectedMediaName;
  int? _selectedMediaBytes;
  String? _uploadErrorMessage;
  String? _postingStatusText;

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
    widget.playbackGate.acquirePauseLock(_composerPauseLockKey);
    _captionController.addListener(_onCaptionChanged);
  }

  @override
  void dispose() {
    widget.playbackGate.releasePauseLock(_composerPauseLockKey);
    _captionController.removeListener(_onCaptionChanged);
    _captionController.dispose();
    super.dispose();
  }

  void _onCaptionChanged() {
    if (mounted) setState(() {});
  }

  void _showAction(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)), behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF111015)));
  }

  String _friendlyError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    if (raw.contains('413')) return 'This file is too large. Choose media under 20 MB.';
    if (raw.contains('401') || raw.toLowerCase().contains('login')) return 'Session expired. Login again before posting.';
    if (raw.contains('400') && raw.toLowerCase().contains('unsupported')) return 'Unsupported media type. Choose JPG, PNG, WEBP, GIF, MP4, WEBM, or MOV.';
    if (raw.toLowerCase().contains('failed to fetch') || raw.toLowerCase().contains('xmlhttprequest')) return 'Upload failed. Check FastAPI is running and try again.';
    return raw.isEmpty ? 'Something went wrong. Please try again.' : raw;
  }

  Future<void> _pickMedia() async {
    if (_isTextMode || _pickingMedia || _uploadingMedia || _publishing) return;
    final sourceType = await _openMediaSourceSheet();
    if (sourceType == null || !mounted) return;
    setState(() {
      _pickingMedia = true;
      _uploadErrorMessage = null;
      _postingStatusText = null;
    });
    try {
      final picked = sourceType == VibeMediaType.video ? await _picker.pickVideo(source: ImageSource.gallery) : await _picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final size = bytes.length;
      if (size <= 0) {
        _showAction('Selected media is empty.');
        return;
      }
      if (size > 20 * 1024 * 1024) {
        _showAction('Vibe media must be 20 MB or smaller.');
        return;
      }
      setState(() {
        _selectedType = sourceType;
        _selectedMediaFile = picked;
        _selectedMediaPreviewBytes = sourceType == VibeMediaType.photo ? bytes : null;
        _uploadedMediaUrl = null;
        _selectedMediaName = picked.name;
        _selectedMediaBytes = size;
        _uploadErrorMessage = null;
        _postingStatusText = null;
      });
    } catch (error) {
      final message = _friendlyError(error);
      setState(() => _uploadErrorMessage = message);
      _showAction(message);
    } finally {
      if (mounted) setState(() => _pickingMedia = false);
    }
  }

  Future<VibeMediaType?> _openMediaSourceSheet() {
    return showModalBottomSheet<VibeMediaType>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateVibeMediaSourceSheet(),
    );
  }

  Future<String?> _uploadSelectedMediaIfNeeded() async {
    final file = _selectedMediaFile;
    if (_isTextMode || file == null) return null;
    if (_uploadedMediaUrl != null && _uploadedMediaUrl!.trim().isNotEmpty) return _uploadedMediaUrl;
    setState(() {
      _uploadingMedia = true;
      _uploadErrorMessage = null;
      _postingStatusText = 'Uploading media...';
    });
    try {
      final result = await _uploadApi.uploadVibeMediaXFile(file);
      if (result.url.trim().isEmpty) throw Exception('Upload completed without a media URL.');
      if (mounted) {
        setState(() {
          _uploadedMediaUrl = result.url;
          _postingStatusText = 'Media uploaded. Publishing Vibe...';
        });
      }
      return result.url;
    } catch (error) {
      final message = _friendlyError(error);
      if (mounted) {
        setState(() {
          _uploadErrorMessage = message;
          _postingStatusText = null;
        });
      }
      rethrow;
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
    setState(() {
      _publishing = true;
      _uploadErrorMessage = null;
      _postingStatusText = _isMediaMode ? 'Preparing upload...' : 'Publishing Vibe...';
    });
    try {
      final mediaUrl = await _uploadSelectedMediaIfNeeded();
      if (mounted) setState(() => _postingStatusText = 'Publishing Vibe...');
      final currentUser = _authApi.cachedUser;
      final visibleName = currentUser?.displayName?.trim().isNotEmpty == true
          ? currentUser!.displayName!.trim()
          : currentUser?.username?.trim().isNotEmpty == true
              ? currentUser!.username!.trim()
              : 'Vibe User';
      await widget.onPublish(VibeItem(
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
        commentsEnabled: _commentsEnabled,
      ));
      if (mounted) Navigator.pop(context);
    } catch (error) {
      final message = _friendlyError(error);
      if (mounted) {
        setState(() {
          _uploadErrorMessage = message;
          _postingStatusText = null;
        });
        _showAction(message);
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  void _selectMode(CreateVibeMode mode) {
    setState(() {
      _selectedType = mode == CreateVibeMode.text
          ? VibeMediaType.text
          : (_selectedMediaFile == null
              ? VibeMediaType.photo
              : _selectedType == VibeMediaType.text
                  ? VibeMediaType.photo
                  : _selectedType);
      if (mode == CreateVibeMode.text) {
        _selectedMediaFile = null;
        _selectedMediaPreviewBytes = null;
        _uploadedMediaUrl = null;
        _selectedMediaName = null;
        _selectedMediaBytes = null;
        _uploadErrorMessage = null;
        _postingStatusText = null;
      }
    });
  }

  void _clearMedia() {
    setState(() {
      _selectedMediaFile = null;
      _selectedMediaPreviewBytes = null;
      _uploadedMediaUrl = null;
      _selectedMediaName = null;
      _selectedMediaBytes = null;
      _uploadErrorMessage = null;
      _postingStatusText = null;
      if (_selectedType != VibeMediaType.text) _selectedType = VibeMediaType.photo;
    });
  }

  @override
  Widget build(BuildContext context) {
    final busy = _publishing || _uploadingMedia;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(onPressed: busy ? null : () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Color(0xFF111015), size: 28)),
        title: const Text('New Vibe', style: TextStyle(color: Color(0xFF111015), fontSize: 18, fontWeight: FontWeight.w900)),
        actions: [
          TextButton(
            onPressed: _canPublish ? () => unawaited(_publish()) : null,
            child: Text(
              busy ? 'Posting...' : 'Share',
              style: TextStyle(color: _canPublish ? const Color(0xFF1A5BEA) : const Color(0xFFB7AFBD), fontSize: 15, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: Color(0xFFECE2D8))),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 26),
          children: [
            CreateVibeTypeTabs(selectedMode: _isTextMode ? CreateVibeMode.text : CreateVibeMode.media, onSelected: busy ? (_) {} : _selectMode),
            CreateVibeMediaPicker(
              type: _selectedType,
              selectedFile: _selectedMediaFile,
              selectedPreviewBytes: _selectedMediaPreviewBytes,
              selectedName: _selectedMediaName,
              selectedBytes: _selectedMediaBytes,
              picking: _pickingMedia,
              uploading: _uploadingMedia,
              uploadedUrl: _uploadedMediaUrl,
              onTap: () => unawaited(_pickMedia()),
              onClear: _clearMedia,
            ),
            if (_postingStatusText != null || _uploadErrorMessage != null)
              CreateVibeStatusBanner(
                message: _uploadErrorMessage ?? _postingStatusText ?? '',
                isError: _uploadErrorMessage != null,
                onRetry: _uploadErrorMessage != null && _isMediaMode && _selectedMediaFile != null && !busy ? () => unawaited(_publish()) : null,
              ),
            CreateVibeCaptionBox(controller: _captionController, commentsEnabled: _commentsEnabled, onToggleComments: busy ? () {} : () => setState(() => _commentsEnabled = !_commentsEnabled)),
            if (_captionController.hasMentionTrigger)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: SocialMentionPicker(query: _captionController.activeMentionQuery, onSelected: (user) => setState(() => _captionController.insertMention(user.username))),
              ),
            CreateVibeMentionRow(usesMentionAll: _captionController.usesMentionAll, mentions: _captionController.validMentions, commentsEnabled: _commentsEnabled, canUseMentionAllToday: widget.canUseMentionAllToday),
            Padding(padding: const EdgeInsets.fromLTRB(14, 16, 14, 0), child: CreateVibeShareButton(enabled: _canPublish, busy: busy, statusText: _postingStatusText, onTap: () => unawaited(_publish()))),
          ],
        ),
      ),
    );
  }
}