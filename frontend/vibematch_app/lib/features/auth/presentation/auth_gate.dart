import 'package:flutter/material.dart';

import '../../../app/app_shell.dart';
import '../data/auth_api_service.dart';
import '../models/current_user.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthApiService _authApiService = AuthApiService();

  bool _isCheckingAuth = true;
  bool _isLoading = false;
  String? _error;
  CurrentUser? _currentUser;

  @override
  void initState() {
    super.initState();
    _checkSavedLogin();
  }

  Future<void> _checkSavedLogin() async {
    setState(() {
      _isCheckingAuth = true;
      _error = null;
    });

    try {
      final user = await _authApiService.getCurrentUser();
      if (mounted) setState(() => _currentUser = user);
    } catch (_) {
      if (mounted) setState(() => _currentUser = null);
    } finally {
      if (mounted) setState(() => _isCheckingAuth = false);
    }
  }

  Future<void> _loginWithDevAccount({
    required String email,
    required String username,
    required String displayName,
  }) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _authApiService.logout();
      final result = await _authApiService.devLogin(
        email: email,
        username: username,
        displayName: displayName,
      );
      final user = await _authApiService.getCurrentUser(accessToken: result.accessToken);
      if (mounted) setState(() => _currentUser = user);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await _authApiService.logout();
    if (!mounted) return;
    setState(() {
      _currentUser = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth) return const _LoadingScreen();

    if (_currentUser == null) {
      return _LoginScreen(
        isLoading: _isLoading,
        error: _error,
        onPhoneLoginPressed: () => _loginWithDevAccount(
          email: 'founder@vibematch.com',
          username: 'founder',
          displayName: 'Founder Owner',
        ),
        onGoogleLoginPressed: () => _loginWithDevAccount(
          email: 'google.tester@vibematch.dev',
          username: 'google_tester',
          displayName: 'Google Tester',
        ),
      );
    }

    return AppShell(
      currentUser: _currentUser!,
      onLogoutPressed: _logout,
      onRefreshPressed: _checkSavedLogin,
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFFBF8F2),
      body: Center(child: CircularProgressIndicator(color: Color(0xFF5B176A))),
    );
  }
}

class _LoginScreen extends StatelessWidget {
  const _LoginScreen({required this.isLoading, required this.error, required this.onPhoneLoginPressed, required this.onGoogleLoginPressed});

  final bool isLoading;
  final String? error;
  final VoidCallback onPhoneLoginPressed;
  final VoidCallback onGoogleLoginPressed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F2),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth > 520 ? 430.0 : constraints.maxWidth;
            return Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _LoginPeopleOrbit(),
                      const SizedBox(height: 36),
                      const Text(
                        'Let’s meet new\npeople around you',
                        textAlign: TextAlign.left,
                        style: TextStyle(color: Color(0xFF191423), fontSize: 34, height: 1.18, fontWeight: FontWeight.w900, letterSpacing: -0.9),
                      ),
                      const SizedBox(height: 34),
                      _PrimaryLoginButton(label: 'Login with Phone', helper: 'Internal test: Founder Owner', icon: Icons.phone_in_talk_rounded, isLoading: isLoading, onTap: onPhoneLoginPressed),
                      const SizedBox(height: 18),
                      _GoogleLoginButton(isLoading: isLoading, onTap: onGoogleLoginPressed),
                      if (error != null) ...[
                        const SizedBox(height: 18),
                        _LoginErrorBox(error: error!),
                      ],
                      const SizedBox(height: 22),
                      Text(
                        'By continuing, you agree to Vibe Match Terms, Privacy Policy, and Community Guidelines.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: const Color(0xFF4B4055).withValues(alpha: 0.62), fontSize: 11.5, fontWeight: FontWeight.w700, height: 1.35),
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

class _LoginPeopleOrbit extends StatelessWidget {
  const _LoginPeopleOrbit();

  static const List<_OrbitAvatarData> _avatars = [
    _OrbitAvatarData(top: 8, left: 28, size: 78, colors: [Color(0xFFFFD8E4), Color(0xFFE8B6C4)], initial: 'R'),
    _OrbitAvatarData(top: 0, left: 184, size: 56, colors: [Color(0xFF22324A), Color(0xFF7E5064)], initial: 'H'),
    _OrbitAvatarData(top: 76, left: 136, size: 92, colors: [Color(0xFFFFE0F2), Color(0xFFD7F0FF)], initial: 'A'),
    _OrbitAvatarData(top: 90, left: 308, size: 62, colors: [Color(0xFFFFD5C7), Color(0xFFEBC3D7)], initial: 'M'),
    _OrbitAvatarData(top: 188, left: 44, size: 56, colors: [Color(0xFF111827), Color(0xFFD45B75)], initial: 'S'),
    _OrbitAvatarData(top: 212, left: 214, size: 42, colors: [Color(0xFFFFE8CC), Color(0xFFCDB1A2)], initial: 'K'),
    _OrbitAvatarData(top: 272, left: 150, size: 64, colors: [Color(0xFFBFDCE8), Color(0xFF161A24)], initial: 'V'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 334,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: CustomPaint(painter: _OrbitLinePainter())),
          for (final avatar in _avatars) Positioned(top: avatar.top, left: avatar.left, child: _OrbitAvatar(data: avatar)),
          Positioned(right: 18, top: 20, child: _FloatingBubble(icon: Icons.location_on_rounded, size: 44)),
          Positioned(left: 118, bottom: 50, child: _FloatingBubble(icon: Icons.more_horiz_rounded, size: 44)),
        ],
      ),
    );
  }
}

