import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'room_theme.dart';

class RoomChatFeed extends StatelessWidget {
  const RoomChatFeed({
    super.key,
    required this.messages,
    required this.canManageSeatApplications,
    required this.onApproveSeatApplication,
  });

  final List<ChatEntry> messages;
  final bool canManageSeatApplications;
  final ValueChanged<ChatEntry> onApproveSeatApplication;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const SizedBox.expand();
    }

    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return _CompactChatLine(
          message: message,
          canManageSeatApplications: canManageSeatApplications,
          onApproveSeatApplication: () => onApproveSeatApplication(message),
        );
      },
    );
  }
}

class _CompactChatLine extends StatelessWidget {
  const _CompactChatLine({
    required this.message,
    required this.canManageSeatApplications,
    required this.onApproveSeatApplication,
  });

  final ChatEntry message;
  final bool canManageSeatApplications;
  final VoidCallback onApproveSeatApplication;

  @override
  Widget build(BuildContext context) {
    final showAgree = message.isSeatApplication && canManageSeatApplications && !message.applicationApproved;

    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: message.isGift
            ? RoomColors.gold.withValues(alpha: 0.13)
            : message.isSeatApplication
                ? RoomColors.aqua.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: message.isGift
              ? RoomColors.gold.withValues(alpha: 0.24)
              : message.isSeatApplication
                  ? RoomColors.aqua.withValues(alpha: 0.24)
                  : Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: message.isGift
                ? RoomColors.gold
                : message.isSeatApplication
                    ? RoomColors.aqua
                    : RoomColors.violet,
            child: Text(
              avatarLetter(message.senderName),
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: RichText(
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '${message.senderName}  ',
                    style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w900),
                  ),
                  TextSpan(
                    text: 'VIP ${message.vipLevel}  S${message.sendingLevel}  R${message.receivingLevel}: ',
                    style: TextStyle(color: RoomColors.gold.withValues(alpha: 0.92), fontSize: 10.5, fontWeight: FontWeight.w900),
                  ),
                  TextSpan(
                    text: message.message,
                    style: TextStyle(
                      color: message.isGift
                          ? RoomColors.gold
                          : message.isSeatApplication
                              ? RoomColors.aqua
                              : Colors.white.withValues(alpha: 0.88),
                      fontSize: 12.5,
                      fontWeight: message.isGift || message.isSeatApplication ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showAgree) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onApproveSeatApplication,
              child: Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: RoomColors.aqua,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: RoomColors.aqua.withValues(alpha: 0.24),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Text(
                  'Agree',
                  style: TextStyle(color: RoomColors.deep, fontSize: 11, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class RoomInputDock extends StatelessWidget {
  const RoomInputDock({
    super.key,
    required this.controller,
    this.focusNode,
    required this.micMuted,
    required this.inboxUnreadCount,
    required this.showImageButton,
    required this.onInboxTap,
    required this.onImageTap,
    required this.onEmojiTap,
    required this.onSendTap,
    required this.onMicTap,
    required this.onGamesTap,
    required this.onGiftTap,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool micMuted;
  final int inboxUnreadCount;
  final bool showImageButton;
  final VoidCallback onInboxTap;
  final VoidCallback onImageTap;
  final VoidCallback onEmojiTap;
  final VoidCallback onSendTap;
  final VoidCallback onMicTap;
  final VoidCallback onGamesTap;
  final VoidCallback onGiftTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
        decoration: BoxDecoration(
          color: RoomColors.deep.withValues(alpha: 0.94),
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
        ),
        child: Row(
          children: [
            _DockButton(
              icon: Icons.mail_outline_rounded,
              onTap: onInboxTap,
              badgeCount: inboxUnreadCount,
            ),
            if (showImageButton) ...[
              const SizedBox(width: 5),
              _DockButton(icon: Icons.image_rounded, onTap: onImageTap),
            ],
            const SizedBox(width: 5),
            Expanded(
              child: Container(
                height: 36,
                padding: const EdgeInsets.only(left: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.30),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5),
                        decoration: InputDecoration(
                          hintText: 'Message...',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.36), fontWeight: FontWeight.w700),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onSubmitted: (_) => onSendTap(),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: onEmojiTap,
                      icon: const Icon(Icons.emoji_emotions_rounded, color: RoomColors.gold, size: 19),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: onSendTap,
                      icon: const Icon(Icons.send_rounded, color: RoomColors.aqua, size: 20),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 5),
            _DockButton(
              icon: micMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
              onTap: onMicTap,
              active: !micMuted,
              muted: micMuted,
            ),
            const SizedBox(width: 5),
            _DockButton(icon: Icons.sports_esports_rounded, onTap: onGamesTap),
            const SizedBox(width: 5),
            _DockButton(icon: Icons.card_giftcard_rounded, onTap: onGiftTap, gift: true),
          ],
        ),
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.icon,
    required this.onTap,
    this.active = false,
    this.muted = false,
    this.gift = false,
    this.badgeCount = 0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final bool muted;
  final bool gift;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final bg = muted
        ? RoomColors.coral.withValues(alpha: 0.22)
        : active
            ? RoomColors.aqua.withValues(alpha: 0.24)
            : Colors.white.withValues(alpha: 0.055);
    final iconColor = muted
        ? RoomColors.coral
        : active
            ? RoomColors.aqua
            : Colors.white;

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: gift ? const LinearGradient(colors: [RoomColors.gold, RoomColors.coral]) : null,
                color: gift ? null : bg,
                border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
              ),
              child: Icon(icon, color: gift ? Colors.white : iconColor, size: 19),
            ),
            if (badgeCount > 0)
              Positioned(
                right: -2,
                top: -3,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: RoomColors.coral,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: RoomColors.deep, width: 1),
                  ),
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
