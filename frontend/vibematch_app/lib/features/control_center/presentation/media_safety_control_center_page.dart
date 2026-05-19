import 'dart:async';

import 'package:flutter/material.dart';

import '../data/media_safety_api_service.dart';

class MediaSafetyControlCenterPage extends StatefulWidget {
  const MediaSafetyControlCenterPage({super.key});

  @override
  State<MediaSafetyControlCenterPage> createState() =>
      _MediaSafetyControlCenterPageState();
}

class _MediaSafetyControlCenterPageState
    extends State<MediaSafetyControlCenterPage> {
  final MediaSafetyApiService _api = MediaSafetyApiService();
  bool _busy = true;
  String? _error;
  MediaSafetyDashboard? _dashboard;
  List<MediaSafetySetting> _settings = const [];
  List<CdnMediaAsset> _assets = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object>([
        _api.loadDashboard(),
        _api.loadSettings(),
        _api.loadAssets(limit: 40),
      ]);
      if (!mounted) return;
      setState(() {
        _dashboard = results[0] as MediaSafetyDashboard;
        _settings = results[1] as List<MediaSafetySetting>;
        _assets = results[2] as List<CdnMediaAsset>;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message, {bool danger = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: danger ? const Color(0xFFE84C72) : const Color(0xFF251538),
      ),
    );
  }

  void _showActionPlaceholder(String label) {
    _toast('$label controls are backend-backed and will be expanded in the next chunk.');
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = _dashboard;
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7F1),
        foregroundColor: const Color(0xFF251538),
        elevation: 0,
        title: const Text(
          'Media & Safety',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _busy ? null : () => unawaited(_load()),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
          children: [
            _HeroCard(onManageSettings: () => _showActionPlaceholder('Settings')),
            const SizedBox(height: 14),
            if (_busy) const _LoadingCard(),
            if (_error != null) _ErrorCard(message: _error!, onRetry: () => unawaited(_load())),
            if (!_busy && _error == null && dashboard != null) ...[
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.5,
                children: [
                  _MetricCard(title: 'Total media', value: '${dashboard.totalCount}', icon: Icons.perm_media_rounded),
                  _MetricCard(title: 'Needs review', value: '${dashboard.pendingReviewCount}', icon: Icons.policy_rounded),
                  _MetricCard(title: 'Delete failed', value: '${dashboard.deletionFailedCount}', icon: Icons.warning_rounded),
                  _MetricCard(title: 'Inbox expiring', value: '${dashboard.inboxExpiringCount}', icon: Icons.timer_rounded),
                ],
              ),
              const SizedBox(height: 14),
              _SectionHeader(
                title: 'Safety settings',
                actionLabel: 'Manage',
                onAction: () => _showActionPlaceholder('Media Safety settings'),
              ),
              const SizedBox(height: 8),
              for (final setting in _settings.take(4)) _SettingCard(setting: setting),
              const SizedBox(height: 14),
              _SectionHeader(
                title: 'Recent media assets',
                actionLabel: 'Review queue',
                onAction: () => _showActionPlaceholder('Review queue'),
              ),
              const SizedBox(height: 8),
              if (_assets.isEmpty)
                const _EmptyCard(message: 'No media records yet. Upload a profile photo, cover, chat image, or Vibe media to populate this dashboard.'),
              for (final asset in _assets) _AssetCard(asset: asset),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onManageSettings});
  final VoidCallback onManageSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF251538), Color(0xFF6D5DF6), Color(0xFF12C7B7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF251538).withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.security_rounded, color: Color(0xFFFFF0A8), size: 30),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'CDN, moderation & retention control',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Founder Owner tools for profile photos, cover photos, Vibes media, inbox media expiry, OpenAI moderation settings and cleanup visibility.',
            style: TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.35),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF251538),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: onManageSettings,
            icon: const Icon(Icons.tune_rounded),
            label: const Text('Manage policies', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value, required this.icon});
  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEDE3D7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFF6D5DF6)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Color(0xFF251538), fontSize: 20, fontWeight: FontWeight.w900)),
          Text(title, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.actionLabel, required this.onAction});
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: const TextStyle(color: Color(0xFF251538), fontSize: 16, fontWeight: FontWeight.w900))),
        TextButton(onPressed: onAction, child: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w900))),
      ],
    );
  }
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({required this.setting});
  final MediaSafetySetting setting;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEDE3D7)),
      ),
      child: Row(
        children: [
          const Icon(Icons.settings_suggest_rounded, color: Color(0xFF12C7B7)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(setting.key.replaceAll('_', ' '), style: const TextStyle(color: Color(0xFF251538), fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(setting.description ?? setting.valueJson.toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({required this.asset});
  final CdnMediaAsset asset;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEDE3D7)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: asset.publicUrl.isEmpty
                ? Container(width: 52, height: 52, color: const Color(0xFFEDE3D7), child: const Icon(Icons.image_rounded))
                : Image.network(asset.publicUrl, width: 52, height: 52, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 52, height: 52, color: const Color(0xFFEDE3D7), child: const Icon(Icons.broken_image_rounded))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(asset.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF251538), fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(asset.subtitle, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 5,
                  children: [
                    _TinyChip(label: asset.moderationStatus),
                    _TinyChip(label: asset.deletionStatus),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF8C8198)),
        ],
      ),
    );
  }
}

class _TinyChip extends StatelessWidget {
  const _TinyChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label.replaceAll('_', ' '), style: const TextStyle(color: Color(0xFF4A2A63), fontSize: 10.5, fontWeight: FontWeight.w900)),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) => const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()));
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => _EmptyCard(message: message, actionLabel: 'Retry', onAction: onRetry);
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message, this.actionLabel, this.onAction});
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFEDE3D7))),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF7B6A86), fontWeight: FontWeight.w800)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 10),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
