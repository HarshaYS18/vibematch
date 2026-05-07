import 'package:flutter/material.dart';

class InboxLockSetupSheet extends StatefulWidget {
  const InboxLockSetupSheet({
    super.key,
    required this.onStartOtp,
    required this.onVerifySetup,
  });

  final Future<String?> Function(String mobileNumber) onStartOtp;
  final Future<void> Function(String mobileNumber, String otp, String lockCode) onVerifySetup;

  @override
  State<InboxLockSetupSheet> createState() => _InboxLockSetupSheetState();
}

class _InboxLockSetupSheetState extends State<InboxLockSetupSheet> {
  final _mobile = TextEditingController();
  final _otp = TextEditingController();
  final _lock = TextEditingController();
  final _confirm = TextEditingController();
  bool _otpSent = false;
  bool _busy = false;
  String? _debugOtp;

  @override
  void dispose() {
    _mobile.dispose();
    _otp.dispose();
    _lock.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_mobile.text.trim().length < 8) {
      _toast('Enter a valid mobile number.');
      return;
    }
    setState(() => _busy = true);
    try {
      final otp = await widget.onStartOtp(_mobile.text.trim());
      setState(() {
        _otpSent = true;
        _debugOtp = otp;
      });
      _toast(otp == null ? 'OTP sent to your mobile number.' : 'OTP sent. Dev OTP: $otp');
    } catch (error) {
      _toast('Could not send OTP. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmSetup() async {
    if (_otp.text.trim().isEmpty) {
      _toast('Enter the OTP.');
      return;
    }
    if (_lock.text.trim().length < 4) {
      _toast('Lock must be at least 4 digits.');
      return;
    }
    if (_lock.text.trim() != _confirm.text.trim()) {
      _toast('Lock confirmation does not match.');
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.onVerifySetup(_mobile.text.trim(), _otp.text.trim(), _lock.text.trim());
      if (mounted) Navigator.pop(context);
      _toast('Inbox lock setup completed.');
    } catch (error) {
      _toast('Setup failed. Check OTP and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF251538), content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800))));
  }

  @override
  Widget build(BuildContext context) {
    return _LockSheetScaffold(
      title: 'Set up Inbox Lock',
      subtitle: 'Link your mobile number, verify OTP, then create your private chat lock.',
      child: Column(
        children: [
          _LockField(controller: _mobile, label: 'Mobile number', icon: Icons.phone_rounded, keyboardType: TextInputType.phone, enabled: !_otpSent),
          if (_otpSent) ...[
            const SizedBox(height: 10),
            _LockField(controller: _otp, label: 'OTP', icon: Icons.sms_rounded, keyboardType: TextInputType.number),
            const SizedBox(height: 10),
            _LockField(controller: _lock, label: 'New lock', icon: Icons.lock_rounded, keyboardType: TextInputType.number, obscureText: true),
            const SizedBox(height: 10),
            _LockField(controller: _confirm, label: 'Re-enter new lock', icon: Icons.verified_user_rounded, keyboardType: TextInputType.number, obscureText: true),
            if (_debugOtp != null) ...[
              const SizedBox(height: 8),
              Text('Dev OTP: $_debugOtp', style: const TextStyle(color: Color(0xFFE84C72), fontSize: 11, fontWeight: FontWeight.w900)),
            ],
          ],
          const SizedBox(height: 14),
          _PrimaryLockButton(label: _otpSent ? 'Confirm setup' : 'Send OTP', busy: _busy, onTap: _otpSent ? _confirmSetup : _sendOtp),
        ],
      ),
    );
  }
}

class InboxLockVerifySheet extends StatefulWidget {
  const InboxLockVerifySheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onVerify,
    required this.onRecoverTap,
  });

  final String title;
  final String subtitle;
  final Future<bool> Function(String lockCode) onVerify;
  final VoidCallback onRecoverTap;

  @override
  State<InboxLockVerifySheet> createState() => _InboxLockVerifySheetState();
}

class _InboxLockVerifySheetState extends State<InboxLockVerifySheet> {
  final _lock = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _lock.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_lock.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final ok = await widget.onVerify(_lock.text.trim());
    if (mounted) setState(() => _busy = false);
    if (ok && mounted) {
      Navigator.pop(context, true);
      return;
    }
    _toast('Incorrect lock. Try again or recover.');
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF251538), content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800))));
  }

  @override
  Widget build(BuildContext context) {
    return _LockSheetScaffold(
      title: widget.title,
      subtitle: widget.subtitle,
      child: Column(
        children: [
          _LockField(controller: _lock, label: 'Inbox lock', icon: Icons.lock_rounded, keyboardType: TextInputType.number, obscureText: true),
          const SizedBox(height: 12),
          _PrimaryLockButton(label: 'Unlock', busy: _busy, onTap: _verify),
          TextButton(onPressed: widget.onRecoverTap, child: const Text('Recover lock', style: TextStyle(fontWeight: FontWeight.w900))),
        ],
      ),
    );
  }
}

