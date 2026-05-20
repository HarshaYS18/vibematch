import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../media/data/media_upload_api_service.dart';
import '../../data/inbox_stories_api_service.dart';
import 'inbox_light_premium_tokens.dart';

class InboxStoryDraft {
  const InboxStoryDraft({
    required this.mediaUrl,
    required this.mediaType,
    required this.visibility,
    this.caption,
  });

  final String mediaUrl;
  final String mediaType;
  final String visibility;
  final String? caption;
}

class InboxStoryRail extends StatelessWidget {
  const InboxStoryRail({
    super.key,
    required this.stories,
    required this.loading,
    required this.errorMessage,
    required this.onCreateStory,
    required this.onStoryTap,
    required this.onRetry,
  });

  final List<InboxStoryItem> stories;
  final bool loading;
  final String? errorMessage;
  final VoidCallback onCreateStory;
  final ValueChanged<InboxStoryItem> onStoryTap;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 122,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFFFF8FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: InboxLightPremiumTokens.border),
        boxShadow: [InboxLightPremiumTokens.softShadow(0.04)],
      ),
      child: errorMessage != null
          ? _StoryRailMessage(message: errorMessage!, onRetry: onRetry)
          : loading
          ? const _StoryRailLoading()
          : _StoryRailList(
              stories: stories,
              onCreateStory: onCreateStory,
              onStoryTap: onStoryTap,
            ),
    );
  }
}

class _StoryRailList extends StatelessWidget {
  const _StoryRailList({
    required this.stories,
    required this.onCreateStory,
    required this.onStoryTap,
  });

  final List<InboxStoryItem> stories;
  final VoidCallback onCreateStory;
  final ValueChanged<InboxStoryItem> onStoryTap;

  @override
  Widget build(BuildContext context) {
    final myStories = stories.where((story) => story.isMine).toList();
    final otherStories = stories.where((story) => !story.isMine).toList();
    final myStory = myStories.isEmpty ? null : myStories.first;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 9),
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      itemCount: otherStories.length + 1,
      separatorBuilder: (context, index) => const SizedBox(width: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _MyStoryBubble(
            story: myStory,
            onCreateStory: onCreateStory,
            onStoryTap: myStory == null ? null : () => onStoryTap(myStory),
          );
        }
        final story = otherStories[index - 1];
        return _StoryBubble(story: story, onTap: () => onStoryTap(story));
      },
    );
  }
}

class _MyStoryBubble extends StatelessWidget {
  const _MyStoryBubble({
    required this.story,
    required this.onCreateStory,
    required this.onStoryTap,
  });

  final InboxStoryItem? story;
  final VoidCallback onCreateStory;
  final VoidCallback? onStoryTap;