class _OrbitAvatar extends StatelessWidget {
  const _OrbitAvatar({required this.data});

  final _OrbitAvatarData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: data.size,
      height: data.size,
      padding: EdgeInsets.all(data.size > 70 ? 4 : 3),
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: [BoxShadow(color: const Color(0xFF5B176A).withValues(alpha: 0.09), blurRadius: 22, offset: const Offset(0, 10))]),
      child: Container(
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: data.colors)),
        child: Center(
          child: Text(
            data.initial,
            style: TextStyle(color: Colors.white, fontSize: data.size * 0.36, fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 8)]),
          ),
        ),
      ),
    );
  }
}

class _FloatingBubble extends StatelessWidget {
  const _FloatingBubble({required this.icon, required this.size});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: const Color(0xFF8D4AA2).withValues(alpha: 0.78), borderRadius: BorderRadius.circular(17), boxShadow: [BoxShadow(color: const Color(0xFF8D4AA2).withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 8))]),
      child: Icon(icon, color: Colors.white, size: size * 0.48),
    );
  }
}

class _PrimaryLoginButton extends StatelessWidget {
  const _PrimaryLoginButton({required this.label, required this.helper, required this.icon, required this.isLoading, required this.onTap});

  final String label;
  final String helper;
  final IconData icon;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          height: 76,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Color(0xFF5B176A), Color(0xFF6E2379), Color(0xFF4D145E)]),
            boxShadow: [BoxShadow(color: const Color(0xFF5B176A).withValues(alpha: 0.24), blurRadius: 26, offset: const Offset(0, 14))],
          ),
          child: Row(
            children: [
              const SizedBox(width: 11),
              Container(
                width: 54,
                height: 54,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: isLoading ? const Padding(padding: EdgeInsets.all(15), child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF5B176A))) : Icon(icon, color: const Color(0xFF5B176A), size: 29),
              ),
              const SizedBox(width: 26),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.2)),
                    const SizedBox(height: 3),
                    Text(helper, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.62), fontSize: 11, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(width: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleLoginButton extends StatelessWidget {
  const _GoogleLoginButton({required this.isLoading, required this.onTap});

  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          height: 66,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.72), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE9DEE8))),
          child: const Row(
            children: [
              Text('G', style: TextStyle(color: Color(0xFF4285F4), fontSize: 29, fontWeight: FontWeight.w900)),
              SizedBox(width: 38),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Login with Google', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Color(0xFF5B176A), fontSize: 17, fontWeight: FontWeight.w900)),
                    SizedBox(height: 3),
                    Text('Internal test: Normal user', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Color(0xFF89798F), fontSize: 11, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginErrorBox extends StatelessWidget {
  const _LoginErrorBox({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFE84C72).withValues(alpha: 0.09), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE84C72).withValues(alpha: 0.42))),
      child: Text(error, style: const TextStyle(color: Color(0xFFE84C72), fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}

class _OrbitLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF5B176A).withValues(alpha: 0.055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final path = Path()
      ..moveTo(size.width * 0.19, size.height * 0.24)
      ..cubicTo(size.width * 0.34, size.height * 0.02, size.width * 0.62, size.height * 0.10, size.width * 0.72, size.height * 0.34)
      ..cubicTo(size.width * 0.86, size.height * 0.66, size.width * 0.48, size.height * 0.76, size.width * 0.33, size.height * 0.58)
      ..cubicTo(size.width * 0.18, size.height * 0.40, size.width * 0.40, size.height * 0.30, size.width * 0.52, size.height * 0.42);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OrbitAvatarData {
  const _OrbitAvatarData({required this.top, required this.left, required this.size, required this.colors, required this.initial});

  final double top;
  final double left;
  final double size;
  final List<Color> colors;
  final String initial;
}
