import 'dart:async';
import 'dart:convert';

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
  bool _actionBusy = false;
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
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            danger ? const Color(0xFFE84C72) : const Color(0xFF251538),
      ),
    );
  }

  Future<String?> _askReason({required String title, required String hint}) async {
    final controller = TextEditingController(text: hint);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Reason',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.trim().length < 2) return null;
    return result.trim();
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      await action();
      await _load();
    } catch (error) {
      _toast(error.toString().replaceFirst('Exception: ', ''), danger: true);
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _cleanupInboxMedia() async {
    final reason = await _askReason(
      title: 'Run inbox media cleanup?',
      hint: 'Manual cleanup from Media & Safety Control Center',
    );
    if (reason == null) return;
    await _runAction(() async {
      final result = await _api.cleanupExpiredInboxMedia(limit: 100);
      _toast(
        'Cleanup checked ${result.checked}, deleted ${result.deleted}, failed ${result.failed}.',
      );
    });
  }

  Future<void> _editSetting(MediaSafetySetting setting) async {
    final jsonController = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(setting.valueJson),
    );
    final descriptionController = TextEditingController(
      text: setting.description ?? '',
    );
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${setting.key.replaceAll('_', ' ')}'),
        content: SizedBox(
          width: 520,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: jsonController,
                  minLines: 8,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    labelText: 'Policy JSON',
                    helperText: 'Keep this valid JSON. Changes are audit-logged.',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    try {
                      final decoded = jsonDecode(value ?? '{}');
                      if (decoded is! Map<String, dynamic>) {
                        return 'Policy must be a JSON object';
                      }
                      return null;
                    } catch (_) {
                      return 'Invalid JSON';
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.of(context).pop({
                'description': descriptionController.text.trim(),
                'value': jsonDecode(jsonController.text) as Map<String, dynamic>,
              });
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    jsonController.dispose();
    descriptionController.dispose();
    if (result == null) return;
    final reason = await _askReason(
      title: 'Confirm setting update?',
      hint: 'Updated ${setting.key} from Media & Safety Control Center',
    );
    if (reason == null) return;
    await _runAction(() async {
      await _api.updateSetting(
        key: setting.key,
        valueJson: result['value']! as Map<String, dynamic>,
        description: result['description']?.toString(),
        reason: reason,
      );
      _toast('Setting updated.');
    });
  }

  Future<void> _approveAsset(CdnMediaAsset asset) async {
    final reason = await _askReason(
      title: 'Approve media?',
      hint: 'Approved after Super Owner review',
    );
    if (reason == null) return;
    await _runAction(() async {
      await _api.approveAsset(mediaId: asset.publicId, reason: reason);
      _toast('Media approved.');
    });
  }

  Future<void> _rejectAsset(CdnMediaAsset asset) async {
    final reason = await _askReason(
      title: 'Reject and remove media?',
      hint: 'Rejected after Super Owner review',
    );
    if (reason == null) return;
    await _runAction(() async {
      await _api.rejectAsset(mediaId: asset.publicId, reason: reason);
      _toast('Media rejected and marked for deletion.');
    });
  }

  Future<void> _retryDelete(CdnMediaAsset asset) async {
    final reason = await _askReason(
      title: 'Retry CDN delete?',
      hint: 'Retry deletion from Media & Safety Control Center',
    );
    if (reason == null) return;
    await _runAction(() async {
      await _api.retryDelete(mediaId: asset.publicId, reason: reason);
      _toast('Deletion retry completed.');
    });
  }

  void _showAssetSheet(CdnMediaAsset asset) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFFFAF7F1),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                asset.title,
                style: const TextStyle(
                  color: Color(0xFF251538),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                asset.objectKey,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF7B6A86),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _actionBusy
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            unawaited(_approveAsset(asset));
                          },
                    icon: const Icon(Icons.verified_rounded),
                    label: const Text('Approve'),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE84C72),
                    ),
                    onPressed: _actionBusy
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            unawaited(_rejectAsset(asset));
                          },
                    icon: const Icon(Icons.block_rounded),
                    label: const Text('Reject'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _actionBusy
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            unawaited(_retryDelete(asset));
                          },
                    icon: const Icon(Icons.delete_sweep_rounded),
                    label: const Text('Retry delete'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'All actions are backend permission-checked and audit-logged.',
                style: TextStyle(
                  color: Color(0xFF7B6A86),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
            tooltip: 'Run inbox cleanup',
            onPressed: _busy || _actionBusy ? null : () => unawaited(_cleanupInboxMedia()),
            icon: const Icon(Icons.cleaning_services_rounded),
          ),
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
            _HeroCard(onRunCleanup: () => unawaited(_cleanupInboxMedia())),
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
              const _SectionHeader(title: 'Safety settings'),
              const SizedBox(height: 8),
              for (final setting in _settings.take(4))
                _SettingCard(
                  setting: setting,
                  onTap: () => unawaited(_editSetting(setting)),
                ),
              const SizedBox(height: 14),
              const _SectionHeader(title: 'Recent media assets'),
              const SizedBox(height: 8),
              if (_assets.isEmpty)
                const _EmptyCard(message: 'No media records yet. Upload a profile photo, cover, chat image, or Vibe media to populate this dashboard.'),
              for (final asset in _assets)
                _AssetCard(asset: asset, onTap: () => _showAssetSheet(asset)),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onRunCleanup});
  final VoidCallback onRunCleanup;

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
            onPressed: onRunCleanup,
            icon: const Icon(Icons.cleaning_services_rounded),
            label: const Text('Run inbox cleanup', style: TextStyle(fontWeight: FontWeight.w900)),
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
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(color: Color(0xFF251538), fontSize: 16, fontWeight: FontWeight.w900),
    );
  }
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({required this.setting, required this.onTap});
  final MediaSafetySetting setting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
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
              const Icon(Icons.edit_rounded, color: Color(0xFF8C8198)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({required this.asset, required this.onTap});
  final CdnMediaAsset asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFEDE3D7)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: asset.publicUrl.isEmpty
                    ? Container(width: 52, height: 52, color: const Color(0xFFEDE3D7), child: const Icon(Icons.image_rounded))
                    : Image.network(asset.publicUrl, width: 52, height: 52, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(width: 52, height: 52, color: const Color(0xFFEDE3D7), child: const Icon(Icons.broken_image_rounded))),
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
        ),
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
