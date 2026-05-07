import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../auth/models/current_user.dart';
import '../public_profile_view_page.dart';
import '../widgets/me_profile_constants.dart';
import 'profile_qr_payload.dart';

class ProfileQrActionsSheet extends StatelessWidget {
  const ProfileQrActionsSheet({
    super.key,
    required this.user,
    this.title = 'Profile QR',
  });

  final CurrentUser user;
  final String title;

  static Future<void> show(BuildContext context, {required CurrentUser user, String title = 'Profile QR'}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProfileQrActionsSheet(user: user, title: title),
    );
  }

  void _openScanner(BuildContext context) {
    Navigator.pop(context);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileQrScannerPage()),
    );
  }

  void _openMyQr(BuildContext context) {
    Navigator.pop(context);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MyProfileQrPage(user: user)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      margin: const EdgeInsets.all(14),
      padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFECE2D8)),
        boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.14), blurRadius: 28, offset: const Offset(0, 12))],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF6D5DF6), Color(0xFFE84C72)])),
                  child: const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Color(0xFF251538), fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
                      const SizedBox(height: 2),
                      const Text('Scan a profile or show your own QR.', style: TextStyle(color: Color(0xFF7B6A86), fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ProfileQrActionTile(
              icon: Icons.qr_code_scanner_rounded,
              title: 'Scan QR',
              subtitle: 'Use camera or select a QR from gallery.',
              color: const Color(0xFF12C7B7),
              onTap: () => _openScanner(context),
            ),
            const SizedBox(height: 10),
            _ProfileQrActionTile(
              icon: Icons.qr_code_2_rounded,
              title: 'My QR',
              subtitle: 'Generate a Vibe Match profile QR.',
              color: const Color(0xFF6D5DF6),
              onTap: () => _openMyQr(context),
            ),
          ],
        ),
      ),
    );
  }
}

class MyProfileQrPage extends StatelessWidget {
  const MyProfileQrPage({super.key, required this.user});

  final CurrentUser user;

  @override
  Widget build(BuildContext context) {
    final payload = ProfileQrPayload.fromUser(user);
    final qrValue = payload.toQrValue();
    final displayName = payload.titleName;
    final roleLabel = _roleLabel(user.primaryRole);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: Column(
          children: [
            _ProfileQrHeader(title: 'My QR', onBack: () => Navigator.pop(context)),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: _profileQrPanelDecoration(radius: 34),
                    child: Column(
                      children: [
                        _ProfileQrAvatar(name: displayName),
                        const SizedBox(height: 12),
                        Text(displayName, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF251538), fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                        const SizedBox(height: 5),
                        Text('ID ${payload.visibleId} • $roleLabel', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 12.5, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 22),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: const Color(0xFFECE2D8)),
                            boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.06), blurRadius: 24, offset: const Offset(0, 12))],
                          ),
                          child: QrImageView(
                            data: qrValue,
                            version: QrVersions.auto,
                            size: 248,
                            gapless: false,
                            embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(46, 46)),
                            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: Color(0xFF251538)),
                            dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: Color(0xFF251538)),
                            errorCorrectionLevel: QrErrorCorrectLevel.H,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Ask friends to scan this inside Vibe Match to open your profile directly.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF7B6A86), fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ProfileQrInfoCard(
                    icon: Icons.verified_user_rounded,
                    title: 'Only Vibe Match profile QR codes work',
                    body: 'Other QR codes will show “Invalid QR” and will not navigate anywhere.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role.trim().toLowerCase()) {
      case 'founder_owner':
        return 'Founder Owner';
      case 'super_owner':
        return 'Super Owner';
      case 'owner':
        return 'Owner';
      case 'superadmin':
        return 'SuperAdmin';
      case 'admin':
        return 'Admin';
      case 'monitor':
        return 'Monitor';
      case 'cs':
        return 'CS';
      default:
        return 'User';
    }
  }
}

class ProfileQrScannerPage extends StatefulWidget {
  const ProfileQrScannerPage({super.key});

  @override
  State<ProfileQrScannerPage> createState() => _ProfileQrScannerPageState();
}

