import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/public_profile_models.dart';

class EditCoverPhotosPage extends StatefulWidget {
  const EditCoverPhotosPage({super.key});

  @override
  State<EditCoverPhotosPage> createState() => _EditCoverPhotosPageState();
}

class _EditCoverPhotosPageState extends State<EditCoverPhotosPage> {
  final ImagePicker _imagePicker = ImagePicker();
  late final List<_CoverPhotoDraft> _coverPhotos = publicProfileCoverPhotos
      .map((photo) => _CoverPhotoDraft.fromPublicCover(photo))
      .toList(growable: true);
  bool _isPicking = false;

  void _toast(String message) {
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

  Future<void> _addCoverPhoto() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);

    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 88);
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      setState(() {
        _coverPhotos.add(
          _CoverPhotoDraft.fromBytes(
            title: picked.name.trim().isEmpty ? 'New Cover ${_coverPhotos.length + 1}' : picked.name.trim(),
            bytes: bytes,
          ),
        );
      });
      _toast('Cover photo added locally. Save to confirm.');
    } catch (_) {
      if (mounted) _toast('Could not add cover photo.');
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _deleteCoverPhoto(int index) {
    if (_coverPhotos.length <= 1) {
      _toast('At least one cover photo is required.');
      return;
    }

    setState(() => _coverPhotos.removeAt(index));
    _toast('Cover photo removed locally. Save to confirm.');
  }

  void _saveCoverPhotos() {
    _toast('Cover photos saved locally. Backend cover photo API will connect later.');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: Column(
          children: [
            _CoverEditorHeader(onBack: () => Navigator.pop(context), onSave: _saveCoverPhotos),
            Expanded(
              child: GridView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.82,
                ),
                itemCount: _coverPhotos.length + 1,
                itemBuilder: (context, index) {
                  if (index == _coverPhotos.length) {
                    return _AddCoverPhotoCard(isPicking: _isPicking, onTap: _addCoverPhoto);
                  }

                  return _CoverPhotoTile(
                    cover: _coverPhotos[index],
                    onDelete: () => _deleteCoverPhoto(index),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverPhotoDraft {
  const _CoverPhotoDraft({
    required this.title,
    required this.colors,
    required this.icon,
    this.bytes,
  });

  final String title;
  final List<Color> colors;
  final IconData icon;
  final Uint8List? bytes;

  factory _CoverPhotoDraft.fromPublicCover(PublicCoverPhoto photo) {
    return _CoverPhotoDraft(
      title: photo.title,
      colors: photo.colors,
      icon: photo.icon,
    );
  }

  factory _CoverPhotoDraft.fromBytes({required String title, required Uint8List bytes}) {
    return _CoverPhotoDraft(
      title: title,
      bytes: bytes,
      icon: Icons.image_rounded,
      colors: const [Color(0xFF251538), Color(0xFF6D5DF6), Color(0xFFE84C72)],
    );
  }
}

class _CoverEditorHeader extends StatelessWidget {
  const _CoverEditorHeader({required this.onBack, required this.onSave});

  final VoidCallback onBack;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(10, 10, 16, 12),
      child: Row(
        children: [
          IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF251538), size: 28)),
          const Expanded(
            child: Text(
              'Edit Cover Photos',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Color(0xFF251538), fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -0.4),
            ),
          ),
          InkWell(
            onTap: onSave,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFF251538), borderRadius: BorderRadius.circular(999)),
              child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverPhotoTile extends StatelessWidget {
  const _CoverPhotoTile({required this.cover, required this.onDelete});

  final _CoverPhotoDraft cover;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final bytes = cover.bytes;

    return Container(
      decoration: _coverCardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (bytes == null)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: cover.colors,
                ),
              ),
              child: Center(child: Icon(cover.icon, color: Colors.white.withValues(alpha: 0.88), size: 42)),
            )
          else
            Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.58)],
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: InkWell(
              onTap: onDelete,
              customBorder: const CircleBorder(),
              child: Container(
                width: 31,
                height: 31,
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.52), shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.36))),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 19),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Text(
              cover.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w900, height: 1.15),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddCoverPhotoCard extends StatelessWidget {
  const _AddCoverPhotoCard({required this.isPicking, required this.onTap});

  final bool isPicking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isPicking ? null : onTap,
      borderRadius: BorderRadius.circular(26),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFECE2D8), width: 1.2),
          boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 8))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF12C7B7), Color(0xFF6D5DF6)])),
              child: isPicking
                  ? const Padding(
                      padding: EdgeInsets.all(17),
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : const Icon(Icons.add_rounded, color: Colors.white, size: 34),
            ),
            const SizedBox(height: 12),
            Text(
              isPicking ? 'Opening gallery...' : 'Add cover photo',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF251538), fontSize: 14, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'Pick an image from your gallery.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w700, height: 1.25),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _coverCardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(26),
    border: Border.all(color: const Color(0xFFECE2D8)),
    boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.05), blurRadius: 18, offset: const Offset(0, 9))],
  );
}