  @override
  Widget build(BuildContext context) {
    final currentStory = story;
    final hasStory = currentStory != null;
    return InkWell(
      onTap: hasStory ? onStoryTap : onCreateStory,
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        width: 70,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: InboxLightPremiumTokens.aquaGradient,
                    boxShadow: [
                      BoxShadow(
                        color: InboxLightPremiumTokens.aqua.withValues(
                          alpha: 0.18,
                        ),
                        blurRadius: 16,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: ClipOval(
                      child: hasStory
                          ? _StoryAvatar(story: currentStory)
                          : const DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: InboxLightPremiumTokens.pageGradient,
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.person_rounded,
                                  color: InboxLightPremiumTokens.violet,
                                  size: 28,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 1,
                  child: InkWell(
                    onTap: onCreateStory,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        gradient: InboxLightPremiumTokens.primaryGradient,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                  ),
                ),
                if (hasStory)
                  Positioned(
                    left: 2,
                    top: 2,
                    child: Container(
                      width: 15,
                      height: 15,
                      decoration: BoxDecoration(
                        color: InboxLightPremiumTokens.aqua,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              hasStory ? 'My story' : 'Your story',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: hasStory
                    ? InboxLightPremiumTokens.ink
                    : InboxLightPremiumTokens.muted,
                fontSize: 10.7,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryBubble extends StatelessWidget {
  const _StoryBubble({required this.story, required this.onTap});

  final InboxStoryItem story;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = story.isViewed
        ? const [Color(0xFFC7BECF), Color(0xFFE7E0EC)]
        : const [
            InboxLightPremiumTokens.pink,
            InboxLightPremiumTokens.warning,
            InboxLightPremiumTokens.violet,
          ];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        width: 70,
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              padding: EdgeInsets.all(story.isViewed ? 2 : 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(colors: [...colors, colors.first]),
                boxShadow: [
                  BoxShadow(
                    color: colors.last.withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(2),
                child: ClipOval(child: _StoryAvatar(story: story)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              story.ownerName.trim().isEmpty ? 'Story' : story.ownerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: story.isViewed
                    ? InboxLightPremiumTokens.muted
                    : InboxLightPremiumTokens.ink,
                fontSize: 10.7,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryAvatar extends StatelessWidget {
  const _StoryAvatar({required this.story});

  final InboxStoryItem story;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = story.ownerAvatarUrl?.trim();
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return Image.network(
        avatarUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _StoryInitials(story: story),
      );
    }
    return _StoryInitials(story: story);
  }
}

class _StoryInitials extends StatelessWidget {
  const _StoryInitials({required this.story});

  final InboxStoryItem story;

  @override
  Widget build(BuildContext context) {
    final name = story.ownerName.trim();
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: InboxLightPremiumTokens.primaryGradient,
      ),
      child: Center(
        child: Text(
          name.isEmpty ? 'S' : name.characters.first.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _StoryRailLoading extends StatelessWidget {
  const _StoryRailLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          color: InboxLightPremiumTokens.violet,
        ),
      ),
    );
  }
}

class _StoryRailMessage extends StatelessWidget {
  const _StoryRailMessage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onRetry,
      borderRadius: BorderRadius.circular(30),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: InboxLightPremiumTokens.danger.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.refresh_rounded,
                color: InboxLightPremiumTokens.danger,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: InboxLightPremiumTokens.muted,
                  fontSize: 12,
                  height: 1.3,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _StoryMediaSource { photo, video }

class InboxCreateStorySheet extends StatefulWidget {
  const InboxCreateStorySheet({super.key});

  @override
  State<InboxCreateStorySheet> createState() => _InboxCreateStorySheetState();
}

class _InboxCreateStorySheetState extends State<InboxCreateStorySheet> {
  final TextEditingController _caption = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final MediaUploadApiService _uploadApi = const MediaUploadApiService();

  XFile? _selectedFile;
  Uint8List? _previewBytes;
  String? _selectedName;
  int? _selectedBytes;
  String _mediaType = 'image';
  String _visibility = 'friends';
  bool _picking = false;
  bool _posting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pickStoryMedia() async {
    if (_picking || _posting) return;
    final source = await showModalBottomSheet<_StoryMediaSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _StoryMediaSourceSheet(),
    );
    if (source == null || !mounted) return;

    setState(() {
      _picking = true;
      _errorMessage = null;
    });

    try {
      final picked = source == _StoryMediaSource.video
          ? await _picker.pickVideo(source: ImageSource.gallery)
          : await _picker.pickImage(
              source: ImageSource.gallery,
              imageQuality: 92,
            );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        _setError('Selected media is empty.');
        return;
      }
      if (bytes.length > 20 * 1024 * 1024) {
        _setError('Story media must be 20 MB or smaller.');
        return;
      }

      setState(() {
        _selectedFile = picked;
        _previewBytes = source == _StoryMediaSource.photo ? bytes : null;
        _selectedName = picked.name;
        _selectedBytes = bytes.length;
        _mediaType = source == _StoryMediaSource.video ? 'video' : 'image';
        _errorMessage = null;
      });
    } catch (error) {
      _setError(_friendlyStoryError(error));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _postStory() async {
    final file = _selectedFile;
    if (file == null) {
      _setError('Choose a photo or video first.');
      return;
    }
    if (_posting) return;

    setState(() {
      _posting = true;
      _errorMessage = null;
    });

    try {
      final uploaded = await _uploadApi.uploadStoryMediaXFile(file);
      if (uploaded.url.trim().isEmpty) {
        throw Exception('Upload completed without a media URL.');
      }
      if (!mounted) return;
      Navigator.pop(
        context,
        InboxStoryDraft(
          mediaUrl: uploaded.url,
          mediaType: uploaded.mediaType == 'video' ? 'video' : _mediaType,
          visibility: _visibility,
          caption: _caption.text.trim().isEmpty ? null : _caption.text.trim(),
        ),
      );
    } catch (error) {
      if (mounted) _setError(_friendlyStoryError(error));
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  void _clearSelectedMedia() {
    if (_posting) return;
    setState(() {
      _selectedFile = null;
      _previewBytes = null;
      _selectedName = null;
      _selectedBytes = null;
      _mediaType = 'image';
      _errorMessage = null;
    });
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() => _errorMessage = message);
  }

  String _friendlyStoryError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    final lower = raw.toLowerCase();
    if (raw.contains('413')) {
      return 'This story is too large. Choose media under 20 MB.';
    }
    if (raw.contains('401') || lower.contains('login')) {
      return 'Session expired. Login again before posting.';
    }
    if (raw.contains('400') && lower.contains('unsupported')) {
      return 'Use JPG, PNG, WEBP, GIF, MP4, WEBM, or MOV.';
    }
    if (lower.contains('failed to fetch') || lower.contains('xmlhttprequest')) {
      return 'Upload failed. Check FastAPI is running and try again.';
    }
    return raw.isEmpty ? 'Could not post story. Please try again.' : raw;
  }

  @override
  Widget build(BuildContext context) {
    final selectedFile = _selectedFile;
    final hasMedia = selectedFile != null;
    final error = _errorMessage;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.90,
        ),
        padding: EdgeInsets.fromLTRB(
          16,
          10,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: InboxLightPremiumTokens.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 34,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SheetGrabber(),
              const SizedBox(height: 14),
              const _CreateStoryTitle(),
              const SizedBox(height: 16),
              _StoryMediaPickerCard(
                mediaType: _mediaType,
                previewBytes: _previewBytes,
                selectedName: _selectedName,
                selectedBytes: _selectedBytes,
                picking: _picking,
                posting: _posting,
                onTap: _pickStoryMedia,
                onClear: _clearSelectedMedia,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _caption,
                enabled: !_posting,
                maxLength: 500,
                maxLines: 3,
                minLines: 1,
                decoration: _storyInputDecoration(
                  label: 'Caption',
                  hint: 'Add a short moment...',
                ),
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                initialValue: _visibility,
                decoration: _storyInputDecoration(label: 'Privacy'),
                items: const [
                  DropdownMenuItem(value: 'friends', child: Text('Friends')),
                  DropdownMenuItem(value: 'everyone', child: Text('Everyone')),
                  DropdownMenuItem(value: 'nobody', child: Text('Only me')),
                ],
                onChanged: _posting
                    ? null
                    : (value) =>
                          setState(() => _visibility = value ?? 'friends'),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                _StoryErrorPill(message: error),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: !hasMedia || _posting ? null : _postStory,
                  icon: _posting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(_posting ? 'Posting...' : 'Post story'),
                  style: FilledButton.styleFrom(
                    backgroundColor: InboxLightPremiumTokens.ink,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFD7CBDD),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _storyInputDecoration({required String label, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: InboxLightPremiumTokens.pearl,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: InboxLightPremiumTokens.warmBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: InboxLightPremiumTokens.warmBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: InboxLightPremiumTokens.violet,
          width: 1.4,
        ),
      ),
    );
  }
}

class _CreateStoryTitle extends StatelessWidget {
  const _CreateStoryTitle();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                InboxLightPremiumTokens.aqua,
                InboxLightPremiumTokens.violet,
                InboxLightPremiumTokens.pink,
              ],
            ),
            borderRadius: BorderRadius.circular(17),
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: 23,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create story',
                style: TextStyle(
                  color: InboxLightPremiumTokens.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Share a photo or video from your gallery',
                style: TextStyle(
                  color: InboxLightPremiumTokens.muted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StoryMediaPickerCard extends StatelessWidget {
  const _StoryMediaPickerCard({
    required this.mediaType,
    required this.previewBytes,
    required this.selectedName,
    required this.selectedBytes,
    required this.picking,
    required this.posting,
    required this.onTap,
    required this.onClear,
  });

  final String mediaType;
  final Uint8List? previewBytes;
  final String? selectedName;
  final int? selectedBytes;
  final bool picking;
  final bool posting;
  final VoidCallback onTap;
  final VoidCallback onClear;

  bool get _hasMedia => selectedName != null;
  bool get _isVideo => mediaType == 'video';

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: posting ? null : onTap,
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: 0.78,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: DecoratedBox(
            decoration: const BoxDecoration(color: Color(0xFFF6F2EE)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (previewBytes != null)
                  Image.memory(previewBytes!, fit: BoxFit.cover)
                else if (_isVideo && _hasMedia)
                  const _VideoStoryPreview()
                else
                  _StoryMediaEmptyState(picking: picking),
                if (_hasMedia) const _StoryMediaGradient(),
                if (_hasMedia)
                  Positioned(
                    left: 12,
                    right: 58,
                    bottom: 12,
                    child: _StorySelectedBadge(
                      mediaType: mediaType,
                      name: selectedName ?? 'Story media',
                      bytes: selectedBytes,
                    ),
                  ),
                if (_hasMedia)
                  Positioned(
                    right: 12,
                    top: 12,
                    child: InkWell(
                      onTap: posting ? null : onClear,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.52),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                if (_hasMedia)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.52),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Change',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoStoryPreview extends StatelessWidget {
  const _VideoStoryPreview();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF12091F), Color(0xFF251538), Color(0xFF7C3AED)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.play_circle_fill_rounded,
          color: Colors.white,
          size: 72,
        ),
      ),
    );
  }
}

class _StoryMediaGradient extends StatelessWidget {
  const _StoryMediaGradient();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.08),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.62),
          ],
          stops: const [0, 0.42, 1],
        ),
      ),
    );
  }
}

class _StoryMediaEmptyState extends StatelessWidget {
  const _StoryMediaEmptyState({required this.picking});

  final bool picking;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (picking)
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                color: InboxLightPremiumTokens.ink,
                strokeWidth: 2.6,
              ),
            )
          else
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: InboxLightPremiumTokens.warmBorder),
              ),
              child: const Icon(
                Icons.add_photo_alternate_rounded,
                color: InboxLightPremiumTokens.ink,
                size: 38,
              ),
            ),
          const SizedBox(height: 14),
          Text(
            picking ? 'Opening gallery...' : 'Choose story media',
            style: const TextStyle(
              color: InboxLightPremiumTokens.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Photo or video, up to 20 MB',
            style: TextStyle(
              color: InboxLightPremiumTokens.muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StorySelectedBadge extends StatelessWidget {
  const _StorySelectedBadge({
    required this.mediaType,
    required this.name,
    required this.bytes,
  });

  final String mediaType;
  final String name;
  final int? bytes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            mediaType == 'video'
                ? Icons.play_circle_fill_rounded
                : Icons.photo_rounded,
            color: Colors.white,
            size: 17,
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              '${name.trim().isEmpty ? 'Selected media' : name.trim()}${bytes == null ? '' : ' - ${_formatStoryBytes(bytes!)}'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryMediaSourceSheet extends StatelessWidget {
  const _StoryMediaSourceSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(14),
      padding: EdgeInsets.fromLTRB(
        14,
        12,
        14,
        14 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _SheetGrabber(),
          const SizedBox(height: 14),
          const Text(
            'Choose media',
            style: TextStyle(
              color: InboxLightPremiumTokens.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          _StorySourceTile(
            icon: Icons.photo_rounded,
            title: 'Photo',
            subtitle: 'Pick an image from gallery',
            onTap: () => Navigator.pop(context, _StoryMediaSource.photo),
          ),
          _StorySourceTile(
            icon: Icons.play_circle_fill_rounded,
            title: 'Video',
            subtitle: 'Pick a video from gallery',
            onTap: () => Navigator.pop(context, _StoryMediaSource.video),
          ),
        ],
      ),
    );
  }
}

class _StorySourceTile extends StatelessWidget {
  const _StorySourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: InboxLightPremiumTokens.pearl,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: InboxLightPremiumTokens.ink,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: InboxLightPremiumTokens.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: InboxLightPremiumTokens.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: InboxLightPremiumTokens.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryErrorPill extends StatelessWidget {
  const _StoryErrorPill({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: InboxLightPremiumTokens.danger.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: InboxLightPremiumTokens.danger.withValues(alpha: 0.36),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: InboxLightPremiumTokens.danger,
            size: 17,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: InboxLightPremiumTokens.danger,
                fontSize: 11.5,
                height: 1.25,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class InboxStoryViewerSheet extends StatelessWidget {
  const InboxStoryViewerSheet({super.key, required this.story});

  final InboxStoryItem story;

  @override
  Widget build(BuildContext context) {
    final caption = story.caption?.trim();
    final isImage = _storyMediaIsImage(story.mediaType, story.mediaUrl);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height,
        child: Container(
          color: InboxLightPremiumTokens.ink,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: 1.2,
                      colors: [
                        InboxLightPremiumTokens.violet.withValues(alpha: 0.30),
                        InboxLightPremiumTokens.ink,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    10,
                    12,
                    12 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Column(
                    children: [
                      _StoryProgressHeader(story: story),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              color: Colors.black,
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (isImage)
                                  Image.network(
                                    story.mediaUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const _StoryMediaUnavailable(),
                                  )
                                else
                                  const _StoryVideoUnavailable(),
                                const _StoryViewerGradient(),
                                Positioned(
                                  left: 16,
                                  right: 16,
                                  bottom: 18,
                                  child: _StoryCaptionArea(caption: caption),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _StoryViewerActions(story: story),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 10,
                top: 8,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.26),
                  ),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryProgressHeader extends StatelessWidget {
  const _StoryProgressHeader({required this.story});

  final InboxStoryItem story;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 48),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 3,
              value: story.isViewed ? 1 : 0.18,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: InboxLightPremiumTokens.primaryGradient,
                ),
                child: ClipOval(child: _StoryAvatar(story: story)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      story.ownerName.trim().isEmpty
                          ? 'Story'
                          : story.ownerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_storyTimeLabel(story)}  •  ${_storyExpiresLabel(story)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        fontSize: 11.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StoryViewerGradient extends StatelessWidget {
  const _StoryViewerGradient();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.08),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.70),
          ],
          stops: const [0, 0.50, 1],
        ),
      ),
    );
  }
}

class _StoryCaptionArea extends StatelessWidget {
  const _StoryCaptionArea({required this.caption});

  final String? caption;

  @override
  Widget build(BuildContext context) {
    final text = caption;
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    return Text(
      text,
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        height: 1.35,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _StoryViewerActions extends StatelessWidget {
  const _StoryViewerActions({required this.story});

  final InboxStoryItem story;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StoryMetricPill(
          icon: Icons.visibility_rounded,
          label: '${story.viewCount} views',
        ),
        const SizedBox(width: 8),
        _StoryMetricPill(
          icon: story.isMine ? Icons.person_rounded : Icons.group_rounded,
          label: story.visibility,
        ),
      ],
    );
  }
}

class _StoryMetricPill extends StatelessWidget {
  const _StoryMetricPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryMediaUnavailable extends StatelessWidget {
  const _StoryMediaUnavailable();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Story media unavailable',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _StoryVideoUnavailable extends StatelessWidget {
  const _StoryVideoUnavailable();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 60),
          SizedBox(height: 10),
          Text(
            'Video story',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _SheetGrabber extends StatelessWidget {
  const _SheetGrabber();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 5,
        decoration: BoxDecoration(
          color: const Color(0xFFE0D5CB),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

String _formatStoryBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '$bytes B';
}

String friendlyInboxStoryLoadError(Object? error) {
  final raw = error?.toString().replaceFirst('Exception: ', '').trim() ?? '';
  final lower = raw.toLowerCase();
  if (raw.contains('401') || lower.contains('login')) {
    return 'Login needed for stories';
  }
  if (lower.contains('failed to fetch') || lower.contains('xmlhttprequest')) {
    return 'Stories offline. Tap retry.';
  }
  return 'Stories unavailable. Tap retry.';
}

bool _storyMediaIsImage(String mediaType, String mediaUrl) {
  final type = mediaType.toLowerCase();
  final url = mediaUrl.toLowerCase();
  if (type == 'video') return false;
  if (url.endsWith('.mp4') || url.endsWith('.webm') || url.endsWith('.mov')) {
    return false;
  }
  return true;
}

String _storyTimeLabel(InboxStoryItem story) {
  final created = story.createdAt;
  if (created == null) return story.isViewed ? 'Viewed' : 'New story';
  final elapsed = DateTime.now().difference(created);
  if (elapsed.inMinutes < 1) return 'Just now';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes}m ago';
  if (elapsed.inHours < 24) return '${elapsed.inHours}h ago';
  return '${elapsed.inDays}d ago';
}

String _storyExpiresLabel(InboxStoryItem story) {
  final expires = story.expiresAt;
  if (expires == null) return '24h story';
  final remaining = expires.difference(DateTime.now());
  if (remaining.isNegative) return 'Expired';
  if (remaining.inHours >= 1) return '${remaining.inHours}h left';
  final minutes = remaining.inMinutes.clamp(1, 59);
  return '${minutes}m left';
}
