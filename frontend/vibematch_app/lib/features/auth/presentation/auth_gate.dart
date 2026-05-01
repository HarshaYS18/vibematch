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

  Future<void> _loginAsFounderOwner() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _authApiService.devLogin(
        email: 'sreeharshareddyyeddula@gmail.com',
        username: 'founder',
        displayName: 'Founder Owner',
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
        onLoginPressed: _loginAsFounderOwner,
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
    required this.onLoginPressed,
  });

  final bool isLoading;
  final String? error;
  final VoidCallback onLoginPressed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF10051F),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              width: 420,
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
                    'Auth, device security, and login tracking connected',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : onLoginPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD36A),
                        foregroundColor: const Color(0xFF1B0B33),
                        disabledBackgroundColor:
                            const Color(0xFFFFD36A).withValues(alpha: 0.45),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Color(0xFF1B0B33),
                              ),
                            )
                          : const Text(
                              'Login as Founder Owner',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                    ),
                  ),
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
