import 'package:flutter/material.dart';

import '../../media/data/media_upload_service.dart';
import '../data/auth_api_service.dart';
import '../models/current_user.dart';

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({
    super.key,
    required this.user,
    required this.onCompleted,
    required this.onLogoutPressed,
  });

  final CurrentUser user;
  final ValueChanged<CurrentUser> onCompleted;
  final Future<void> Function() onLogoutPressed;

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final AuthApiService _authApi = const AuthApiService();
  final MediaUploadService _mediaUpload = const MediaUploadService();
  late final TextEditingController _nameController;
  String? _avatarUrl;
  bool _isPickingPhoto = false;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.user.displayName?.trim().isNotEmpty == true
          ? widget.user.displayName!.trim()
          : widget.user.username?.trim() ?? '',
    );
    _avatarUrl = widget.user.avatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickProfilePhoto() async {
    if (_isPickingPhoto || _isSaving) return;
    setState(() {
      _isPickingPhoto = true;
      _error = null;
    });

    try {
      final uploaded = await _mediaUpload.pickCropAndUploadAvatar(context);
      if (!mounted) return;
      setState(() => _avatarUrl = uploaded.url);
    } on MediaUploadCancelledException {
      // User cancelled image picking/cropping. Keep the setup screen open.
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  Future<void> _saveProfile() async {
    if (_isSaving) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your display name.');
      return;
    }
    if (name.length < 2) {
      setState(() => _error = 'Name should be at least 2 characters.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final updated = await _authApi.updateProfile(
        displayName: name,
        bio: widget.user.bio,
        avatarUrl: _avatarUrl,
      );
      if (!mounted) return;
      widget.onCompleted(updated);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String get _avatarLetter {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) return name[0].toUpperCase();
    final username = widget.user.username?.trim();
    if (username != null && username.isNotEmpty) return username[0].toUpperCase();
    return 'F';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0820),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth > 520 ? 430.0 : constraints.maxWidth;
            return Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isSaving ? null : widget.onLogoutPressed,
                          child: const Text(
                            'Logout',
                            style: TextStyle(
                              color: Color(0xFFFF7AAE),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Set up your\nFunKey profile',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          height: 1.08,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.9,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Add your profile photo and display name. These details will appear on your Me page, chatrooms, seats, gifts and public profile.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.70),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF3E9D).withValues(alpha: 0.12),
                              blurRadius: 36,
                              offset: const Offset(0, 18),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _pickProfilePhoto,
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  Container(
                                    width: 122,
                                    height: 122,
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFF22F5FF),
                                          Color(0xFFFF2FA3),
                                          Color(0xFFFFB45E),
                                        ],
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      backgroundColor: const Color(0xFF17102F),
                                      backgroundImage: _avatarUrl?.trim().isNotEmpty == true
                                          ? NetworkImage(_avatarUrl!.trim())
                                          : null,
                                      child: _avatarUrl?.trim().isNotEmpty == true
                                          ? null
                                          : Text(
                                              _avatarLetter,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 44,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                    ),
                                  ),
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF3E9D),
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: _isPickingPhoto
                                        ? const Padding(
                                            padding: EdgeInsets.all(9),
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.camera_alt_rounded,
                                            color: Colors.white,
                                            size: 19,
                                          ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 13),
                            TextButton.icon(
                              onPressed: _isPickingPhoto || _isSaving ? null : _pickProfilePhoto,
                              icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
                              label: Text(_avatarUrl?.trim().isNotEmpty == true ? 'Change profile photo' : 'Add profile photo'),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF22F5FF),
                                textStyle: const TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: _nameController,
                              maxLength: 30,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _saveProfile(),
                              onChanged: (_) => setState(() {}),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                              ),
                              decoration: InputDecoration(
                                counterStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
                                labelText: 'Display name',
                                labelStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.64),
                                  fontWeight: FontWeight.w800,
                                ),
                                hintText: 'Enter your name',
                                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.36)),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.08),
                                prefixIcon: const Icon(Icons.badge_rounded, color: Color(0xFF22F5FF)),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(color: Color(0xFF22F5FF), width: 1.4),
                                ),
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF4F73).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFFF4F73).withValues(alpha: 0.34)),
                                ),
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: Color(0xFFFFA0B5),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 22),
                            SizedBox(
                              width: double.infinity,
                              height: 58,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _saveProfile,
                                style: ElevatedButton.styleFrom(
                                  elevation: 0,
                                  backgroundColor: const Color(0xFFFF3E9D),
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2.3, color: Colors.white),
                                      )
                                    : const Text(
                                        'Continue to FunKey',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
