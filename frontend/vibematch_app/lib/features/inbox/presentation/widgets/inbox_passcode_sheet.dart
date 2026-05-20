import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../../data/inbox_preferences_api_service.dart';
import 'inbox_light_premium_tokens.dart';

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
  final TextEditingController _controller = TextEditingController();
  final LocalAuthentication _localAuth = LocalAuthentication();
  final InboxPreferencesApiService _preferencesApi = const InboxPreferencesApiService();
  bool _obscure = true;
  bool _busy = false;
  bool _biometricBusy = false;
  bool _deviceUnlockAllowed = false;
  bool _canUseBiometrics = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrapDeviceUnlock();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _bootstrapDeviceUnlock() async {
    var allowed = widget.deviceUnlockEnabled;
    try {
      final preferences = await _preferencesApi.loadPreferences();
      allowed = allowed || preferences.deviceUnlockEnabled;
    } catch (_) {
      // Keep constructor-provided value if settings cannot be loaded yet.
    }
    if (!mounted) return;
    setState(() => _deviceUnlockAllowed = allowed);
    await _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    if (!_deviceUnlockAllowed) return;
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!mounted) return;
      setState(() => _canUseBiometrics = supported || canCheck);
    } catch (_) {
      if (mounted) setState(() => _canUseBiometrics = false);
    }
  }

  Future<void> _unlockWithBiometrics() async {
    if (!_deviceUnlockAllowed || !_canUseBiometrics || _biometricBusy) return;
    setState(() {
      _biometricBusy = true;
      _error = null;
    });
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: 'Unlock your locked Vibe Match chats',
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
      if (mounted) setState(() => _biometricBusy = false);
    }
  }

  Future<void> _submit() async {
    if (_controller.text.trim().isEmpty) {
      setState(() => _error = 'Enter your Inbox lock.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final valid = await widget.onValidate(_controller.text.trim());
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Container(
          padding: EdgeInsets.fromLTRB(18, 10, 18, 18 + safeBottom),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 30, offset: const Offset(0, 14))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 42, height: 5, decoration: BoxDecoration(color: const Color(0xFFE0D5CB), borderRadius: BorderRadius.circular(999))),
              const SizedBox(height: 16),
              Container(width: 62, height: 62, decoration: BoxDecoration(color: InboxLightPremiumTokens.ink, borderRadius: BorderRadius.circular(22)), child: const Icon(Icons.lock_rounded, color: Colors.white, size: 30)),
              const SizedBox(height: 13),
              Text(widget.title, textAlign: TextAlign.center, style: const TextStyle(color: InboxLightPremiumTokens.ink, fontSize: 21, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(widget.subtitle, textAlign: TextAlign.center, style: const TextStyle(color: InboxLightPremiumTokens.muted, fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              if (_deviceUnlockAllowed && _canUseBiometrics) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _biometricBusy ? null : _unlockWithBiometrics,
                    style: OutlinedButton.styleFrom(foregroundColor: InboxLightPremiumTokens.ink, padding: const EdgeInsets.symmetric(vertical: 13), side: const BorderSide(color: InboxLightPremiumTokens.warmBorder), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                    icon: _biometricBusy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: InboxLightPremiumTokens.ink)) : const Icon(Icons.fingerprint_rounded, size: 22),
                    label: const Text('Unlock with device', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(height: 12),
                const Row(children: [Expanded(child: Divider(color: InboxLightPremiumTokens.warmBorder)), Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('or', style: TextStyle(color: InboxLightPremiumTokens.softMuted, fontWeight: FontWeight.w800))), Expanded(child: Divider(color: InboxLightPremiumTokens.warmBorder))]),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _controller,
                obscureText: _obscure,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                style: const TextStyle(color: InboxLightPremiumTokens.ink, fontWeight: FontWeight.w900),
                decoration: InputDecoration(
                  hintText: 'Enter Inbox lock',
                  errorText: _error,
                  prefixIcon: const Icon(Icons.password_rounded, color: InboxLightPremiumTokens.violet),
                  suffixIcon: IconButton(onPressed: () => setState(() => _obscure = !_obscure), icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded)),
                  filled: true,
                  fillColor: InboxLightPremiumTokens.page,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: InboxLightPremiumTokens.warmBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: InboxLightPremiumTokens.warmBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: InboxLightPremiumTokens.violet, width: 1.4)),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(backgroundColor: InboxLightPremiumTokens.ink, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                  icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.lock_open_rounded, size: 18),
                  label: const Text('Unlock', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
              if (widget.onRecoverTap != null) ...[
                const SizedBox(height: 8),
                TextButton(onPressed: _busy ? null : widget.onRecoverTap, child: const Text('Recover lock', style: TextStyle(fontWeight: FontWeight.w900))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
