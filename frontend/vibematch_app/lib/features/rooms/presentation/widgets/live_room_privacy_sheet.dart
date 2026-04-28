import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'room_theme.dart';

class LiveRoomPrivacySheet extends StatefulWidget {
  const LiveRoomPrivacySheet({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
  });

  final RoomPrivacyMode currentMode;
  final ValueChanged<RoomPrivacyMode> onModeChanged;

  @override
  State<LiveRoomPrivacySheet> createState() => _LiveRoomPrivacySheetState();
}

class _LiveRoomPrivacySheetState extends State<LiveRoomPrivacySheet> {
  late RoomPrivacyMode _mode;
  final TextEditingController _passwordController = TextEditingController();

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
              const Text(
                'Password & Privacy',
                style: TextStyle(
                  color: RoomColors.plum,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Locked mode applies only after a password is saved.',
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
                        onTap: () {
                          setState(() => _mode = mode);
                          if (mode != RoomPrivacyMode.locked) {
                            widget.onModeChanged(mode);
                          }
                        },
                      );
                    }),
                    if (_mode == RoomPrivacyMode.locked) ...[
                      const SizedBox(height: 6),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: 'Set room lock password',
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFFFAF7F1),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(13),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_passwordController.text.trim().isEmpty) {
                              RoomToast.show(context, 'Enter a lock password');
                              return;
                            }
                            widget.onModeChanged(RoomPrivacyMode.locked);
                            RoomToast.show(context, 'Room lock saved');
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: RoomColors.plum,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                          ),
                          child: const Text(
                            'Save lock',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
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
    required this.onTap,
  });

  final RoomPrivacyMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? RoomColors.aqua.withValues(alpha: 0.12)
              : const Color(0xFFFCFAF6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? RoomColors.aqua.withValues(alpha: 0.30)
                : const Color(0xFFE8DDCF),
          ),
        ),
        child: Row(
          children: [
            Icon(
              mode.icon,
              color: selected ? RoomColors.aqua : RoomColors.plum,
              size: 18,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                mode.label,
                style: TextStyle(
                  color: selected ? RoomColors.aqua : RoomColors.plum,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: RoomColors.aqua,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}