class InboxLockChangeSheet extends StatefulWidget {
  const InboxLockChangeSheet({
    super.key,
    required this.onChangeLock,
  });

  final Future<void> Function(String currentLock, String newLock) onChangeLock;

  @override
  State<InboxLockChangeSheet> createState() => _InboxLockChangeSheetState();
}

class _InboxLockChangeSheetState extends State<InboxLockChangeSheet> {
  final _current = TextEditingController();
  final _newLock = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _newLock.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _change() async {
    if (_current.text.trim().isEmpty) {
      _toast('Enter current lock.');
      return;
    }
    if (_newLock.text.trim().length < 4) {
      _toast('New lock must be at least 4 digits.');
      return;
    }
    if (_newLock.text.trim() != _confirm.text.trim()) {
      _toast('New lock confirmation does not match.');
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.onChangeLock(_current.text.trim(), _newLock.text.trim());
      if (mounted) Navigator.pop(context);
      _toast('Inbox lock changed.');
    } catch (_) {
      _toast('Could not change lock. Check current lock.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF251538), content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800))));
  }

  @override
  Widget build(BuildContext context) {
    return _LockSheetScaffold(
      title: 'Change Inbox Lock',
      subtitle: 'Enter your current lock, set a new lock, then confirm it.',
      child: Column(
        children: [
          _LockField(controller: _current, label: 'Current lock', icon: Icons.lock_open_rounded, keyboardType: TextInputType.number, obscureText: true),
          const SizedBox(height: 10),
          _LockField(controller: _newLock, label: 'New lock', icon: Icons.lock_rounded, keyboardType: TextInputType.number, obscureText: true),
          const SizedBox(height: 10),
          _LockField(controller: _confirm, label: 'Re-enter new lock', icon: Icons.verified_rounded, keyboardType: TextInputType.number, obscureText: true),
          const SizedBox(height: 14),
          _PrimaryLockButton(label: 'Confirm change', busy: _busy, onTap: _change),
        ],
      ),
    );
  }
}

class InboxLockRecoverySheet extends StatefulWidget {
  const InboxLockRecoverySheet({
    super.key,
    required this.registeredMobile,
    required this.onStartRecovery,
    required this.onVerifyRecovery,
    required this.onRequestCs,
  });

  final String? registeredMobile;
  final Future<String?> Function(String mobileNumber) onStartRecovery;
  final Future<void> Function(String mobileNumber, String otp, String newLock) onVerifyRecovery;
  final Future<String> Function() onRequestCs;

  @override
  State<InboxLockRecoverySheet> createState() => _InboxLockRecoverySheetState();
}

class _InboxLockRecoverySheetState extends State<InboxLockRecoverySheet> {
  final _mobile = TextEditingController();
  final _otp = TextEditingController();
  final _newLock = TextEditingController();
  final _confirm = TextEditingController();
  bool _otpSent = false;
  bool _busy = false;
  String? _debugOtp;

  @override
  void initState() {
    super.initState();
    _mobile.text = widget.registeredMobile ?? '';
  }

  @override
  void dispose() {
    _mobile.dispose();
    _otp.dispose();
    _newLock.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    setState(() => _busy = true);
    try {
      final otp = await widget.onStartRecovery(_mobile.text.trim());
      setState(() {
        _otpSent = true;
        _debugOtp = otp;
      });
      _toast(otp == null ? 'Recovery OTP sent.' : 'Recovery OTP sent. Dev OTP: $otp');
    } catch (_) {
      _toast('Mobile number did not match or OTP failed.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recover() async {
    if (_newLock.text.trim().length < 4) {
      _toast('New lock must be at least 4 digits.');
      return;
    }
    if (_newLock.text.trim() != _confirm.text.trim()) {
      _toast('New lock confirmation does not match.');
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.onVerifyRecovery(_mobile.text.trim(), _otp.text.trim(), _newLock.text.trim());
      if (mounted) Navigator.pop(context);
      _toast('Inbox lock recovered.');
    } catch (_) {
      _toast('Recovery failed. Check OTP.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestCs() async {
    setState(() => _busy = true);
    try {
      final message = await widget.onRequestCs();
      if (mounted) Navigator.pop(context);
      _toast(message);
    } catch (_) {
      _toast('Could not submit CS recovery request.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF251538), content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800))));
  }

  @override
  Widget build(BuildContext context) {
    return _LockSheetScaffold(
      title: 'Recover Inbox Lock',
      subtitle: 'Confirm your identity using OTP sent to the registered mobile number. If unavailable, contact CS.',
      child: Column(
        children: [
          _LockField(controller: _mobile, label: 'Registered mobile number', icon: Icons.phone_rounded, keyboardType: TextInputType.phone, enabled: !_otpSent),
          if (_otpSent) ...[
            const SizedBox(height: 10),
            _LockField(controller: _otp, label: 'Recovery OTP', icon: Icons.sms_rounded, keyboardType: TextInputType.number),
            const SizedBox(height: 10),
            _LockField(controller: _newLock, label: 'New lock', icon: Icons.lock_reset_rounded, keyboardType: TextInputType.number, obscureText: true),
            const SizedBox(height: 10),
            _LockField(controller: _confirm, label: 'Re-enter new lock', icon: Icons.verified_rounded, keyboardType: TextInputType.number, obscureText: true),
            if (_debugOtp != null) ...[
              const SizedBox(height: 8),
              Text('Dev OTP: $_debugOtp', style: const TextStyle(color: Color(0xFFE84C72), fontSize: 11, fontWeight: FontWeight.w900)),
            ],
          ],
          const SizedBox(height: 14),
          _PrimaryLockButton(label: _otpSent ? 'Recover lock' : 'Send recovery OTP', busy: _busy, onTap: _otpSent ? _recover : _sendOtp),
          TextButton(onPressed: _busy ? null : _requestCs, child: const Text('Contact CS for recovery', style: TextStyle(fontWeight: FontWeight.w900))),
        ],
      ),
    );
  }
}

class _LockSheetScaffold extends StatelessWidget {
  const _LockSheetScaffold({required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(14),
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.paddingOf(context).bottom),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 30, offset: const Offset(0, 14))]),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: const Color(0xFFE0D5CB), borderRadius: BorderRadius.circular(999)))),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(color: Color(0xFF251538), fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Text(subtitle, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 12.2, height: 1.35, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _LockField extends StatelessWidget {
  const _LockField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      enabled: enabled,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: const Color(0xFF4A2A63), size: 20),
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF7B6A86), fontWeight: FontWeight.w800),
        filled: true,
        fillColor: const Color(0xFFFAF7F1),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFECE2D8))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFECE2D8))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFF12C7B7), width: 1.4)),
      ),
    );
  }
}

class _PrimaryLockButton extends StatelessWidget {
  const _PrimaryLockButton({required this.label, required this.busy, required this.onTap});

  final String label;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: busy ? null : onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF251538), Color(0xFF6D5DF6)]), borderRadius: BorderRadius.circular(18)),
        child: Center(
          child: busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(label, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }
}
