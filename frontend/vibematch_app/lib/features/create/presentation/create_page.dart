import 'package:flutter/material.dart';

import '../../rooms/presentation/live_room_page.dart';

class CreatePage extends StatefulWidget {
  const CreatePage({super.key});

  @override
  State<CreatePage> createState() => _CreatePageState();
}

class _CreatePageState extends State<CreatePage> {
  final TextEditingController _roomNameController = TextEditingController(
    text: 'Late Night Chill',
  );

  String _selectedLanguage = 'Telugu';
  _RoomMode _selectedMode = _RoomMode.open;
  bool _roomImageSelected = false;

  final List<String> _languages = const [
    'Telugu',
    'Hindi',
    'English',
    'Tamil',
    'Malayalam',
    'Kannada',
    'Bengali',
    'Marathi',
    'Punjabi',
    'Gujarati',
    'Odia',
    'Urdu',
    'Arabic',
    'Spanish',
    'French',
    'Other',
  ];

  @override
  void dispose() {
    _roomNameController.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF251538),
        content: Text(message),
      ),
    );
  }

  String _generateRoomId() {
    final now = DateTime.now().millisecondsSinceEpoch.toString();
    return 'VM${now.substring(now.length - 6)}';
  }

  void _openLanguageSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _CreateSheet(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SheetHandle(),
              const SizedBox(height: 14),
              const Text(
                'Choose room language',
                style: TextStyle(
                  color: Color(0xFF251538),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _languages.length,
                  itemBuilder: (context, index) {
                    final language = _languages[index];
                    final selected = language == _selectedLanguage;

                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      leading: Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.language_rounded,
                        color: selected
                            ? const Color(0xFF12C7B7)
                            : const Color(0xFF6A5877),
                      ),
                      title: Text(
                        language,
                        style: TextStyle(
                          color: const Color(0xFF251538),
                          fontWeight:
                              selected ? FontWeight.w900 : FontWeight.w700,
                        ),
                      ),
                      onTap: () {
                        setState(() => _selectedLanguage = language);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _createRoom() {
    final roomName = _roomNameController.text.trim();

    if (roomName.isEmpty) {
      _toast('Enter a room name');
      return;
    }

    final roomId = _generateRoomId();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _CreateSheet(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SheetHandle(),
              const SizedBox(height: 16),
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF12C7B7),
                      Color(0xFF8C5CF6),
                      Color(0xFFE84C72),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8C5CF6).withValues(alpha: 0.28),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.graphic_eq_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Room Ready',
                style: TextStyle(
                  color: Color(0xFF251538),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                roomName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF251538).withValues(alpha: 0.72),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _ReadyInfoRow(label: 'Room ID', value: roomId),
              _ReadyInfoRow(label: 'Mode', value: _selectedMode.title),
              _ReadyInfoRow(label: 'Language', value: _selectedLanguage),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _SecondaryButton(
                      text: 'Edit',
                      icon: Icons.edit_rounded,
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PrimaryButton(
                      text: 'Enter Room',
                      icon: Icons.login_rounded,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LiveRoomPage(
                              roomName: roomName,
                              roomId: roomId,
                              language: _selectedLanguage,
                              modeTitle: _selectedMode.title,
                              onlineCount: 1,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildCreateCard()),
            SliverToBoxAdapter(child: _buildModeSection()),
            SliverToBoxAdapter(child: _buildRulesCard()),
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
          child: _PrimaryButton(
            text: 'Create Room',
            icon: Icons.add_circle_rounded,
            onTap: _createRoom,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF12C7B7),
                  Color(0xFF8C5CF6),
                ],
              ),
            ),
            child: const Icon(
              Icons.add_home_work_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create Room',
                  style: TextStyle(
                    color: Color(0xFF251538),
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Start your own live vibe',
                  style: TextStyle(
                    color: Color(0xFF7B6A86),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _toast('Create room help opened'),
            icon: const Icon(
              Icons.help_rounded,
              color: Color(0xFF4A2A63),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 8, 18, 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFEDE3D7)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF251538).withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              setState(() => _roomImageSelected = !_roomImageSelected);
              _toast(
                _roomImageSelected
                    ? 'Mock room image selected'
                    : 'Room image removed',
              );
            },
            child: Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(34),
                gradient: _roomImageSelected
                    ? const LinearGradient(
                        colors: [
                          Color(0xFF12C7B7),
                          Color(0xFF8C5CF6),
                          Color(0xFFE84C72),
                        ],
                      )
                    : null,
                color: _roomImageSelected ? null : const Color(0xFFF4EEE7),
                border: Border.all(color: const Color(0xFFEDE3D7)),
              ),
              child: Icon(
                _roomImageSelected
                    ? Icons.image_rounded
                    : Icons.add_photo_alternate_rounded,
                color: _roomImageSelected
                    ? Colors.white
                    : const Color(0xFF7B6A86),
                size: 38,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _roomImageSelected ? 'Room image ready' : 'Tap to add room image',
            style: const TextStyle(
              color: Color(0xFF7B6A86),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _roomNameController,
            style: const TextStyle(
              color: Color(0xFF251538),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
            decoration: InputDecoration(
              labelText: 'Room name',
              labelStyle: const TextStyle(
                color: Color(0xFF7B6A86),
                fontWeight: FontWeight.w700,
              ),
              prefixIcon: const Icon(
                Icons.graphic_eq_rounded,
                color: Color(0xFF12C7B7),
              ),
              filled: true,
              fillColor: const Color(0xFFFAF7F1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: const BorderSide(color: Color(0xFFEDE3D7)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: const BorderSide(color: Color(0xFFEDE3D7)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: const BorderSide(
                  color: Color(0xFF12C7B7),
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _openLanguageSheet,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7F1),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFEDE3D7)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.language_rounded,
                    color: Color(0xFF8C5CF6),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Room language',
                      style: TextStyle(
                        color: Color(0xFF7B6A86),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    _selectedLanguage,
                    style: const TextStyle(
                      color: Color(0xFF251538),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF4A2A63),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Room mode',
            style: TextStyle(
              color: Color(0xFF251538),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ..._RoomMode.values.map(
            (mode) => _ModeCard(
              mode: mode,
              selected: mode == _selectedMode,
              onTap: () => setState(() => _selectedMode = mode),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E3),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFFFE4A8)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.security_rounded,
            color: Color(0xFFC99A3B),
            size: 22,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Backend later controls locked access, Secret Vibe privacy, member approval, image chat, guest messages, audit logs, and room moderation hierarchy.',
              style: TextStyle(
                color: Color(0xFF6A4E18),
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _RoomMode {
  open(
    title: 'Open',
    subtitle: 'Anyone can enter and join the vibe',
    icon: Icons.public_rounded,
    color: Color(0xFF12C7B7),
  ),
  locked(
    title: 'Locked',
    subtitle: 'Users need a password or invite',
    icon: Icons.lock_rounded,
    color: Color(0xFFC99A3B),
  ),
  secretVibe(
    title: 'Secret Vibe',
    subtitle: 'Private room presence hidden from public UI',
    icon: Icons.visibility_off_rounded,
    color: Color(0xFF8C5CF6),
  ),
  vibeSync(
    title: 'Vibe Sync',
    subtitle: 'Music-style room with animated mood',
    icon: Icons.graphic_eq_rounded,
    color: Color(0xFFE84C72),
  ),
  membersOnly(
    title: 'Members Only',
    subtitle: 'Only approved room members can chat',
    icon: Icons.workspace_premium_rounded,
    color: Color(0xFF4A2A63),
  );

  const _RoomMode({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final _RoomMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? mode.color.withValues(alpha: 0.11) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? mode.color : const Color(0xFFEDE3D7),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF251538).withValues(alpha: 0.045),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: mode.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(mode.icon, color: mode.color, size: 23),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.title,
                    style: const TextStyle(
                      color: Color(0xFF251538),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mode.subtitle,
                    style: const TextStyle(
                      color: Color(0xFF7B6A86),
                      fontSize: 12,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected ? mode.color : const Color(0xFFD4C7BB),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.text,
    required this.icon,
    required this.onTap,
  });

  final String text;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF12C7B7),
              Color(0xFF8C5CF6),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF12C7B7).withValues(alpha: 0.24),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.text,
    required this.icon,
    required this.onTap,
  });

  final String text;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: const Color(0xFFFAF7F1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEDE3D7)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF4A2A63), size: 20),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                color: Color(0xFF4A2A63),
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateSheet extends StatelessWidget {
  const _CreateSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(14),
      padding: EdgeInsets.fromLTRB(
        18,
        10,
        18,
        18 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 5,
        decoration: BoxDecoration(
          color: const Color(0xFFE0D5CB),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _ReadyInfoRow extends StatelessWidget {
  const _ReadyInfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDE3D7)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7B6A86),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF251538),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}