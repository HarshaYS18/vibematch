import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/inbox_models.dart';

class InboxMessageMediaContent extends StatelessWidget {
  const InboxMessageMediaContent({super.key, required this.message, required this.mine});

  final InboxMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return switch (message.type) {
      InboxMessageType.image => _InboxImageMedia(message: message, mine: mine),
      InboxMessageType.document => _InboxFileMedia(message: message, mine: mine, icon: Icons.description_rounded, title: _cleanAttachmentLabel(message.text, fallback: 'Document')),
      InboxMessageType.voice => _InboxFileMedia(message: message, mine: mine, icon: Icons.mic_rounded, title: _cleanAttachmentLabel(message.text, fallback: 'Voice message')),
      _ => Text(
          message.text,
          style: TextStyle(
            color: mine ? Colors.white : const Color(0xFF251538),
            fontSize: 13.2,
            height: 1.32,
            fontWeight: FontWeight.w700,
          ),
        ),
    };
  }
}

class _InboxImageMedia extends StatefulWidget {
  const _InboxImageMedia({required this.message, required this.mine});

  final InboxMessage message;
  final bool mine;

  @override
  State<_InboxImageMedia> createState() => _InboxImageMediaState();
}

class _InboxImageMediaState extends State<_InboxImageMedia> {
  bool _remoteFailed = false;

  @override
  void didUpdateWidget(covariant _InboxImageMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.effectiveRemoteMediaUrl != widget.message.effectiveRemoteMediaUrl || oldWidget.message.localAttachmentPath != widget.message.localAttachmentPath) {
      _remoteFailed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final localPath = widget.message.localAttachmentPath?.trim();
    final remoteUrl = widget.message.effectiveRemoteMediaUrl?.trim();
    final source = _usableImageSource(localPath) ?? _usableImageSource(remoteUrl);

    if (source == null || _remoteFailed) {
      return _ExpiredMediaCard(message: widget.message, mine: widget.mine, icon: Icons.image_not_supported_rounded);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          SizedBox(
            width: 252,
            height: 188,
            child: _imageForSource(
              source,
              onError: () {
                if (!mounted) return;
                setState(() => _remoteFailed = true);
              },
            ),
          ),
          if (widget.message.mediaExpired)
            Positioned(
              left: 8,
              bottom: 8,
              child: _LocalFirstBadge(localAvailable: _usableImageSource(localPath) != null),
            ),
        ],
      ),
    );
  }
}

class _InboxFileMedia extends StatelessWidget {
  const _InboxFileMedia({required this.message, required this.mine, required this.icon, required this.title});

  final InboxMessage message;
  final bool mine;
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final hasLocalCopy = message.hasLocalAttachmentPath;
    final hasRemoteCopy = message.hasAttachmentUrl || (message.expiredMediaUrl?.trim().isNotEmpty ?? false);
    if (message.mediaExpired && !hasLocalCopy && !hasRemoteCopy) {
      return _ExpiredMediaCard(message: message, mine: mine, icon: icon);
    }
    final subtitle = message.mediaExpired
        ? (hasLocalCopy ? 'Saved on this device' : 'Server copy expired')
        : (hasLocalCopy ? 'Local copy available' : 'Tap to open');
    final canOpen = hasLocalCopy || hasRemoteCopy;
    return InkWell(
      onTap: canOpen ? () => _confirmAndOpenAttachment(context, message, title) : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 252,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: mine ? Colors.white.withValues(alpha: 0.14) : const Color(0xFFF8F5FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: mine ? Colors.white.withValues(alpha: 0.18) : const Color(0xFFE9DDF5)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: mine ? Colors.white.withValues(alpha: 0.18) : const Color(0xFF7C3AED).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: mine ? Colors.white : const Color(0xFF7C3AED), size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: mine ? Colors.white : const Color(0xFF251538), fontSize: 12.5, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: mine ? Colors.white70 : const Color(0xFF7B6A86), fontSize: 10.5, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            Icon(canOpen ? Icons.open_in_new_rounded : Icons.chevron_right_rounded, color: mine ? Colors.white70 : const Color(0xFF9B8CA5), size: 18),
          ],
        ),
      ),
    );
  }
}

class _ExpiredMediaCard extends StatelessWidget {
  const _ExpiredMediaCard({required this.message, required this.mine, required this.icon});

