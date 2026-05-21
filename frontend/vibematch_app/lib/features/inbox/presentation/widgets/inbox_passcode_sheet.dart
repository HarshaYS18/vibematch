import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../../data/inbox_preferences_api_service.dart';

class InboxPasscodeSheet extends StatefulWidget {
  const InboxPasscodeSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onValidate,
    required this.onUnlocked,
    this.onRecoverTap,
    this.deviceUnlockEnabled = false,
  });

  final String title;
  final String subtitle;
  final Future<bool> Function(String passcode) onValidate;
  final VoidCallback onUnlocked;
  final VoidCallback? onRecoverTap;
  final bool deviceUnlockEnabled;

  @override
  State<InboxPasscodeSheet> createState() => _InboxPasscodeSheetState();
}

class _InboxPasscodeSheetState extends State<InboxPasscodeSheet> {
  static const _ink = Color(0xFF111114);
  static const _muted = Color(0xFF71717A);
  static const _line = Color(0xFFEDEDEF);
  static const _blue = Color(0xFF3797F0);

  final TextEditingController _controller = TextEditingController();
  final LocalAuthentication _localAuth = LocalAuthentication();
  final InboxPreferencesApiService _preferencesApi = const InboxPreferencesApiService();

  bool _obscure = true;
  bool _busy = false;
  bool _deviceBusy = false;
  bool _deviceUnlockAllowed = false;
  bool _canUseDeviceUnlock = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDeviceUnlockState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadDeviceUnlockState() async {
    var allowed = widget.deviceUnlockEnabled;
    try {
      final preferences = await _preferencesApi.loadPreferences();
      allowed = allowed || preferences.deviceUnlockEnabled;
    } catch (_) {}

    if (!mounted) return;
    setState(() => _deviceUnlockAllowed = allowed);
    if (!allowed) return;

    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!mounted) return;
      setState(() => _canUseDeviceUnlock = supported || canCheck);
    } catch (_) {
      if (mounted) setState(() => _canUseDeviceUnlock = false);
    }
  }

  Future<void> _unlockWithDevice() async {
    if (!_deviceUnlockAllowed || !_canUseDeviceUnlock || _deviceBusy) return;

    setState(() {
      _deviceBusy = true;
      _error = null;
    });

    try {
      final ok = await _localAuth.authenticate(
        localizedReason: 'Unlock your locked FunKey chats',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (!mounted) return;

      if (ok) {
        widget.onUnlocked();
      } else {
        setState(() => _error = 'Device unlock cancelled.');
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Device unlock is not available on this device.');
    } finally {
      if (mounted) setState(() => _deviceBusy = false);
    }
  }

  Future<void> _submit() async {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _error = 'Enter your Inbox lock.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final valid = await widget.onValidate(value);
    if (!mounted) return;
    setState(() => _busy = false);

    if (valid) {
      widget.onUnlocked();
      return;
    }

    setState(() => _error = 'Wrong lock. Try again or recover.');
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final keyboardInset = mediaQuery.viewInsets.bottom;
    final safeBottom = mediaQuery.padding.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(8),
        child: Container(
          padding: EdgeInsets.fromLTRB(18, 10, 18, 16 + safeBottom),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 38, height: 4, decoration: BoxDecoration(color: const Color(0xFFD4D4D8), borderRadius: BorderRadius.circular(999))),
              const SizedBox(height: 16),
              Container(width: 60, height: 60, decoration: const BoxDecoration(color: Color(0xFFF1F1F3), shape: BoxShape.circle), child: const Icon(Icons.lock_outline_rounded, color: _ink, size: 28)),
              const SizedBox(height: 13),
              Text(widget.title, textAlign: TextAlign.center, style: const TextStyle(color: _ink, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
              const SizedBox(height: 6),
              Text(widget.subtitle, textAlign: TextAlign.center, style: const TextStyle(color: _muted, fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w500)),
              const SizedBox(height: 16),
              if (_deviceUnlockAllowed && _canUseDeviceUnlock) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _deviceBusy ? null : _unlockWithDevice,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _ink,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: const BorderSide(color: _line),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: _deviceBusy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _ink))
                        : const Icon(Icons.fingerprint_rounded, size: 22),
                    label: const Text('Unlock with device', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 12),
                const Row(children: [
                  Expanded(child: Divider(color: _line)),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('or', style: TextStyle(color: _muted, fontWeight: FontWeight.w700))),
                  Expanded(child: Divider(color: _line)),
                ]),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _controller,
                obscureText: _obscure,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                style: const TextStyle(color: _ink, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: 'Enter Inbox lock',
                  errorText: _error,
                  prefixIcon: const Icon(Icons.password_rounded, color: _muted),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: _muted),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF7F7F8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _blue, width: 1.3)),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: _busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.lock_open_rounded, size: 18),
                  label: const Text('Unlock', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              if (widget.onRecoverTap != null) ...[
                const SizedBox(height: 8),
                TextButton(onPressed: _busy ? null : widget.onRecoverTap, child: const Text('Recover lock', style: TextStyle(fontWeight: FontWeight.w800))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
