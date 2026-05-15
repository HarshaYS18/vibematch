import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../models/vibe_models.dart';

class CreateVibeMediaPicker extends StatelessWidget {
  const CreateVibeMediaPicker({
    super.key,
    required this.type,
    required this.selectedFile,
    required this.selectedBytes,
    required this.picking,
    required this.uploading,
    required this.uploadedUrl,
    required this.onTap,
    required this.onClear,
  });

  final VibeMediaType type;
  final File? selectedFile;
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
                          _MediaPrompt(picking: picking, uploading: uploading),
                        if (hasFile) const _PreviewGradient(),
                        if (hasFile) Positioned(left: 12, bottom: 12, child: _SelectedMediaBadge(type: type, bytes: selectedBytes)),
                        if (!hasFile) Positioned(left: 12, bottom: 12, right: 12, child: _ChooseMediaHint(picking: picking, uploading: uploading)),
                        if (hasFile)
                          Positioned(
                            right: 12,
                            top: 12,
                            child: InkWell(
                              onTap: uploading ? null : onClear,
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.48), shape: BoxShape.circle),
                                child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                        if (hasFile)
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: InkWell(
                              onTap: uploading ? null : onTap,
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.54), borderRadius: BorderRadius.circular(999)),
                                child: const Text('Change', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                              ),
                            ),
                          ),
                        if (uploadedUrl != null && uploadedUrl!.trim().isNotEmpty)
                          Positioned(
                            left: 12,
                            top: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(color: const Color(0xFF111015).withValues(alpha: 0.80), borderRadius: BorderRadius.circular(999)),
                              child: const Text('Uploaded', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class CreateVibeMediaSourceSheet extends StatelessWidget {
  const CreateVibeMediaSourceSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(14),
      padding: EdgeInsets.fromLTRB(14, 12, 14, 14 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 42, height: 5, decoration: BoxDecoration(color: const Color(0xFFE0D5CB), borderRadius: BorderRadius.circular(999))),
          const SizedBox(height: 14),
          const Text('Choose media', style: TextStyle(color: Color(0xFF111015), fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          _MediaSourceTile(icon: Icons.photo_rounded, title: 'Photo', subtitle: 'Pick an image from gallery', onTap: () => Navigator.pop(context, VibeMediaType.photo)),
          _MediaSourceTile(icon: Icons.play_circle_fill_rounded, title: 'Video', subtitle: 'Pick a video from gallery', onTap: () => Navigator.pop(context, VibeMediaType.video)),
        ],
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
    _initializeController();
  }

  @override
  void didUpdateWidget(covariant _LocalVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      _controller?.dispose();
      _ready = false;
      _hasError = false;
      _initializeController();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _initializeController() {
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
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_hasError) return const Center(child: Icon(Icons.movie_creation_rounded, color: Color(0xFF111015), size: 54));
    if (controller == null || !_ready) return const Center(child: CircularProgressIndicator(color: Color(0xFF111015), strokeWidth: 2.6));
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(width: controller.value.size.width, height: controller.value.size.height, child: VideoPlayer(controller)),
    );
  }
}

class _PreviewGradient extends StatelessWidget {
  const _PreviewGradient();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.06), Colors.transparent, Colors.black.withValues(alpha: 0.56)],
            stops: const [0, 0.48, 1],
          ),
        ),
      ),
    );
  }
}

class _SelectedMediaBadge extends StatelessWidget {
  const _SelectedMediaBadge({required this.type, required this.bytes});

  final VibeMediaType type;
  final int? bytes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.54), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type == VibeMediaType.video ? Icons.play_circle_fill_rounded : Icons.photo_rounded, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text('${type.label}${bytes == null ? '' : ' · ${_formatBytes(bytes!)}'}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _ChooseMediaHint extends StatelessWidget {
  const _ChooseMediaHint({required this.picking, required this.uploading});

  final bool picking;
  final bool uploading;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        picking ? 'Opening gallery...' : uploading ? 'Uploading...' : 'Tap to choose photo or video',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFF111015), fontSize: 13, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _MediaSourceTile extends StatelessWidget {
  const _MediaSourceTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

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
        decoration: BoxDecoration(color: const Color(0xFFFAF7F1), borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFF111015), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: Colors.white, size: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Color(0xFF111015), fontSize: 14, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: Color(0xFF8C8198), fontSize: 11.5, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF8C8198)),
          ],
        ),
      ),
    );
  }
}

class _MediaPrompt extends StatelessWidget {
  const _MediaPrompt({required this.picking, required this.uploading});

  final bool picking;
  final bool uploading;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (picking || uploading)
            const SizedBox(width: 34, height: 34, child: CircularProgressIndicator(color: Color(0xFF111015), strokeWidth: 2.6))
          else
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), border: Border.all(color: const Color(0xFFECE2D8))),
              child: const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF111015), size: 38),
            ),
          const SizedBox(height: 14),
          const Text('Create Media Vibe', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF111015), fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          const Text('Photo or video preview will appear here', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF8C8198), fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '$bytes B';
}
