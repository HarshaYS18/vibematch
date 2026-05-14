import 'package:flutter/material.dart';

import '../../../media/data/media_upload_service.dart';
import '../../data/profile_api_service.dart';

class EditCoverPhotosPage extends StatefulWidget {
  const EditCoverPhotosPage({super.key, required this.initialCoverPhotoUrls});

  final List<String> initialCoverPhotoUrls;

  @override
  State<EditCoverPhotosPage> createState() => _EditCoverPhotosPageState();
}

class _EditCoverPhotosPageState extends State<EditCoverPhotosPage> {
  final MediaUploadService _mediaUploadService = const MediaUploadService();
  final ProfileApiService _profileApiService = const ProfileApiService();

  late final List<String> _coverPhotoUrls = widget.initialCoverPhotoUrls.map((url) => url.trim()).where((url) => url.isNotEmpty).toList(growable: true);

  bool _isUploading = false;
  bool _isSaving = false;

  void _toast(String message) {
    ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF251538), content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800))));
  }

  Future<void> _addCoverPhoto() async {
    if (_isUploading || _isSaving) return;
    if (_coverPhotoUrls.length >= 6) {
      _toast('Maximum 6 cover photos allowed.');
      return;
    }

    setState(() => _isUploading = true);
    try {
      final upload = await _mediaUploadService.pickCropAndUploadProfileCover(context);
      if (!mounted) return;
      setState(() => _coverPhotoUrls.add(upload.url));
      _toast('Cover cropped and uploaded. Tap Save to apply.');
    } on MediaUploadCancelledException {
      return;
    } catch (error) {
      if (!mounted) return;
      _toast(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _deleteCoverPhoto(int index) {
    setState(() => _coverPhotoUrls.removeAt(index));
    _toast('Cover removed. Tap Save to apply.');
  }

  Future<void> _saveCoverPhotos() async {
    if (_isSaving || _isUploading) return;
    setState(() => _isSaving = true);
    try {
      await _profileApiService.updateCoverPhotoUrls(_coverPhotoUrls);
      if (!mounted) return;
      _toast('Cover photos saved.');
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      _toast(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = _coverPhotoUrls.length + 1;
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: Column(
          children: [
            _CoverEditorHeader(onBack: () => Navigator.pop(context), onSave: _saveCoverPhotos, saving: _isSaving),
            Expanded(
              child: GridView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 16 / 9),
                itemCount: itemCount,
                itemBuilder: (context, index) {
                  if (index == _coverPhotoUrls.length) return _AddCoverPhotoCard(isUploading: _isUploading, onTap: _addCoverPhoto);
                  return _CoverPhotoTile(imageUrl: _coverPhotoUrls[index], onDelete: () => _deleteCoverPhoto(index));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverEditorHeader extends StatelessWidget {
  const _CoverEditorHeader({required this.onBack, required this.onSave, required this.saving});
  final VoidCallback onBack;
  final VoidCallback onSave;
  final bool saving;
  @override
  Widget build(BuildContext context) => Container(color: Colors.white, padding: const EdgeInsets.fromLTRB(10, 10, 16, 12), child: Row(children: [IconButton(onPressed: saving ? null : onBack, icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF251538), size: 28)), const Expanded(child: Text('Edit Cover Photos', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Color(0xFF251538), fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -0.4))), InkWell(onTap: saving ? null : onSave, borderRadius: BorderRadius.circular(999), child: Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10), decoration: BoxDecoration(color: const Color(0xFF251538).withValues(alpha: saving ? 0.55 : 1), borderRadius: BorderRadius.circular(999)), child: Text(saving ? 'Saving...' : 'Save', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))))]));
}

class _CoverPhotoTile extends StatelessWidget {
  const _CoverPhotoTile({required this.imageUrl, required this.onDelete});
  final String imageUrl;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) => Container(decoration: _coverCardDecoration(), clipBehavior: Clip.antiAlias, child: Stack(fit: StackFit.expand, children: [Image.network(imageUrl, fit: BoxFit.cover, alignment: Alignment.center, filterQuality: FilterQuality.high, errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFF251538), alignment: Alignment.center, child: const Icon(Icons.broken_image_rounded, color: Colors.white70, size: 34))), Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: 0.58)])))), Positioned(top: 8, right: 8, child: InkWell(onTap: onDelete, customBorder: const CircleBorder(), child: Container(width: 31, height: 31, decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.52), shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.36))), child: const Icon(Icons.close_rounded, color: Colors.white, size: 19))))]));
}

class _AddCoverPhotoCard extends StatelessWidget {
  const _AddCoverPhotoCard({required this.isUploading, required this.onTap});
  final bool isUploading;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: isUploading ? null : onTap, borderRadius: BorderRadius.circular(26), child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), border: Border.all(color: const Color(0xFFECE2D8), width: 1.2), boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 8))]), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 42, height: 42, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF12C7B7), Color(0xFF6D5DF6)])), child: isUploading ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)) : const Icon(Icons.edit_rounded, color: Colors.white, size: 22)), const SizedBox(height: 9), Text(isUploading ? 'Uploading...' : 'Upload Cover', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF251538), fontSize: 13, fontWeight: FontWeight.w900)), const SizedBox(height: 4), const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('16:9 crop with 3×3 grid.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF7B6A86), fontSize: 10.5, fontWeight: FontWeight.w700, height: 1.2)))])));
}

BoxDecoration _coverCardDecoration() => BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), border: Border.all(color: const Color(0xFFECE2D8)), boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.05), blurRadius: 18, offset: const Offset(0, 9))]);
