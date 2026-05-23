import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

class AppLifecycleLockGate extends StatefulWidget {
  const AppLifecycleLockGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppLifecycleLockGate> createState() => _AppLifecycleLockGateState();
}

class _AppLifecycleLockGateState extends State<AppLifecycleLockGate>
    with WidgetsBindingObserver {
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _locked = false;
  bool _authenticating = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _forceLock();
        break;
      case AppLifecycleState.resumed:
        // Stay locked on resume. The user must explicitly pass device auth.
        if (_locked && !_authenticating) {
          setState(() => _errorText = null);
        }
        break;
    }
  }

  void _forceLock() {
    if (!mounted) return;
    if (_locked) return;
    setState(() {
      _locked = true;
      _authenticating = false;
      _errorText = null;
    });
  }

  Future<void> _unlock() async {
    if (_authenticating) return;
    setState(() {
      _authenticating = true;
      _errorText = null;
    });

    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final supported = await _localAuth.isDeviceSupported();
      if (!canCheck && !supported) {
        if (!mounted) return;
        setState(() {
          _authenticating = false;
          _errorText = 'Device lock is not available on this device.';
        });
        return;
      }

      final unlocked = await _localAuth.authenticate(
        localizedReason: 'Unlock FunKey to continue',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          sensitiveTransaction: true,
        ),
      );

      if (!mounted) return;
      setState(() {
        _locked = !unlocked;
        _authenticating = false;
        _errorText = unlocked ? null : 'Unlock cancelled. Authenticate to continue.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _authenticating = false;
        _errorText = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_locked) _AppLifecycleLockOverlay(
          authenticating: _authenticating,
          errorText: _errorText,
          onUnlock: _unlock,
        ),
      ],
    );
  }
}

class _AppLifecycleLockOverlay extends StatelessWidget {
  const _AppLifecycleLockOverlay({
    required this.authenticating,
    required this.errorText,
    required this.onUnlock,
  });

  final bool authenticating;
  final String? errorText;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: const Color(0xFF120D1F),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF12C7B7), Color(0xFF8C5CF6)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF12C7B7).withValues(alpha: 0.25),
                          blurRadius: 30,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'FunKey Locked',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Unlock with your device lock to continue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.68),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      errorText!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFE84C72),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: authenticating ? null : onUnlock,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF12C7B7),
                        foregroundColor: const Color(0xFF120D1F),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon: authenticating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.fingerprint_rounded),
                      label: Text(
                        authenticating ? 'Checking...' : 'Unlock',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
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