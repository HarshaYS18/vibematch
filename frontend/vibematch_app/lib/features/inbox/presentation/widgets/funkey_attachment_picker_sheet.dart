import 'package:flutter/material.dart';

import '../../models/inbox_models.dart';

class FunKeyAttachmentPickerSheet extends StatelessWidget {
  const FunKeyAttachmentPickerSheet({
    super.key,
    required this.onPick,
  });

  final ValueChanged<InboxMessageType> onPick;

  static const _ink = Color(0xFF111114);
  static const _muted = Color(0xFF71717A);
  static const _line = Color(0xFFEDEDEF);
  static const _blue = Color(0xFF3797F0);

  @override
  Widget build(BuildContext context) {
    final items = <_AttachmentOption>[
      _AttachmentOption(
        type: InboxMessageType.image,
        icon: Icons.image_rounded,
        label: 'Gallery',
      ),
      _AttachmentOption(
        type: InboxMessageType.document,
        icon: Icons.description_rounded,
        label: 'Document',
      ),
      _AttachmentOption(
        type: InboxMessageType.location,
        icon: Icons.location_on_rounded,
        label: 'Location',
      ),
    ];

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: EdgeInsets.fromLTRB(
          16,
          10,
          16,
          14 + MediaQuery.paddingOf(context).bottom,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4D4D8),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Add to chat',
              style: TextStyle(
                color: _ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Choose what you want to send.',
              style: TextStyle(
                color: _muted,
                fontSize: 12.2,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: items.map((item) {
                return InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => onPick(item.type),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _line),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: _blue.withValues(alpha: 0.10),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(item.icon, color: _blue),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.label,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentOption {
  const _AttachmentOption({
    required this.type,
    required this.icon,
    required this.label,
  });

  final InboxMessageType type;
  final IconData icon;
  final String label;
}