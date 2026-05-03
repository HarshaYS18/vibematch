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

      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _currentUser = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingAuth = false;
        });
      }
    }
  }

  Future<void> _loginAs({
    required String email,
    required String username,
    required String displayName,
    String? deviceId,
  }) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _authApiService.devLogin(
        email: email,
        username: username,
        displayName: displayName,
        deviceId: deviceId,
      );

      final user = await _authApiService.getCurrentUser();

      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
    if (_isCheckingAuth) {
      return const _LoadingScreen();
    }

    if (_currentUser == null) {
      return _LoginScreen(
        isLoading: _isLoading,
        error: _error,
        onFounderOwnerLogin: () => _loginAs(
          email: 'founder@vibematch.com',
          username: 'founder',
          displayName: 'Founder Owner',
          deviceId: 'founder-device-001',
        ),
        onFounderUserLogin: () => _loginAs(
          email: 'founderuser@vibematch.com',
          username: 'founderuser',
          displayName: 'Founder Test User',
        ),
        onCleanUserLogin: () => _loginAs(
          email: 'cleanstep2huser@vibematch.com',
          username: 'cleanstep2huser',
          displayName: 'Clean Step 2H User',
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
      backgroundColor: Color(0xFF10051F),
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFFD36A),
        ),
      ),
    );
  }
}

class _LoginScreen extends StatelessWidget {
  const _LoginScreen({
    required this.isLoading,
    required this.error,
    required this.onFounderOwnerLogin,
    required this.onFounderUserLogin,
    required this.onCleanUserLogin,
  });

  final bool isLoading;
  final String? error;
  final VoidCallback onFounderOwnerLogin;
  final VoidCallback onFounderUserLogin;
  final VoidCallback onCleanUserLogin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF10051F),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              width: 430,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF1B0B33),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: const Color(0xFFFFD36A).withValues(alpha: 0.45),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD36A).withValues(alpha: 0.16),
                    blurRadius: 32,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(
                    radius: 44,
                    backgroundColor: Color(0xFFFFD36A),
                    child: Icon(
                      Icons.favorite,
                      color: Color(0xFF1B0B33),
                      size: 42,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Vibe Match',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose a real dev login. Every page opens with this active account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 26),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(color: Color(0xFFFFD36A)),
                    )
                  else ...[
                    _LoginOptionCard(
                      title: 'Founder Owner',
                      subtitle: 'Official founder account · ID 6922022 · all controls',
                      icon: Icons.admin_panel_settings_rounded,
                      backgroundColor: const Color(0xFFFFD36A),
                      foregroundColor: const Color(0xFF1B0B33),
                      onTap: onFounderOwnerLogin,
                    ),
                    const SizedBox(height: 12),
                    _LoginOptionCard(
                      title: 'Founder User',
                      subtitle: 'Normal user account for testing non-owner UI access',
                      icon: Icons.person_rounded,
                      backgroundColor: const Color(0xFF35E6A8),
                      foregroundColor: const Color(0xFF061A13),
                      onTap: onFounderUserLogin,
                    ),
                    const SizedBox(height: 12),
                    _LoginOptionCard(
                      title: 'Clean Test User',
                      subtitle: 'Fresh generated-device login for normal user flows',
                      icon: Icons.verified_user_rounded,
                      backgroundColor: const Color(0xFF6D5DF6),
                      foregroundColor: Colors.white,
                      onTap: onCleanUserLogin,
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.redAccent),
                      ),
                      child: Text(
                        error!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginOptionCard extends StatelessWidget {
  const _LoginOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Icon(icon, color: foregroundColor, size: 28),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: foregroundColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: foregroundColor.withValues(alpha: 0.78),
                        fontSize: 12.2,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: foregroundColor, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
