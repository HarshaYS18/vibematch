import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';

class InboxLockOwnerResetPage extends StatefulWidget {
  const InboxLockOwnerResetPage({super.key});

  @override
  State<InboxLockOwnerResetPage> createState() => _InboxLockOwnerResetPageState();
}

class _InboxLockOwnerResetPageState extends State<InboxLockOwnerResetPage> {
  final TextEditingController _identifierController = TextEditingController();
  final AuthApiService _auth = const AuthApiService();
  bool _busy = false;

  @override
  void dispose() {
    _identifierController.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      _toast('Enter public ID or custom ID.');
      return;
    }
    final token = _auth.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      _toast('Please login again.');
      return;
    }
    setState(() => _busy = true);
    try {
      final response = await http.post(
        Uri.parse(VmApiConfig.endpoint('/inbox/lock/owner-reset-by-id')),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'user_identifier': identifier}),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(_errorMessage(response));
      }
      _identifierController.clear();
      _toast('Inbox Lock reset to 1234. User can unlock with 1234 and change it in Inbox Settings.');
    } catch (error) {
      _toast(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _errorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail']?.toString();
        if (detail != null && detail.trim().isNotEmpty) return detail;
      }
    } catch (_) {}
    return 'Reset failed (${response.statusCode})';
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF251538), content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7F1),
        foregroundColor: const Color(0xFF251538),
        elevation: 0,
        title: const Text('Reset Inbox Lock', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), gradient: const LinearGradient(colors: [Color(0xFF251538), Color(0xFF6D5DF6)])),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_reset_rounded, color: Colors.white, size: 30),
                SizedBox(height: 10),
                Text('Owner/Super Owner Tool', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                SizedBox(height: 6),
                Text('Search by public user ID or display custom ID. Reset sets the user’s Inbox Lock to 1234. The user can unlock with 1234, then change it in Inbox Settings.', style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFECE2D8))),
            child: Column(
              children: [
                TextField(
                  controller: _identifierController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.badge_rounded, color: Color(0xFF4A2A63)),
                    labelText: 'Public ID / Custom ID',
                    filled: true,
                    fillColor: const Color(0xFFFAF7F1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFECE2D8))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFECE2D8))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFF12C7B7), width: 1.4)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _reset,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF251538), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                    icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.lock_reset_rounded),
                    label: const Text('Reset to 1234', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
