import 'package:flutter/material.dart';

import '../../auth/data/auth_api_service.dart';
import '../../auth/models/current_user.dart';
import 'public_profile_view_page.dart';

class PublicProfilePage extends StatefulWidget {
  const PublicProfilePage({
    super.key,
    this.userId = '6418000000',
    this.displayName = 'Vibe User',
    this.username,
  });

  final String userId;
  final String displayName;
  final String? username;

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  final AuthApiService _authApi = const AuthApiService();
  CurrentUser? _viewer;
  bool _loading = true;
  String? _error;

  int get _targetPublicUserId => int.tryParse(widget.userId.replaceAll(RegExp('[^0-9]'), '')) ?? 0;

  @override
  void initState() {
    super.initState();
    _loadViewer();
  }

  Future<void> _loadViewer() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final viewer = await _authApi.getCurrentUser(forceRefresh: false);
      if (!mounted) return;
      setState(() {
        _viewer = viewer;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final publicUserId = _targetPublicUserId;
    final viewer = _viewer;
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFAF7F1),
        body: SafeArea(child: LinearProgressIndicator(minHeight: 3, color: Color(0xFF12C7B7), backgroundColor: Color(0xFFECE2D8))),
      );
    }
    if (_error != null || viewer == null || publicUserId <= 0) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAF7F1),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.wifi_off_rounded, color: Color(0xFFC99A3B), size: 34),
                const SizedBox(height: 10),
                Text(_error ?? 'Invalid public user ID.', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF251538), fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                TextButton(onPressed: _loadViewer, child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w900))),
              ]),
            ),
          ),
        ),
      );
    }
    return PublicProfileViewPage(
      user: viewer,
      publicUserId: publicUserId,
      vipLevel: 0,
      svipLevel: 0,
      presenceLabel: 'Offline',
      currentRoomName: null,
      relationshipLabel: '',
      familyName: '',
      familyLevel: 0,
    );
  }
}
