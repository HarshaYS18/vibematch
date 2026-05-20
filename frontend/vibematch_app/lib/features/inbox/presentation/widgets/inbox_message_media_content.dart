import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/inbox_voice_playback_coordinator.dart';
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
      InboxMessageType.voice => _InboxVoiceMedia(message: message, mine: mine, title: _cleanAttachmentLabel(message.text, fallback: 'Voice message')),
      _ => Text(
          message.text,
          style: TextStyle(
            color: mine ? Colors.white : const Color(0xFF111114),
            fontSize: 13.2,
            height: 1.32,
            fontWeight: FontWeight.w600,
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
        ? (hasLocalCopy ? 'Saved on this device' : 'Needs fresh access')
        : (hasLocalCopy ? 'Saved on this device' : 'Tap to open');
    final canOpen = hasLocalCopy || hasRemoteCopy;
    return InkWell(
      onTap: canOpen ? () => _confirmAndOpenAttachment(context, message, title) : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 252,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: mine ? Colors.white.withValues(alpha: 0.14) : const Color(0xFFF7F7F8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: mine ? Colors.white.withValues(alpha: 0.18) : const Color(0xFFEDEDEF)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: mine ? Colors.white.withValues(alpha: 0.18) : const Color(0xFF3797F0).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: mine ? Colors.white : const Color(0xFF3797F0), size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: mine ? Colors.white : const Color(0xFF111114), fontSize: 12.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: mine ? Colors.white70 : const Color(0xFF71717A), fontSize: 10.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Icon(canOpen ? Icons.open_in_new_rounded : Icons.chevron_right_rounded, color: mine ? Colors.white70 : const Color(0xFF71717A), size: 18),
          ],
        ),
      ),
    );
  }
}

class _InboxVoiceMedia extends StatefulWidget {
  const _InboxVoiceMedia({required this.message, required this.mine, required this.title});

  final InboxMessage message;
  final bool mine;
  final String title;

  @override
  State<_InboxVoiceMedia> createState() => _InboxVoiceMediaState();
}

class _InboxVoiceMediaState extends State<_InboxVoiceMedia> {
  final InboxVoicePlaybackCoordinator _coordinator = InboxVoicePlaybackCoordinator.instance;

  @override
  void initState() {
    super.initState();
    _coordinator.addListener(_handlePlaybackChanged);
  }

  @override
  void dispose() {
    _coordinator.removeListener(_handlePlaybackChanged);
    super.dispose();
  }

