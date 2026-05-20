import 'package:flutter/material.dart';

const String kMockInboxLockMobile = 'mock-inbox-lock-user';

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
  final _otp = TextEditingController();
  final _lock = TextEditingController();
  final _confirm = TextEditingController();
  bool _otpSent = false;
  bool _busy = false;
  String? _debugOtp;

  @override
  void dispose() {
    _otp.dispose();
    _lock.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    setState(() => _busy = true);
    try {
      final otp = await widget.onStartOtp(kMockInboxLockMobile);
      setState(() {
        _otpSent = true;
        _debugOtp = otp;
      });
      _toast(otp == null ? 'Verification code generated.' : 'Verification code: $otp');
    } catch (_) {
      _toast('Could not generate code. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmSetup() async {
    if (_otp.text.trim().isEmpty) {
      _toast('Enter the verification code.');
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
      await widget.onVerifySetup(kMockInboxLockMobile, _otp.text.trim(), _lock.text.trim());
      if (mounted) Navigator.pop(context);
      _toast('Inbox lock is ready.');
    } catch (_) {
      _toast('Setup failed. Check the code and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF111114), content: Text(message, style: const TextStyle(fontWeight: FontWeight.w700))));
  }

  @override
  Widget build(BuildContext context) {
    return _LockSheetScaffold(
      title: 'Set up Inbox lock',
      subtitle: 'Create a private lock for hidden conversations.',
      child: Column(
        children: [
          const _LockInfoCard(icon: Icons.lock_outline_rounded, text: 'Locked chats stay hidden until you unlock them.'),
          if (_otpSent) ...[
            const SizedBox(height: 10),
            _LockField(controller: _otp, label: 'Verification code', icon: Icons.sms_rounded, keyboardType: TextInputType.number),
            const SizedBox(height: 10),
            _LockField(controller: _lock, label: 'New lock', icon: Icons.lock_rounded, keyboardType: TextInputType.number, obscureText: true),
            const SizedBox(height: 10),
            _LockField(controller: _confirm, label: 'Re-enter new lock', icon: Icons.verified_user_rounded, keyboardType: TextInputType.number, obscureText: true),
            if (_debugOtp != null) ...[
              const SizedBox(height: 8),
              Text('Code: $_debugOtp', style: const TextStyle(color: Color(0xFF3797F0), fontSize: 11, fontWeight: FontWeight.w800)),
            ],
          ],
          const SizedBox(height: 14),
          _PrimaryLockButton(label: _otpSent ? 'Confirm setup' : 'Get code', busy: _busy, onTap: _otpSent ? _confirmSetup : _sendOtp),
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
      ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF111114), content: Text(message, style: const TextStyle(fontWeight: FontWeight.w700))));
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
          TextButton(onPressed: widget.onRecoverTap, child: const Text('Recover lock', style: TextStyle(fontWeight: FontWeight.w800))),
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
      ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF111114), content: Text(message, style: const TextStyle(fontWeight: FontWeight.w700))));
  }

  @override
  Widget build(BuildContext context) {
    return _LockSheetScaffold(
      title: 'Change Inbox lock',
      subtitle: 'Update your private chat lock.',
      child: Column(
        children: [
          _LockField(controller: _current, label: 'Current lock', icon: Icons.lock_open_rounded, keyboardType: TextInputType.number, obscureText: true),
          const SizedBox(height: 10),
          _LockField(controller: _newLock, label: 'New lock', icon: Icons.lock_rounded, keyboardType: TextInputType.number, obscureText: true),
          const SizedBox(height: 10),
          _LockField(controller: _confirm, label: 'Re-enter new lock', icon: Icons.verified_rounded, keyboardType: TextInputType.number, obscureText: true),
          const SizedBox(height: 14),
          _PrimaryLockButton(label: 'Save lock', busy: _busy, onTap: _change),
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
  final _otp = TextEditingController();
  final _newLock = TextEditingController();
  final _confirm = TextEditingController();
  bool _otpSent = false;
  bool _busy = false;
  String? _debugOtp;

  @override
  void dispose() {
    _otp.dispose();
    _newLock.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    setState(() => _busy = true);
    try {
      final otp = await widget.onStartRecovery(widget.registeredMobile?.trim().isNotEmpty == true ? widget.registeredMobile!.trim() : kMockInboxLockMobile);
      setState(() {
        _otpSent = true;
        _debugOtp = otp;
      });
      _toast(otp == null ? 'Recovery code generated.' : 'Recovery code: $otp');
    } catch (_) {
      _toast('Could not generate recovery code.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recover() async {
    if (_otp.text.trim().isEmpty) {
      _toast('Enter the recovery code.');
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
      await widget.onVerifyRecovery(widget.registeredMobile?.trim().isNotEmpty == true ? widget.registeredMobile!.trim() : kMockInboxLockMobile, _otp.text.trim(), _newLock.text.trim());
      if (mounted) Navigator.pop(context);
      _toast('Inbox lock recovered.');
    } catch (_) {
      _toast('Recovery failed. Check the code.');
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
      _toast('Could not submit recovery request.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF111114), content: Text(message, style: const TextStyle(fontWeight: FontWeight.w700))));
  }

  @override
  Widget build(BuildContext context) {
    return _LockSheetScaffold(
      title: 'Recover Inbox lock',
      subtitle: 'Reset your private lock with a recovery code.',
      child: Column(
        children: [
          const _LockInfoCard(icon: Icons.lock_reset_rounded, text: 'After recovery, use the new lock to access locked chats.'),
          if (_otpSent) ...[
            const SizedBox(height: 10),
            _LockField(controller: _otp, label: 'Recovery code', icon: Icons.sms_rounded, keyboardType: TextInputType.number),
            const SizedBox(height: 10),
            _LockField(controller: _newLock, label: 'New lock', icon: Icons.lock_reset_rounded, keyboardType: TextInputType.number, obscureText: true),
            const SizedBox(height: 10),
            _LockField(controller: _confirm, label: 'Re-enter new lock', icon: Icons.verified_rounded, keyboardType: TextInputType.number, obscureText: true),
            if (_debugOtp != null) ...[
              const SizedBox(height: 8),
              Text('Code: $_debugOtp', style: const TextStyle(color: Color(0xFF3797F0), fontSize: 11, fontWeight: FontWeight.w800)),
            ],
          ],
          const SizedBox(height: 14),
          _PrimaryLockButton(label: _otpSent ? 'Recover lock' : 'Get recovery code', busy: _busy, onTap: _otpSent ? _recover : _sendOtp),
          TextButton(onPressed: _busy ? null : _requestCs, child: const Text('Contact support', style: TextStyle(fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }
}

class _LockInfoCard extends StatelessWidget {
  const _LockInfoCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFBFDBFE))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF3797F0), size: 19),
          const SizedBox(width: 9),
          Expanded(child: Text(text, style: const TextStyle(color: Color(0xFF1E3A8A), fontSize: 11.7, height: 1.3, fontWeight: FontWeight.w600))),
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
        margin: const EdgeInsets.all(8),
        padding: EdgeInsets.fromLTRB(16, 10, 16, 14 + MediaQuery.paddingOf(context).bottom),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 28, offset: const Offset(0, 14))]),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: const Color(0xFFD4D4D8), borderRadius: BorderRadius.circular(999)))),
              const SizedBox(height: 14),
              Text(title, style: const TextStyle(color: Color(0xFF111114), fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
              const SizedBox(height: 5),
              Text(subtitle, style: const TextStyle(color: Color(0xFF71717A), fontSize: 12.3, height: 1.35, fontWeight: FontWeight.w500)),
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
        prefixIcon: Icon(icon, color: const Color(0xFF71717A), size: 20),
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF71717A), fontWeight: FontWeight.w600),
        filled: true,
        fillColor: const Color(0xFFF7F7F8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF3797F0), width: 1.3)),
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
      borderRadius: BorderRadius.circular(16),
      onTap: busy ? null : onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(color: const Color(0xFF3797F0), borderRadius: BorderRadius.circular(16)),
        child: Center(
          child: busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(label, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}
