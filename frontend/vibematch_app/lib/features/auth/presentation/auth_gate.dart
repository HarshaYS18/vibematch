import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_shell.dart';
import '../../../identity/data/identity_repository.dart';
import '../../../session/data/session_repository.dart';
import '../data/auth_api_service.dart';
import '../data/google_sign_in_config.dart';
import '../data/google_sign_in_session_service.dart';
import '../models/current_user.dart';
import 'profile_setup_page.dart';

Future<bool> resolveProfileSetupRequirement({
  required CurrentUser user,
}) async {
  return !user.profileSetupCompleted;
}

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  final GoogleSignInSessionService _googleSignIn =
      GoogleSignInSessionService.instance;

  bool _isCheckingAuth = true;
  bool _isLoading = false;
  bool _needsProfileSetup = false;
  String? _error;
  CurrentUser? _currentUser;
  StreamSubscription<void>? _signedOutSubscription;

  @override
  void initState() {
    super.initState();
    _signedOutSubscription = AuthUserRealtimeService.instance.signedOut.listen(
      (_) => _handleSessionSignedOut(),
    );
    _checkSavedLogin();
  }

  @override
  void dispose() {
    _signedOutSubscription?.cancel();
    super.dispose();
  }

  void _handleSessionSignedOut() {
    ref.read(sessionRepositoryProvider.notifier).handleExternalSignOut();
    ref.read(identityRepositoryProvider.notifier).clear();
    if (!mounted) return;
    setState(() {
      _currentUser = null;
      _needsProfileSetup = false;
      _error = 'Signed out because this account was opened on another device.';
    });
  }

  Future<void> _checkSavedLogin() async {
    setState(() {
      _isCheckingAuth = true;
      _error = null;
    });

    try {
      final user = await ref.read(sessionRepositoryProvider.notifier).restore();
      ref.read(identityRepositoryProvider.notifier).accept(user);
      final needsSetup = await _shouldShowProfileSetup(user);
      if (mounted) {
        setState(() {
          _currentUser = user;
          _needsProfileSetup = needsSetup;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _currentUser = null;
          _needsProfileSetup = false;
        });
      }
    } finally {
      if (mounted) setState(() => _isCheckingAuth = false);
    }
  }

  Future<void> _loginWithFounderTest() async {
    await _loginWithDevAccount(
      email: 'founder@vibematch.com',
      username: 'founder',
      displayName: 'Founder Owner',
      label: 'Founder test login',
    );
  }

  Future<void> _loginWithNormalTestUser() async {
    await _loginWithDevAccount(
      email: 'testuser@vibematch.com',
      username: 'test_user',
      displayName: 'Test User',
      label: 'Test user login',
    );
  }

  Future<void> _loginWithDevAccount({
    required String email,
    required String username,
    required String displayName,
    required String label,
  }) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ref.read(sessionRepositoryProvider.notifier).logout();
      ref.read(identityRepositoryProvider.notifier).clear();
      await _googleSignIn.signOutIfUsed();
      final user = await ref.read(sessionRepositoryProvider.notifier).devLogin(
        email: email,
        username: username,
        displayName: displayName,
      );
      ref.read(identityRepositoryProvider.notifier).accept(user);
      final needsSetup = await _shouldShowProfileSetup(user);
      if (mounted) {
        setState(() {
          _currentUser = user;
          _needsProfileSetup = needsSetup;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$label failed: $error\nMake sure backend .env has ENABLE_DEV_LOGIN=true and restart backend.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ref.read(sessionRepositoryProvider.notifier).logout();
      ref.read(identityRepositoryProvider.notifier).clear();
      await _googleSignIn.signOutIfUsed();
      final account = await _googleSignIn.signIn();
      if (account == null) {
        if (mounted) setState(() => _error = 'Google login cancelled.');
        return;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.trim().isEmpty) {
        throw Exception('Google did not return an ID token. ${GoogleSignInConfig.setupHint}');
      }

      final user = await ref
          .read(sessionRepositoryProvider.notifier)
          .googleLogin(idToken: idToken);
      ref.read(identityRepositoryProvider.notifier).accept(user);
      final needsSetup = await _shouldShowProfileSetup(user);
      if (mounted) {
        setState(() {
          _currentUser = user;
          _needsProfileSetup = needsSetup;
        });
      }
    } catch (error) {
      final message = error.toString();
      final lower = message.toLowerCase();
      final helpfulMessage = lower.contains('api exception: 10') || lower.contains('sign_in_failed')
          ? 'Google Sign-In config mismatch. ${GoogleSignInConfig.setupHint}'
          : message;
      if (mounted) setState(() => _error = helpfulMessage);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await ref.read(sessionRepositoryProvider.notifier).logout();
    ref.read(identityRepositoryProvider.notifier).clear();
    await _googleSignIn.clearGoogleSessionIfUsed();
    if (!mounted) return;
    setState(() {
      _currentUser = null;
      _needsProfileSetup = false;
      _error = null;
    });
  }

  Future<bool> _shouldShowProfileSetup(CurrentUser user) {
    return resolveProfileSetupRequirement(user: user);
  }

  Future<void> _handleProfileSetupCompleted(CurrentUser user) async {
    await ref.read(identityRepositoryProvider.notifier).persist(user);
    if (!mounted) return;
    setState(() {
      _currentUser = user;
      _needsProfileSetup = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth) return const _LoadingScreen();

    final user = _currentUser;
    if (user == null) {
      return _LoginScreen(
        isLoading: _isLoading,
        error: _error,
        onFounderLoginPressed: _loginWithFounderTest,
        onTestUserLoginPressed: _loginWithNormalTestUser,
        onGoogleLoginPressed: _loginWithGoogle,
      );
    }

    if (_needsProfileSetup) {
      return ProfileSetupPage(
        user: user,
        onCompleted: (updatedUser) => unawaited(_handleProfileSetupCompleted(updatedUser)),
        onLogoutPressed: _logout,
      );
    }

    return AppShell(
      currentUser: user,
      onLogoutPressed: _logout,
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
  const _LoginScreen({
    required this.isLoading,
    required this.error,
    required this.onFounderLoginPressed,
    required this.onTestUserLoginPressed,
    required this.onGoogleLoginPressed,
  });

  final bool isLoading;
  final String? error;
  final VoidCallback onFounderLoginPressed;
  final VoidCallback onTestUserLoginPressed;
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
                        'Early beta access\nstarts with testing',
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          color: Color(0xFF191423),
                          fontSize: 34,
                          height: 1.18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.9,
                        ),
                      ),
                      const SizedBox(height: 34),
                      _LocalLoginButton(
                        isLoading: isLoading,
                        onTap: onFounderLoginPressed,
                        title: 'Founder Test Login',
                        subtitle: 'Owner/admin room control account',
                        icon: Icons.workspace_premium_rounded,
                        background: const Color(0xFF5B176A),
                      ),
                      const SizedBox(height: 12),
                      _LocalLoginButton(
                        isLoading: isLoading,
                        onTap: onTestUserLoginPressed,
                        title: 'Test User Login',
                        subtitle: 'Normal user for two-window broadcast test',
                        icon: Icons.person_rounded,
                        background: const Color(0xFF0F7D78),
                      ),
                      const SizedBox(height: 12),
                      _GoogleLoginButton(
                        isLoading: isLoading,
                        onTap: onGoogleLoginPressed,
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 18),
                        _LoginErrorBox(error: error!),
                      ],
                      const SizedBox(height: 22),
                      Text(
                        'Use Founder + Test User in two browser windows to verify backend broadcast. Google can be fixed later for production sign-in.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFF4B4055).withValues(alpha: 0.62),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
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
          for (final avatar in _avatars)
            Positioned(top: avatar.top, left: avatar.left, child: _OrbitAvatar(data: avatar)),
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
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5B176A).withValues(alpha: 0.09),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: data.colors),
        ),
        child: Center(
          child: Text(
            data.initial,
            style: TextStyle(
              color: Colors.white,
              fontSize: data.size * 0.36,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 8)],
            ),
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
      decoration: BoxDecoration(
        color: const Color(0xFF8D4AA2).withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8D4AA2).withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.48),
    );
  }
}

class _LocalLoginButton extends StatelessWidget {
  const _LocalLoginButton({
    required this.isLoading,
    required this.onTap,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.background,
  });

  final bool isLoading;
  final VoidCallback onTap;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color background;

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
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: background.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 29),
              const SizedBox(width: 28),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isLoading ? 'Signing in...' : subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 11, fontWeight: FontWeight.w800),
                    ),
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
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE9DEE8)),
          ),
          child: Row(
            children: [
              const Text('G', style: TextStyle(color: Color(0xFF4285F4), fontSize: 25, fontWeight: FontWeight.w900)),
              const SizedBox(width: 28),
              Expanded(
                child: Text(
                  isLoading ? 'Signing in...' : 'Google sign-in later',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF5B176A), fontSize: 14, fontWeight: FontWeight.w900),
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
      decoration: BoxDecoration(
        color: const Color(0xFFE84C72).withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE84C72).withValues(alpha: 0.42)),
      ),
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
      ..cubicTo(size.width * 0.18, size.height * 0.40, size.width * 0.30, size.height * 0.30, size.width * 0.52, size.height * 0.42);
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