  final InboxMessage message;
  final bool mine;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final localAllowed = message.localFirstAllowed || message.mediaExpired;
    return Container(
      width: 252,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: mine ? Colors.white.withValues(alpha: 0.14) : const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: mine ? Colors.white.withValues(alpha: 0.18) : const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          Icon(icon, color: mine ? Colors.white : const Color(0xFFE84C72), size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Media expired', style: TextStyle(color: mine ? Colors.white : const Color(0xFF7F1D1D), fontSize: 12.5, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(
                  localAllowed ? 'Server copy was removed. It will show if saved on this device.' : 'This media is no longer available.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: mine ? Colors.white70 : const Color(0xFF991B1B), fontSize: 10.5, fontWeight: FontWeight.w800, height: 1.2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalFirstBadge extends StatelessWidget {
  const _LocalFirstBadge({required this.localAvailable});

  final bool localAvailable;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(localAvailable ? Icons.phone_android_rounded : Icons.schedule_rounded, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(localAvailable ? 'On device' : 'Server expired', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _OpenAttachmentSheet extends StatelessWidget {
  const _OpenAttachmentSheet({required this.message, required this.title, required this.target});

  final InboxMessage message;
  final String title;
  final String target;

  @override
  Widget build(BuildContext context) {
    final isZip = title.toLowerCase().endsWith('.zip') || target.toLowerCase().contains('.zip');
    final isExpiredServerCopy = message.mediaExpired && !message.hasLocalAttachmentPath;
    final warning = isZip
        ? 'ZIP files can contain risky files. Open only if you trust the sender.'
        : isExpiredServerCopy
            ? 'The server copy may already be expired. This will open only if your device or browser can still access it.'
            : 'Open files only from people you trust.';
    return Container(
      margin: const EdgeInsets.all(14),
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: const Color(0xFF7C3AED).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
                child: Icon(isZip ? Icons.folder_zip_rounded : Icons.description_rounded, color: const Color(0xFF7C3AED)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Open attachment?', style: TextStyle(color: Color(0xFF251538), fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 12, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isZip ? const Color(0xFFFFF7ED) : const Color(0xFFF8F5FF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isZip ? const Color(0xFFFED7AA) : const Color(0xFFE9DDF5)),
            ),
            child: Text(warning, style: TextStyle(color: isZip ? const Color(0xFF9A3412) : const Color(0xFF251538), fontSize: 12, fontWeight: FontWeight.w800, height: 1.25)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), side: const BorderSide(color: Color(0xFFE9DDF5))),
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF251538), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  icon: const Icon(Icons.open_in_new_rounded, size: 17),
                  label: const Text('Open', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Widget _imageForSource(String source, {required VoidCallback onError}) {
  if (source.startsWith('assets/')) {
    return Image.asset(source, fit: BoxFit.cover, errorBuilder: (_, _, _) {
      onError();
      return const SizedBox.shrink();
    });
  }
  return Image.network(source, fit: BoxFit.cover, errorBuilder: (_, _, _) {
    onError();
    return const SizedBox.shrink();
  });
}

String? _usableImageSource(String? value) {
  final source = value?.trim();
  if (source == null || source.isEmpty) return null;
  if (source.startsWith('http://') || source.startsWith('https://') || source.startsWith('assets/')) return source;
  return null;
}

Future<void> _confirmAndOpenAttachment(BuildContext context, InboxMessage message, String title) async {
  final localPath = message.localAttachmentPath?.trim();
  final remoteUrl = message.effectiveRemoteMediaUrl?.trim();
  final target = (localPath != null && localPath.isNotEmpty) ? localPath : remoteUrl;
  if (target == null || target.isEmpty) {
    _showOpenSnack(context, 'This attachment is no longer available.');
    return;
  }

  final uri = _attachmentUri(target);
  if (uri == null) {
    _showOpenSnack(context, 'This attachment path cannot be opened yet.');
    return;
  }

  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _OpenAttachmentSheet(message: message, title: title, target: target),
  );
  if (confirmed != true || !context.mounted) return;

  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    _showOpenSnack(context, 'Could not open attachment.');
  }
}

Uri? _attachmentUri(String target) {
  if (target.startsWith('http://') || target.startsWith('https://')) return Uri.tryParse(target);
  if (target.startsWith('file://')) return Uri.tryParse(target);
  if (target.startsWith('/') || RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(target)) {
    return Uri.file(target);
  }
  return null;
}

void _showOpenSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF251538),
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
}

String _cleanAttachmentLabel(String value, {required String fallback}) {
  final cleaned = value
      .replaceFirst('📷', '')
      .replaceFirst('🎙', '')
      .replaceFirst('📄', '')
      .trim();
  if (cleaned.isEmpty || cleaned.toLowerCase() == 'media expired') return fallback;
  return cleaned;
}
