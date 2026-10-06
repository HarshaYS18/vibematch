import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'vm_growth_link.dart';

enum VmGrowthShareResult { shared, copied }

class VmGrowthCoordinator {
  VmGrowthCoordinator._();

  static final VmGrowthCoordinator instance = VmGrowthCoordinator._();

  static const MethodChannel _channel = MethodChannel('funkey/growth');
  static const String _lastReferrerKey = 'funkey_growth_last_referrer_v1';
  static const String _lastLinkKey = 'funkey_growth_last_link_v1';

  final StreamController<VmGrowthLink> _links =
      StreamController<VmGrowthLink>.broadcast();

  bool _initialized = false;
  VmGrowthLink? _pending;
  String? _lastAcceptedRaw;
  DateTime? _lastAcceptedAt;

  Stream<VmGrowthLink> get links => _links.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (kIsWeb) {
      _accept(Uri.base);
      return;
    }

    _channel.setMethodCallHandler((call) async {
      if (call.method != 'link') return;
      final raw = call.arguments?.toString().trim();
      if (raw == null || raw.isEmpty) return;
      final uri = Uri.tryParse(raw);
      if (uri != null) _accept(uri);
    });

    try {
      final raw = await _channel.invokeMethod<String>('getInitialLink');
      if (raw != null && raw.trim().isNotEmpty) {
        final uri = Uri.tryParse(raw.trim());
        if (uri != null) _accept(uri);
      }
    } on MissingPluginException {
      // Desktop/test environments may not implement the native bridge.
    } on PlatformException {
      // Growth links are non-critical startup infrastructure and fail open.
    }
  }

  VmGrowthLink? takePending() {
    final value = _pending;
    _pending = null;
    return value;
  }

  void markConsumed(VmGrowthLink link) {
    if (_pending?.uri == link.uri) _pending = null;
  }

  Future<VmGrowthShareResult> shareText(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return VmGrowthShareResult.copied;

    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        final shared = await _channel.invokeMethod<bool>(
          'shareText',
          <String, Object>{'text': clean},
        );
        if (shared == true) return VmGrowthShareResult.shared;
      } on MissingPluginException {
        // Fall through to clipboard.
      } on PlatformException {
        // Fall through to clipboard.
      }
    }

    await Clipboard.setData(ClipboardData(text: clean));
    return VmGrowthShareResult.copied;
  }

  void _accept(Uri uri) {
    final link = VmGrowthLinks.parse(uri);
    if (link == null) return;

    final raw = uri.toString();
    final now = DateTime.now();
    if (_lastAcceptedRaw == raw &&
        _lastAcceptedAt != null &&
        now.difference(_lastAcceptedAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastAcceptedRaw = raw;
    _lastAcceptedAt = now;

    _pending = link;
    unawaited(_captureAttribution(link));
    _links.add(link);
  }

  Future<void> _captureAttribution(VmGrowthLink link) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_lastLinkKey, link.uri.toString());
      final referrer = link.referrerId;
      if (referrer != null && referrer.isNotEmpty) {
        await preferences.setString(_lastReferrerKey, referrer);
      }
    } catch (_) {
      // Attribution is non-authoritative and cannot block navigation.
    }
  }
}
