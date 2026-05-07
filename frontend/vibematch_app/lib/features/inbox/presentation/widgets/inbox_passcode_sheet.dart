import 'package:flutter/material.dart';

class InboxPasscodeSheet extends StatefulWidget {
  const InboxPasscodeSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onValidate,
    required this.onUnlocked,
    this.onRecoverTap,
  });

  final String title;
  final String subtitle;
  final Future<bool> Function(String passcode) onValidate;
  final VoidCallback onUnlocked;
  final VoidCallback? onRecoverTap;

  @override
  State<InboxPasscodeSheet> createState() => _InboxPasscodeSheetState();
}

class _InboxPasscodeSheetState extends State<InboxPasscodeSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_controller.text.trim().isEmpty) {
      setState(() => _error = 'Enter your Inbox lock.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final valid = await widget.onValidate(_controller.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);
    if (valid) {
      widget.onUnlocked();
      return;
    }

    setState(() => _error = 'Wrong lock. Try again or recover.');
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final keyboardInset = mediaQuery.viewInsets.bottom;
    final safeBottom = mediaQuery.padding.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Container(
          padding: EdgeInsets.fromLTRB(18, 10, 18, 18 + safeBottom),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 30, offset: const Offset(0, 14))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 42, height: 5, decoration: BoxDecoration(color: const Color(0xFFE0D5CB), borderRadius: BorderRadius.circular(999))),
              const SizedBox(height: 16),
              Container(width: 62, height: 62, decoration: BoxDecoration(color: const Color(0xFF251538), borderRadius: BorderRadius.circular(22)), child: const Icon(Icons.lock_rounded, color: Colors.white, size: 30)),
              const SizedBox(height: 13),
              Text(widget.title, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF251538), fontSize: 21, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(widget.subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                obscureText: _obscure,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                style: const TextStyle(color: Color(0xFF251538), fontWeight: FontWeight.w900),
                decoration: InputDecoration(
                  hintText: 'Enter Inbox lock',
                  errorText: _error,
                  prefixIcon: const Icon(Icons.password_rounded, color: Color(0xFF8C5CF6)),
                  suffixIcon: IconButton(onPressed: () => setState(() => _obscure = !_obscure), icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded)),
                  filled: true,
                  fillColor: const Color(0xFFFAF7F1),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFECE2D8))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFECE2D8))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFF8C5CF6), width: 1.4)),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF251538), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                  icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.lock_open_rounded, size: 18),
                  label: const Text('Unlock', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
              if (widget.onRecoverTap != null) ...[
                const SizedBox(height: 8),
                TextButton(onPressed: _busy ? null : widget.onRecoverTap, child: const Text('Recover lock', style: TextStyle(fontWeight: FontWeight.w900))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
