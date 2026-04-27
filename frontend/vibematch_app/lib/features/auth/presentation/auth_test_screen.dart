import 'package:flutter/material.dart';

import '../data/auth_api_service.dart';
import '../models/current_user.dart';

class AuthTestScreen extends StatefulWidget {
  const AuthTestScreen({super.key});

  @override
  State<AuthTestScreen> createState() => _AuthTestScreenState();
}

class _AuthTestScreenState extends State<AuthTestScreen> {
  final AuthApiService _authApiService = AuthApiService();

  bool _isLoading = false;
  String? _error;
  String? _success;
  String? _currentDeviceId;
  CurrentUser? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentDeviceId();
  }

  Future<void> _loadCurrentDeviceId() async {
    try {
      final deviceId = await _authApiService.getCurrentDeviceId();

      if (!mounted) return;

      setState(() {
        _currentDeviceId = deviceId;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _currentDeviceId = 'Unable to load device ID: $error';
      });
    }
  }

  Future<void> _runAction(
    Future<void> Function() action, {
    bool clearUserBeforeAction = false,
  }) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _success = null;

      if (clearUserBeforeAction) {
        _currentUser = null;
      }
    });

    try {
      await action();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loginAsFounderOwner() async {
    await _runAction(
      () async {
        await _authApiService.devLogin(
          email: 'founder@vibematch.com',
          username: 'founder',
          displayName: 'Founder Owner',
          deviceId: 'founder-device-001',
        );

        final user = await _authApiService.getCurrentUser();

        setState(() {
          _currentUser = user;
          _success = 'Founder Owner login successful.';
        });
      },
      clearUserBeforeAction: true,
    );
  }

  Future<void> _loginAsCleanUser() async {
    await _runAction(
      () async {
        await _authApiService.devLogin(
          email: 'cleanstep2huser@vibematch.com',
          username: 'cleanstep2huser',
          displayName: 'Clean Step 2H User',
        );

        final user = await _authApiService.getCurrentUser();
        final deviceId = await _authApiService.getCurrentDeviceId();

        setState(() {
          _currentUser = user;
          _currentDeviceId = deviceId;
          _success = 'Clean device login successful using generated app device ID.';
        });
      },
      clearUserBeforeAction: true,
    );
  }

  Future<void> _loginWithBannedDevice() async {
    await _runAction(
      () async {
        await _authApiService.devLogin(
          email: 'banneddeviceuser@vibematch.com',
          username: 'banneddeviceuser',
          displayName: 'Banned Device User',
          deviceId: 'step2h-banned-device-001',
        );

        final user = await _authApiService.getCurrentUser();

        setState(() {
          _currentUser = user;
          _success = 'Unexpected: banned device login succeeded.';
        });
      },
      clearUserBeforeAction: true,
    );
  }

  Future<void> _fetchMe() async {
    await _runAction(() async {
      final user = await _authApiService.getCurrentUser();
      final deviceId = await _authApiService.getCurrentDeviceId();

      setState(() {
        _currentUser = user;
        _currentDeviceId = deviceId;
        _success = 'Current user fetched successfully.';
      });
    });
  }

  Future<void> _refreshDeviceId() async {
    await _runAction(() async {
      final deviceId = await _authApiService.getCurrentDeviceId();

      setState(() {
        _currentDeviceId = deviceId;
        _success = 'Device ID loaded successfully.';
      });
    });
  }

  Future<void> _logout() async {
    await _authApiService.logout();

    setState(() {
      _currentUser = null;
      _error = null;
      _success = 'Logged out successfully.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = _currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF10051F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B0B33),
        title: const Text('Vibe Match Auth Test'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _fetchMe,
            icon: const Icon(Icons.refresh),
            tooltip: 'Fetch /users/me',
          ),
          IconButton(
            onPressed: _isLoading ? null : _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1B0B33),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFFFD36A).withValues(alpha: 0.45),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD36A).withValues(alpha: 0.16),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 42,
                  backgroundColor: Color(0xFFFFD36A),
                  child: Icon(
                    Icons.verified_user,
                    color: Color(0xFF1B0B33),
                    size: 42,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Vibe Match Auth + Security Test',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Step 2P: Flutter reads /users/me security fields',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 18),
                _DeviceIdBox(
                  deviceId: _currentDeviceId ?? 'Loading device ID...',
                  onRefresh: _isLoading ? null : _refreshDeviceId,
                ),
                const SizedBox(height: 24),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  )
                else ...[
                  _ActionButton(
                    label: 'Login as Founder Owner',
                    icon: Icons.workspace_premium,
                    backgroundColor: const Color(0xFFFFD36A),
                    foregroundColor: const Color(0xFF1B0B33),
                    onPressed: _loginAsFounderOwner,
                  ),
                  const SizedBox(height: 12),
                  _ActionButton(
                    label: 'Login Clean Generated Device User',
                    icon: Icons.check_circle,
                    backgroundColor: const Color(0xFF35E6A8),
                    foregroundColor: const Color(0xFF061A13),
                    onPressed: _loginAsCleanUser,
                  ),
                  const SizedBox(height: 12),
                  _ActionButton(
                    label: 'Test Manual Banned Device Login',
                    icon: Icons.block,
                    backgroundColor: const Color(0xFFFF5C7A),
                    foregroundColor: Colors.white,
                    onPressed: _loginWithBannedDevice,
                  ),
                  const SizedBox(height: 12),
                  _ActionButton(
                    label: 'Fetch Current User',
                    icon: Icons.person_search,
                    backgroundColor: Colors.white12,
                    foregroundColor: Colors.white,
                    onPressed: _fetchMe,
                  ),
                ],
                const SizedBox(height: 20),
                if (_success != null)
                  _MessageBox(
                    message: _success!,
                    color: const Color(0xFF35E6A8),
                    icon: Icons.check_circle,
                  ),
                if (_error != null)
                  _MessageBox(
                    message: _error!,
                    color: Colors.redAccent,
                    icon: Icons.error,
                  ),
                if (user != null) ...[
                  const SizedBox(height: 18),
                  _SectionHeader(
                    icon: Icons.person,
                    title: 'Account',
                  ),
                  _InfoTile(
                    label: 'Display Name',
                    value: user.displayName ?? 'No name',
                  ),
                  _InfoTile(
                    label: 'Username',
                    value: user.username ?? 'No username',
                  ),
                  _InfoTile(
                    label: 'Permanent Public ID',
                    value: user.publicUserId.toString(),
                  ),
                  _InfoTile(
                    label: 'Visible ID',
                    value: user.visibleId,
                  ),
                  _InfoTile(
                    label: 'Primary Role',
                    value: user.primaryRole,
                  ),
                  _InfoTile(
                    label: 'Roles',
                    value: user.roles.join(', '),
                  ),
                  _InfoTile(
                    label: 'Account Status',
                    value: user.accountStatusLabel,
                  ),
                  const SizedBox(height: 10),
                  _SectionHeader(
                    icon: Icons.security,
                    title: 'Security',
                  ),
                  _InfoTile(
                    label: 'Last Device ID',
                    value: user.lastDeviceId ?? 'No device recorded',
                  ),
                  _InfoTile(
                    label: 'Last Login At',
                    value: user.lastLoginLabel,
                  ),
                  _InfoTile(
                    label: 'Last Seen At',
                    value: user.lastSeenAt?.toLocal().toString() ?? 'Never',
                  ),
                  _InfoTile(
                    label: 'Created At',
                    value: user.createdAt.toLocal().toString(),
                  ),
                  _InfoTile(
                    label: 'Updated At',
                    value: user.updatedAt.toLocal().toString(),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: user.isFounderOwner
                          ? const Color(0xFFFFD36A)
                          : user.isOfficialOrStaff
                              ? const Color(0xFF35E6A8)
                              : Colors.white12,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      user.isFounderOwner
                          ? 'OFFICIAL • FOUNDER OWNER'
                          : user.isOfficialOrStaff
                              ? 'OFFICIAL / STAFF'
                              : 'NORMAL USER',
                      style: TextStyle(
                        color: user.isFounderOwner || user.isOfficialOrStaff
                            ? const Color(0xFF1B0B33)
                            : Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeviceIdBox extends StatelessWidget {
  const _DeviceIdBox({
    required this.deviceId,
    required this.onRefresh,
  });

  final String deviceId;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF35E6A8).withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.devices, color: Color(0xFF35E6A8), size: 19),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Generated App Device ID',
                  style: TextStyle(
                    color: Color(0xFF35E6A8),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, size: 18),
                color: Colors.white70,
                tooltip: 'Refresh device ID',
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            deviceId,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({
    required this.message,
    required this.color,
    required this.icon,
  });

  final String message;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFFD36A), size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFFFD36A),
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: SelectableText(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}