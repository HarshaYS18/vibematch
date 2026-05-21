import 'package:flutter/material.dart';

import '../../models/inbox_models.dart';

class FunKeyAttachmentPickerSheet extends StatelessWidget {
  const FunKeyAttachmentPickerSheet({super.key, required this.onPick});

  final ValueChanged<InboxMessageType> onPick;

  static const _ink = Color(0xFF111114);
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
              'Add',
              style: TextStyle(
                color: _ink,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: items.map((item) {
                return _AttachmentButton(
                  item: item,
                  onTap: () => onPick(item.type),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentButton extends StatelessWidget {
  const _AttachmentButton({required this.item, required this.onTap});

  final _AttachmentOption item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: FunKeyAttachmentPickerSheet._blue.withValues(
                  alpha: 0.10,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                item.icon,
                color: FunKeyAttachmentPickerSheet._blue,
                size: 22,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.label,
              style: const TextStyle(
                color: FunKeyAttachmentPickerSheet._ink,
                fontSize: 11.8,
                fontWeight: FontWeight.w700,
              ),
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
