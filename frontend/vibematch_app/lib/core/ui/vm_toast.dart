import 'dart:async';

import 'package:flutter/material.dart';

class VmToast {
  VmToast._();

  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String message, {
    IconData icon = Icons.check_circle_rounded,
    Duration duration = const Duration(milliseconds: 1700),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _timer?.cancel();
    _entry?.remove();
    final safeMessage = _clean(message);
    _entry = OverlayEntry(
      builder: (_) => _VmToastOverlay(message: safeMessage, icon: icon),
    );
    overlay.insert(_entry!);
    _timer = Timer(duration, dismiss);
  }

  static void error(BuildContext context, String message) {
    show(context, message, icon: Icons.info_rounded, duration: const Duration(milliseconds: 2100));
  }

  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }

  static String _clean(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return 'Done';
    text = text.replaceAll(RegExp(r'Exception:\s*'), '');
    text = text.replaceAll(RegExp(r'backend', caseSensitive: false), 'server');
    text = text.replaceAll(RegExp(r'api', caseSensitive: false), 'service');
    text = text.replaceAll(RegExp(r'debug', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length > 82) text = '${text.substring(0, 79)}...';
    return text;
  }
}

class _VmToastOverlay extends StatefulWidget {
  const _VmToastOverlay({required this.message, required this.icon});
  final String message;
  final IconData icon;

  @override
  State<_VmToastOverlay> createState() => _VmToastOverlayState();
}

class _VmToastOverlayState extends State<_VmToastOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _scale = Tween<double>(begin: 0.94, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _slide = Tween<Offset>(begin: const Offset(0, -0.18), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: top > 0 ? 10 : 18, left: 22, right: 22),
            child: FadeTransition(
              opacity: _opacity,
              child: SlideTransition(
                position: _slide,
                child: ScaleTransition(
                  scale: _scale,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 310),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: const Color(0xEE17121F),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.22),
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(widget.icon, color: const Color(0xFF19E6D2), size: 16),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              widget.message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.2,
                                height: 1.12,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
