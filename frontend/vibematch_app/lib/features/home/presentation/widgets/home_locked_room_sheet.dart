import 'package:flutter/material.dart';

import '../../models/home_room.dart';
import 'home_common_widgets.dart';

class HomeLockedRoomSheet extends StatefulWidget {
  const HomeLockedRoomSheet({
    super.key,
    required this.room,
    required this.onPasswordAccepted,
    required this.onWrongPassword,
  });

  final HomeRoom room;
  final VoidCallback onPasswordAccepted;
  final VoidCallback onWrongPassword;

  @override
  State<HomeLockedRoomSheet> createState() => _HomeLockedRoomSheetState();
}

class _HomeLockedRoomSheetState extends State<HomeLockedRoomSheet> {
  final TextEditingController _passwordController = TextEditingController();
  bool _passwordVisible = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HomeSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const HomeSheetHandle(),
          const SizedBox(height: 16),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: const Color(0xFFC99A3B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.lock_rounded, color: Color(0xFFC99A3B), size: 32),
          ),
          const SizedBox(height: 14),
          const Text(
            'Locked Room',
            style: TextStyle(
              color: Color(0xFF251538),
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.room.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF7B6A86),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _passwordController,
            obscureText: !_passwordVisible,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Color(0xFF251538), fontWeight: FontWeight.w900),
            decoration: InputDecoration(
              hintText: 'Enter password',
              hintStyle: const TextStyle(color: Color(0xFF9B8CA5), fontWeight: FontWeight.w600),
              prefixIcon: const Icon(Icons.lock_rounded, color: Color(0xFFC99A3B)),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                icon: Icon(
                  _passwordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: const Color(0xFF7B6A86),
                ),
              ),
              filled: true,
              fillColor: const Color(0xFFFAF7F1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: Color(0xFFEDE3D7)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: Color(0xFFEDE3D7)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: Color(0xFFC99A3B), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Mock password: 1234',
              style: TextStyle(
                color: Color(0xFF9B8CA5),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: HomeSecondaryButton(
                  text: 'Cancel',
                  icon: Icons.close_rounded,
                  onTap: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: HomePrimaryButton(
                  text: 'Enter',
                  icon: Icons.lock_open_rounded,
                  onTap: () {
                    if (_passwordController.text.trim() != '1234') {
                      widget.onWrongPassword();
                      return;
                    }
                    Navigator.pop(context);
                    widget.onPasswordAccepted();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
