import 'package:flutter/material.dart';

import '../models/ribbon_background_style.dart';
import '../models/ribbon_message.dart';

class RibbonMessageComposerSheet extends StatefulWidget {
  final String roomId;
  final String senderUserId;
  final String senderName;
  final ValueChanged<RibbonMessage> onSendRibbonMessage;

  const RibbonMessageComposerSheet({
    super.key,
    required this.roomId,
    required this.senderUserId,
    required this.senderName,
    required this.onSendRibbonMessage,
  });

  @override
  State<RibbonMessageComposerSheet> createState() => _RibbonMessageComposerSheetState();
}

class _RibbonMessageComposerSheetState extends State<RibbonMessageComposerSheet> {
  final TextEditingController _controller = TextEditingController();
  RibbonBackgroundType _selectedBackgroundType = RibbonBackgroundType.darkLuxury;

  static const int _coinCost = 1000;
  static const int _maxCharacters = 50;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSend {
    final length = _controller.text.trim().characters.length;
    return length > 0 && length <= _maxCharacters;
  }

  @override
  Widget build(BuildContext context) {
    final textLength = _controller.text.characters.length;

    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Floating Ribbon Message',
              style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose a custom ribbon background and send a premium sliding message.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.68),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD66B), size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    '1000 coins per message',
                    style: TextStyle(color: Color(0xFFFFE7A0), fontSize: 14, fontWeight: FontWeight.w900),
                  ),
                  const Spacer(),
                  Text(
                    '$textLength/$_maxCharacters',
                    style: TextStyle(
                      color: textLength > _maxCharacters ? const Color(0xFFFF6B8A) : Colors.white.withValues(alpha: 0.68),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              maxLength: _maxCharacters,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              cursorColor: const Color(0xFFFFD66B),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Type up to 50 characters...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontWeight: FontWeight.w600),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: Color(0xFFFFD66B)),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Ribbon Background',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: RibbonBackgroundType.values.map((type) {
                final style = RibbonBackgroundStyle.fromType(type);
                final selected = _selectedBackgroundType == type;
                return GestureDetector(
                  onTap: () => setState(() => _selectedBackgroundType = type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(colors: style.bodyColors),
                      border: Border.all(
                        color: selected ? style.coinTextColor : Colors.white.withValues(alpha: 0.14),
                        width: selected ? 1.5 : 1,
                      ),
                      boxShadow: selected
                          ? [BoxShadow(color: style.glowColor.withValues(alpha: 0.35), blurRadius: 14)]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(style.badgeIcon, color: style.coinTextColor, size: 15),
                        const SizedBox(width: 5),
                        Text(
                          style.label,
                          style: TextStyle(
                            color: style.secondaryTextColor,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _canSend ? _send : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD66B),
                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.10),
                  foregroundColor: const Color(0xFF251538),
                  disabledForegroundColor: Colors.white.withValues(alpha: 0.35),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: const Text('Send Floating Text', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _send() {
    final message = RibbonMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      roomId: widget.roomId,
      senderUserId: widget.senderUserId,
      senderName: widget.senderName,
      text: _controller.text.trim(),
      coinCost: _coinCost,
      createdAt: DateTime.now(),
      backgroundType: _selectedBackgroundType,
    );

    widget.onSendRibbonMessage(message);
    Navigator.pop(context);
  }
}
