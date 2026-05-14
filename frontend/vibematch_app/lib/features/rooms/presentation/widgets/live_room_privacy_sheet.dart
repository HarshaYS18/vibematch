import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/active_room_context.dart';
import '../../data/room_api_service.dart';
import '../live_room_models.dart';
import 'room_theme.dart';

class LiveRoomPrivacySheet extends StatefulWidget {
  const LiveRoomPrivacySheet({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
    this.roomId,
  });

  final RoomPrivacyMode currentMode;
  final ValueChanged<RoomPrivacyMode> onModeChanged;
  final String? roomId;

  @override
  State<LiveRoomPrivacySheet> createState() => _LiveRoomPrivacySheetState();
}

class _LiveRoomPrivacySheetState extends State<LiveRoomPrivacySheet> {
  late RoomPrivacyMode _mode;
  final TextEditingController _passwordController = TextEditingController();
  final RoomApiService _roomApi = const RoomApiService();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.currentMode;
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveMode(RoomPrivacyMode mode) async {
    if (_saving) return;
    final roomId = (widget.roomId ?? ActiveRoomContext.roomPublicId ?? '').trim();
    if (roomId.isEmpty) {
      RoomToast.show(context, 'Room ID missing. Re-enter room and try again.');
      return;
    }

    setState(() {
      _saving = true;
      _mode = mode;
    });

    try {
      final updated = await _roomApi.updateRoomMode(roomId: roomId, mode: _backendModeName(mode));
      if (!mounted) return;
      final confirmedMode = privacyModeFromTitle(updated.mode);
      setState(() => _mode = confirmedMode);
      widget.onModeChanged(confirmedMode);
      RoomToast.show(context, _successMessage(confirmedMode));
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => _mode = widget.currentMode);
      RoomToast.show(context, error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _backendModeName(RoomPrivacyMode mode) {
    switch (mode) {
      case RoomPrivacyMode.open:
        return 'Open';
      case RoomPrivacyMode.locked:
        return 'Locked';
      case RoomPrivacyMode.membersOnly:
        return 'Members Only';
      case RoomPrivacyMode.privateVibe:
        return 'Secret Vibe';
    }
  }

  String _successMessage(RoomPrivacyMode mode) {
    switch (mode) {
      case RoomPrivacyMode.open:
        return 'Room is now Open and visible in eligible lists.';
      case RoomPrivacyMode.locked:
        return 'Room is now Locked. Host/admins can enter; users need approved access/invite.';
      case RoomPrivacyMode.membersOnly:
        return 'Room is now Members Only. Only approved members/admins can enter.';
      case RoomPrivacyMode.privateVibe:
        return 'Secret Vibe enabled. Room is hidden from public discovery.';
    }
  }

  String _modeDescription(RoomPrivacyMode mode) {
    switch (mode) {
      case RoomPrivacyMode.open:
        return 'Visible publicly. Visitors can enter, but they are not members until approved.';
      case RoomPrivacyMode.locked:
        return 'Host/admins enter directly. Users need approved access, invite, or future password support.';
      case RoomPrivacyMode.membersOnly:
        return 'Only approved chatroom members, room admins, host, and Owner roles can enter.';
      case RoomPrivacyMode.privateVibe:
        return 'Hidden from discovery/trending. No public presence reveal. Entry only by host/admin invite or approval.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.46,
        child: Container(
          padding: EdgeInsets.fromLTRB(
            12,
            8,
            12,
            MediaQuery.paddingOf(context).bottom + 10,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(width: 42),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Room Privacy',
                      style: TextStyle(
                        color: RoomColors.plum,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (_saving)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Mode changes are backend-enforced and affect room entry/discovery rules.',
                style: TextStyle(
                  color: Color(0xFF82758E),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  physics: const BouncingScrollPhysics(),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    ...RoomPrivacyMode.values.map((mode) {
                      return _PrivacyTile(
                        mode: mode,
                        selected: _mode == mode,
                        description: _modeDescription(mode),
                        saving: _saving,
                        onTap: () => unawaited(_saveMode(mode)),
                      );
                    }),
                    if (_mode == RoomPrivacyMode.locked) ...[
                      const SizedBox(height: 6),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        enabled: false,
                        decoration: InputDecoration(
                          hintText: 'Password support will be wired after invite/access approvals',
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFFFAF7F1),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide.none),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyTile extends StatelessWidget {
  const _PrivacyTile({
    required this.mode,
    required this.selected,
    required this.description,
    required this.saving,
    required this.onTap,
  });

  final RoomPrivacyMode mode;
  final bool selected;
  final String description;
  final bool saving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: saving ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? RoomColors.aqua.withValues(alpha: 0.12) : const Color(0xFFFCFAF6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? RoomColors.aqua.withValues(alpha: 0.30) : const Color(0xFFE8DDCF),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(mode.icon, color: selected ? RoomColors.aqua : RoomColors.plum, size: 18),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.label,
                    style: TextStyle(
                      color: selected ? RoomColors.aqua : RoomColors.plum,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Color(0xFF82758E),
                      fontSize: 10.3,
                      height: 1.18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.check_circle_rounded, color: RoomColors.aqua, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}