  void _handlePlaybackChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _toggle() async {
    final target = _voiceTarget(widget.message);
    if (target == null) {
      _showOpenSnack(context, 'This voice message is no longer available.');
      return;
    }
    try {
      await _coordinator.toggle(key: _voiceKey(widget.message), target: target);
    } catch (_) {
      if (!mounted) return;
      _showOpenSnack(context, 'Could not play voice message.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = _voiceTarget(widget.message);
    if (target == null) {
      return _ExpiredMediaCard(message: widget.message, mine: widget.mine, icon: Icons.mic_off_rounded);
    }
    final state = _coordinator.state;
    final active = state.isActive(_voiceKey(widget.message));
    final playing = active && state.isPlaying;
    final loading = active && state.isLoading;
    final subtitle = widget.message.mediaExpired
        ? (widget.message.hasLocalAttachmentPath ? 'Saved on this device' : 'Needs fresh access')
        : (playing ? 'Playing voice message' : 'Tap to play');
    return InkWell(
      onTap: _toggle,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 252,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.mine ? Colors.white.withValues(alpha: 0.14) : const Color(0xFFF7F7F8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: widget.mine ? Colors.white.withValues(alpha: 0.18) : const Color(0xFFEDEDEF)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: playing ? const Color(0xFF22C55E) : (widget.mine ? Colors.white.withValues(alpha: 0.18) : const Color(0xFF3797F0).withValues(alpha: 0.10)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: loading
                  ? Padding(
                      padding: const EdgeInsets.all(11),
                      child: CircularProgressIndicator(strokeWidth: 2.3, color: widget.mine ? Colors.white : const Color(0xFF3797F0)),
                    )
                  : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: playing || widget.mine ? Colors.white : const Color(0xFF3797F0), size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: widget.mine ? Colors.white : const Color(0xFF111114), fontSize: 12.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: _VoiceWaveform(active: playing, mine: widget.mine)),
                      const SizedBox(width: 8),
                      Text(_durationFromTitle(widget.title), style: TextStyle(color: widget.mine ? Colors.white70 : const Color(0xFF71717A), fontSize: 10.5, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: widget.mine ? Colors.white70 : const Color(0xFF71717A), fontSize: 10.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceWaveform extends StatelessWidget {
  const _VoiceWaveform({required this.active, required this.mine});

  final bool active;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF22C55E) : (mine ? Colors.white70 : const Color(0xFFA1A1AA));
    const heights = [8.0, 13.0, 18.0, 11.0, 15.0, 9.0, 17.0, 12.0, 20.0, 10.0, 14.0, 8.0];
    return Row(
      children: heights
          .map((height) => Expanded(
                child: Align(
                  alignment: Alignment.center,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: active ? height : height * 0.56,
                    margin: const EdgeInsets.symmetric(horizontal: 1.4),
                    decoration: BoxDecoration(color: color.withValues(alpha: active ? 0.95 : 0.62), borderRadius: BorderRadius.circular(999)),
                  ),
                ),
              ))
          .toList(),
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
        color: mine ? Colors.white.withValues(alpha: 0.14) : const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: mine ? Colors.white.withValues(alpha: 0.18) : const Color(0xFFEDEDEF)),
      ),
      child: Row(
        children: [
          Icon(icon, color: mine ? Colors.white : const Color(0xFF71717A), size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Media unavailable', style: TextStyle(color: mine ? Colors.white : const Color(0xFF111114), fontSize: 12.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                  localAllowed ? 'It may still open if saved on this device.' : 'This media is no longer available.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: mine ? Colors.white70 : const Color(0xFF71717A), fontSize: 10.5, fontWeight: FontWeight.w600, height: 1.2),
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
          Text(localAvailable ? 'On device' : 'Needs access', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
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
    final isExpiredCopy = message.mediaExpired && !message.hasLocalAttachmentPath;
    final warning = isZip
        ? 'ZIP files can include many file types. Open only if you trust the sender.'
        : isExpiredCopy
            ? 'This file may need fresh access before it opens.'
            : 'Open files only from people you trust.';
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: EdgeInsets.fromLTRB(16, 10, 16, 14 + MediaQuery.paddingOf(context).bottom),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 28, offset: const Offset(0, 14))]),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: const Color(0xFFD4D4D8), borderRadius: BorderRadius.circular(999)))),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: const Color(0xFF3797F0).withValues(alpha: 0.10), borderRadius: BorderRadius.circular(16)),
                  child: Icon(isZip ? Icons.folder_zip_rounded : Icons.description_rounded, color: const Color(0xFF3797F0)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Open attachment?', style: TextStyle(color: Color(0xFF111114), fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF71717A), fontSize: 12, fontWeight: FontWeight.w600)),
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
                color: isZip ? const Color(0xFFFFF7ED) : const Color(0xFFF7F7F8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isZip ? const Color(0xFFFED7AA) : const Color(0xFFEDEDEF)),
              ),
              child: Text(warning, style: TextStyle(color: isZip ? const Color(0xFF9A3412) : const Color(0xFF111114), fontSize: 12, fontWeight: FontWeight.w600, height: 1.25)),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), side: const BorderSide(color: Color(0xFFEDEDEF))),
                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF3797F0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    icon: const Icon(Icons.open_in_new_rounded, size: 17),
                    label: const Text('Open', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ],
        ),
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
    _showOpenSnack(context, 'This attachment cannot be opened yet.');
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

String _voiceKey(InboxMessage message) {
  return message.id ?? message.effectiveRemoteMediaUrl ?? message.localAttachmentPath ?? message.text;
}

String? _voiceTarget(InboxMessage message) {
  final localPath = message.localAttachmentPath?.trim();
  if (localPath != null && localPath.isNotEmpty) return localPath;
  final remoteUrl = message.effectiveRemoteMediaUrl?.trim();
  if (remoteUrl != null && remoteUrl.isNotEmpty) return remoteUrl;
  return null;
}

String _durationFromTitle(String title) {
  final match = RegExp(r'(\d{1,2}:\d{2})').firstMatch(title);
  return match?.group(1) ?? '0:00';
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
        backgroundColor: const Color(0xFF111114),
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w700)),
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