class _ProfileQrScannerPageState extends State<ProfileQrScannerPage> {
  late final MobileScannerController _scannerController;
  final ImagePicker _imagePicker = ImagePicker();
  bool _handlingScan = false;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [BarcodeFormat.qrCode],
    );
  }

  @override
  void dispose() {
    unawaited(_scannerController.dispose());
    super.dispose();
  }

  void _showMessage(String message) {
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

  Future<void> _handleRawValue(String? rawValue) async {
    if (_handlingScan) return;
    _handlingScan = true;

    final payload = ProfileQrPayload.tryParse(rawValue);
    if (payload == null) {
      if (mounted) _showMessage('Invalid QR');
      await Future<void>.delayed(const Duration(milliseconds: 900));
      _handlingScan = false;
      return;
    }

    await _scannerController.stop();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PublicProfileViewPage(
          user: payload.toResolvedUser(),
          vipLevel: MeProfileConstants.vipLevel,
          svipLevel: MeProfileConstants.svipLevel,
          presenceLabel: 'Online',
          currentRoomName: null,
          relationshipLabel: 'Friend Match',
          familyName: MeProfileConstants.familyName,
          familyLevel: MeProfileConstants.familyLevel,
        ),
      ),
    );
  }

  Future<void> _pickAndAnalyzeImage() async {
    if (_handlingScan) return;

    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 100);
      if (image == null) return;

      final capture = await _scannerController.analyzeImage(image.path);
      final rawValue = capture?.barcodes.isNotEmpty == true ? capture!.barcodes.first.rawValue : null;
      await _handleRawValue(rawValue);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Invalid QR');
      _handlingScan = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08050D),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: MobileScanner(
                controller: _scannerController,
                onDetect: (capture) {
                  final rawValue = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
                  unawaited(_handleRawValue(rawValue));
                },
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.45),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(top: 10, left: 10, right: 10, child: _ProfileQrScannerTopBar(onBack: () => Navigator.pop(context))),
            Center(child: _ScannerFrame()),
            Positioned(
              left: 18,
              right: 18,
              bottom: 18 + MediaQuery.paddingOf(context).bottom,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Scan a Vibe Match profile QR',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Only valid profile QR codes can open a profile.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.76), fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _ScannerBottomButton(
                          icon: Icons.photo_library_rounded,
                          label: 'Select from gallery',
                          onTap: _pickAndAnalyzeImage,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _ScannerIconButton(
                        icon: Icons.flash_on_rounded,
                        onTap: () => unawaited(_scannerController.toggleTorch()),
                      ),
                      const SizedBox(width: 10),
                      _ScannerIconButton(
                        icon: Icons.cameraswitch_rounded,
                        onTap: () => unawaited(_scannerController.switchCamera()),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileQrActionTile extends StatelessWidget {
  const _ProfileQrActionTile({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFFAF7F1), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFECE2D8))),
        child: Row(
          children: [
            Container(width: 46, height: 46, decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(color: Color(0xFF251538), fontSize: 15.5, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w700, height: 1.25)),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF7B6A86), size: 24),
          ],
        ),
      ),
    );
  }
}

class _ProfileQrHeader extends StatelessWidget {
  const _ProfileQrHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(10, 10, 16, 12),
      child: Row(
        children: [
          IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF251538), size: 28)),
          Expanded(child: Text(title, style: const TextStyle(color: Color(0xFF251538), fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.4))),
        ],
      ),
    );
  }
}

class _ProfileQrAvatar extends StatelessWidget {
  const _ProfileQrAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? 'V' : name.trim()[0].toUpperCase();
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.14), blurRadius: 18, offset: const Offset(0, 8))]),
      child: Container(
        width: 88,
        height: 88,
        decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF6D5DF6), Color(0xFFE84C72), Color(0xFFFFD36A)])),
        child: Center(child: Text(letter, style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900))),
      ),
    );
  }
}

class _ProfileQrInfoCard extends StatelessWidget {
  const _ProfileQrInfoCard({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _profileQrPanelDecoration(radius: 24),
      child: Row(
        children: [
          Container(width: 42, height: 42, decoration: const BoxDecoration(color: Color(0x1412C7B7), shape: BoxShape.circle), child: const Icon(Icons.verified_user_rounded, color: Color(0xFF12C7B7), size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Color(0xFF251538), fontSize: 14, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(body, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, height: 1.3, fontWeight: FontWeight.w700)),
          ])),
        ],
      ),
    );
  }
}

class _ProfileQrScannerTopBar extends StatelessWidget {
  const _ProfileQrScannerTopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ScannerIconButton(icon: Icons.arrow_back_rounded, onTap: onBack),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 46,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.32), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withValues(alpha: 0.18))),
            child: const Text('Profile QR Scanner', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
          ),
        ),
      ],
    );
  }
}

class _ScannerFrame extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      height: 260,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: Colors.white.withValues(alpha: 0.88), width: 2.2),
      ),
      child: Stack(
        children: const [
          Positioned(left: 18, top: 18, child: _ScannerCorner()),
          Positioned(right: 18, top: 18, child: RotatedBox(quarterTurns: 1, child: _ScannerCorner())),
          Positioned(right: 18, bottom: 18, child: RotatedBox(quarterTurns: 2, child: _ScannerCorner())),
          Positioned(left: 18, bottom: 18, child: RotatedBox(quarterTurns: 3, child: _ScannerCorner())),
        ],
      ),
    );
  }
}

class _ScannerCorner extends StatelessWidget {
  const _ScannerCorner();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: const Color(0xFF12C7B7).withValues(alpha: 0.95), width: 5), left: BorderSide(color: const Color(0xFF12C7B7).withValues(alpha: 0.95), width: 5)),
        ),
      ),
    );
  }
}

class _ScannerBottomButton extends StatelessWidget {
  const _ScannerBottomButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 18, offset: const Offset(0, 8))]),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: const Color(0xFF251538), size: 21), const SizedBox(width: 8), Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF251538), fontSize: 13, fontWeight: FontWeight.w900)))]),
      ),
    );
  }
}

class _ScannerIconButton extends StatelessWidget {
  const _ScannerIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.34), shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.18))),
        child: Icon(icon, color: Colors.white, size: 23),
      ),
    );
  }
}

BoxDecoration _profileQrPanelDecoration({required double radius}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: const Color(0xFFECE2D8)),
    boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.04), blurRadius: 18, offset: const Offset(0, 9))],
  );
}
