import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/models/current_user.dart';
import '../../media/data/media_upload_service.dart';
import '../../rooms/data/live_room_media_signaling_service.dart';
import '../../rooms/data/room_api_service.dart';
import '../../rooms/presentation/live_room_models.dart';
import '../../rooms/presentation/live_room_page.dart';

class CreatePage extends StatefulWidget {
  const CreatePage({super.key, required this.currentUser, this.onRoomCreated});

  final CurrentUser currentUser;
  final ValueChanged<RealRoom>? onRoomCreated;

  @override
  State<CreatePage> createState() => _CreatePageState();
}

class _CreatePageState extends State<CreatePage> {
  final TextEditingController _roomNameController = TextEditingController();
  final TextEditingController _lockPasswordController = TextEditingController();
  final RoomApiService _roomApiService = const RoomApiService();
  final MediaUploadService _mediaUploadService = const MediaUploadService();

  String _selectedLanguage = 'Telugu';
  _RoomMode _selectedMode = _RoomMode.open;
  String? _roomCoverUrl;
  bool _uploadingRoomCover = false;
  bool _allowScreenshots = true;
  bool _creatingRoom = false;
  bool _obscureLockPassword = true;

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
    _lockPasswordController.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF251538), content: Text(message)));
  }

  Future<void> _pickCropAndUploadRoomCover() async {
    if (_uploadingRoomCover || _creatingRoom) return;
    setState(() => _uploadingRoomCover = true);
    try {
      final upload = await _mediaUploadService.pickCropAndUploadRoomCover(context);
      if (!mounted) return;
      setState(() => _roomCoverUrl = upload.url);
      _toast('Room cover uploaded');
    } on MediaUploadCancelledException {
      return;
    } catch (error) {
      if (!mounted) return;
      _toast(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _uploadingRoomCover = false);
    }
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
              const SizedBox(height: 12),
              const Text('Choose room language', style: TextStyle(color: Color(0xFF251538), fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _languages.length,
                  itemBuilder: (context, index) {
                    final language = _languages[index];
                    final selected = language == _selectedLanguage;
                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      leading: Icon(selected ? Icons.check_circle_rounded : Icons.language_rounded, color: selected ? const Color(0xFF12C7B7) : const Color(0xFF6A5877), size: 20),
                      title: Text(language, style: TextStyle(color: const Color(0xFF251538), fontSize: 13, fontWeight: selected ? FontWeight.w900 : FontWeight.w700)),
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

  Future<void> _createRoom() async {
    final roomName = _roomNameController.text.trim();
    final lockPassword = _lockPasswordController.text.trim();
    if (roomName.isEmpty) {
      _toast('Enter a room name');
      return;
    }
    if (_selectedMode == _RoomMode.locked && lockPassword.length != 4) {
      _toast('Enter the 4-digit room lock');
      return;
    }
    if (_creatingRoom) return;

    setState(() => _creatingRoom = true);
    try {
      final room = await _roomApiService.createRoom(
        name: roomName,
        subtitle: '$_selectedLanguage ${_selectedMode.title} room',
        language: _selectedLanguage,
        mode: _selectedMode.title,
        type: 'Chat',
        avatarUrl: _roomCoverUrl,
        coverPhotoUrl: _roomCoverUrl,
        allowScreenshots: _allowScreenshots,
        lockPassword: _selectedMode == _RoomMode.locked ? lockPassword : null,
      );
      widget.onRoomCreated?.call(room);
      if (!mounted) return;
      _showRoomReadySheet(room);
    } catch (error) {
      if (!mounted) return;
      _toast(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _creatingRoom = false);
    }
  }

  SeatUser _createdRoomHostSeatUser() {
    final currentUser = widget.currentUser;
    final isOfficial = currentUser.canSeeOwnerControls;

    return SeatUser(
      id: currentUser.publicUserId.toString(),
      name: currentUser.displayName ?? currentUser.username ?? 'Vibe User',
      roleLabel: 'Channel Host',
      familyName: '',
      familyLevel: 'bronze',
      relationshipText: '',
      vipLevel: currentUser.vip.vipLevel,
      svipLevel: currentUser.vip.svipLevel,
      sendingLevel: currentUser.wallet.sendLevel <= 0 ? 1 : currentUser.wallet.sendLevel,
      receivingLevel: currentUser.wallet.receiveLevel <= 0 ? 1 : currentUser.wallet.receiveLevel,
      sentExp: currentUser.wallet.monthlyGiftCoinsSent,
      receivedExp: currentUser.wallet.monthlyGiftCoinsReceived,
      medals: const <String>[],
      avatarColors: isOfficial
          ? const <Color>[Color(0xFFFFC857), Color(0xFFE84C72)]
          : const <Color>[Color(0xFF12C7B7), Color(0xFF6D5DF6)],
      avatarUrl: currentUser.avatarUrl,
      isCurrentUser: true,
      isHost: true,
      isRoomAdmin: true,
    );
  }

  void _showRoomReadySheet(RealRoom room) {
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
              const SizedBox(height: 14),
              Container(
                width: 96,
                height: 54,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: room.coverPhotoUrl == null || room.coverPhotoUrl!.trim().isEmpty ? const LinearGradient(colors: [Color(0xFF12C7B7), Color(0xFF8C5CF6), Color(0xFFE84C72)]) : null,
                  boxShadow: [BoxShadow(color: const Color(0xFF8C5CF6).withValues(alpha: 0.22), blurRadius: 18, offset: const Offset(0, 8))],
                ),
                child: room.coverPhotoUrl == null || room.coverPhotoUrl!.trim().isEmpty
                    ? const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 29)
                    : Image.network(room.coverPhotoUrl!, fit: BoxFit.cover),
              ),
              const SizedBox(height: 12),
              const Text('Room Ready', style: TextStyle(color: Color(0xFF251538), fontSize: 21, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Text(room.name, textAlign: TextAlign.center, style: TextStyle(color: const Color(0xFF251538).withValues(alpha: 0.72), fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              _ReadyInfoRow(label: 'Room ID', value: room.id),
              _ReadyInfoRow(label: 'Mode', value: room.mode),
              _ReadyInfoRow(label: 'Language', value: room.language),
              _ReadyInfoRow(label: 'Screenshots', value: room.allowScreenshots ? 'Allowed' : 'Denied'),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _SecondaryButton(text: 'Edit', icon: Icons.edit_rounded, onTap: () => Navigator.pop(context))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PrimaryButton(
                      text: 'Enter Room',
                      icon: Icons.login_rounded,
                      onTap: () {
                        final mediaService = LiveRoomMediaSignalingService.instance;
                        mediaService.configureRoom(roomId: room.id, roomName: room.name);
                        mediaService.seedActiveRoomSeatUser(_createdRoomHostSeatUser());
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LiveRoomPage(
                              roomName: room.name,
                              roomId: room.id,
                              language: room.language,
                              modeTitle: room.mode,
                              onlineCount: room.onlineCount,
                            ),
                          ),
                        );
                        _toast(room.allowScreenshots ? 'Screenshots allowed for this room' : 'Screenshots denied for this room');
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
            SliverToBoxAdapter(child: _buildCreateCard()),
            SliverToBoxAdapter(child: _buildModeSection()),
            SliverToBoxAdapter(child: _buildRulesCard()),
            const SliverToBoxAdapter(child: SizedBox(height: 128)),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ScreenshotToggle(
                allowScreenshots: _allowScreenshots,
                onChanged: (value) {
                  setState(() => _allowScreenshots = value);
                  _toast(value ? 'Screenshots allowed' : 'Screenshots denied');
                },
              ),
              const SizedBox(height: 8),
              _PrimaryButton(text: _creatingRoom ? 'Saving Room' : 'Save Room', icon: Icons.add_circle_rounded, onTap: _createRoom),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateCard() {
    final hasCover = _roomCoverUrl?.trim().isNotEmpty == true;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFEDE3D7)), boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.045), blurRadius: 18, offset: const Offset(0, 8))]),
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickCropAndUploadRoomCover,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), color: hasCover ? null : const Color(0xFFF4EEE7), border: Border.all(color: const Color(0xFFEDE3D7))),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasCover)
                      Image.network(_roomCoverUrl!, fit: BoxFit.cover)
                    else
                      const Center(child: Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF7B6A86), size: 34)),
                    if (_uploadingRoomCover)
                      Container(
                        color: Colors.black.withValues(alpha: 0.28),
                        child: const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(_uploadingRoomCover ? 'Uploading room cover...' : hasCover ? 'Room cover ready' : 'Tap to add room cover photo', style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 13),
          TextField(
            controller: _roomNameController,
            style: const TextStyle(color: Color(0xFF251538), fontSize: 14.5, fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              hintText: 'Type channel name here',
              hintStyle: const TextStyle(color: Color(0xFF9B8FA3), fontSize: 12.5, fontWeight: FontWeight.w700),
              prefixIcon: const Icon(Icons.graphic_eq_rounded, color: Color(0xFF12C7B7), size: 19),
              filled: true,
              fillColor: const Color(0xFFFAF7F1),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFEDE3D7))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFEDE3D7))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFF12C7B7), width: 1.5)),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _openLanguageSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFFFAF7F1), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFEDE3D7))),
              child: Row(
                children: [
                  const Icon(Icons.language_rounded, color: Color(0xFF8C5CF6), size: 19),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Room language', style: TextStyle(color: Color(0xFF7B6A86), fontSize: 12.5, fontWeight: FontWeight.w800))),
                  Text(_selectedLanguage, style: const TextStyle(color: Color(0xFF251538), fontSize: 13, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 5),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF4A2A63), size: 20),
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.only(left: 2, bottom: 9), child: Text('Room mode', style: TextStyle(color: Color(0xFF251538), fontSize: 16, fontWeight: FontWeight.w900))),
          ..._RoomMode.values.map((mode) => _ModeCard(mode: mode, selected: mode == _selectedMode, onTap: () => setState(() => _selectedMode = mode))),
          if (_selectedMode == _RoomMode.locked) ...[
            const SizedBox(height: 4),
            _LockPasswordField(
              controller: _lockPasswordController,
              obscureText: _obscureLockPassword,
              onToggleObscure: () => setState(() => _obscureLockPassword = !_obscureLockPassword),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRulesCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: const Color(0xFFFFF7E3), borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFFFE4A8))),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.security_rounded, color: Color(0xFFC99A3B), size: 19),
          SizedBox(width: 10),
          Expanded(child: Text('This lifetime room keeps the same room ID, admins, members, level, and contribution data. Saving here only updates name, cover/avatar, language, screenshot permission, and access mode. Locked mode requires a 4-digit room lock.', style: TextStyle(color: Color(0xFF6A4E18), fontSize: 11.5, height: 1.28, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

enum _RoomMode {
  open(title: 'Open', subtitle: 'Anyone can enter and join the vibe', icon: Icons.public_rounded, color: Color(0xFF12C7B7)),
  locked(title: 'Locked', subtitle: 'Users need a 4-digit password or invite', icon: Icons.lock_rounded, color: Color(0xFFC99A3B)),
  secretVibe(title: 'Secret Vibe', subtitle: 'Private room presence hidden from public UI', icon: Icons.visibility_off_rounded, color: Color(0xFF8C5CF6)),
  membersOnly(title: 'Members Only', subtitle: 'Only approved room members can chat', icon: Icons.workspace_premium_rounded, color: Color(0xFF4A2A63));

  const _RoomMode({required this.title, required this.subtitle, required this.icon, required this.color});

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}

class _LockPasswordField extends StatefulWidget {
  const _LockPasswordField({
    required this.controller,
    required this.obscureText,
    required this.onToggleObscure,
  });

  final TextEditingController controller;
  final bool obscureText;
  final VoidCallback onToggleObscure;

  @override
  State<_LockPasswordField> createState() => _LockPasswordFieldState();
}

class _LockPasswordFieldState extends State<_LockPasswordField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant _LockPasswordField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _focusNode.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.text;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: const Color(0xFFFFF9EA), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFFFE4A8))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pin_rounded, color: Color(0xFFC99A3B), size: 18),
              const SizedBox(width: 7),
              const Expanded(child: Text('4-digit room lock', style: TextStyle(color: Color(0xFF251538), fontSize: 12.8, fontWeight: FontWeight.w900))),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: widget.onToggleObscure,
                icon: Icon(widget.obscureText ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: const Color(0xFF7B6A86), size: 18),
              ),
            ],
          ),
          const SizedBox(height: 7),
          GestureDetector(
            onTap: () => _focusNode.requestFocus(),
            child: Stack(
              children: [
                Row(
                  children: List.generate(4, (index) {
                    final filled = index < value.length;
                    final text = filled ? (widget.obscureText ? '•' : value[index]) : '';
                    return Expanded(
                      child: Container(
                        height: 54,
                        margin: EdgeInsets.only(right: index == 3 ? 0 : 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: filled ? const Color(0xFFC99A3B) : const Color(0xFFE8DDCF), width: filled ? 1.5 : 1),
                          boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: filled ? 0.06 : 0.025), blurRadius: 10, offset: const Offset(0, 5))],
                        ),
                        child: Text(text, style: const TextStyle(color: Color(0xFF251538), fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                      ),
                    );
                  }),
                ),
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.01,
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focusNode,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      maxLength: 4,
                      autofocus: true,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      decoration: const InputDecoration(counterText: '', border: InputBorder.none),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text('Users who are not invited/admin/member must enter these 4 digits to join.', style: TextStyle(color: Color(0xFF7B6A86), fontSize: 10.8, height: 1.25, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ScreenshotToggle extends StatelessWidget {
  const _ScreenshotToggle({required this.allowScreenshots, required this.onChanged});

  final bool allowScreenshots;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFEDE3D7)), boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.035), blurRadius: 12, offset: const Offset(0, 6))]),
      child: Row(
        children: [
          Icon(allowScreenshots ? Icons.screenshot_monitor_rounded : Icons.no_photography_rounded, color: allowScreenshots ? const Color(0xFF12C7B7) : const Color(0xFFE84C72), size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Screenshots', style: TextStyle(color: Color(0xFF251538), fontSize: 12.5, fontWeight: FontWeight.w900)),
                const SizedBox(height: 1),
                Text(allowScreenshots ? 'Allowed in this chatroom' : 'Denied in this chatroom', style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 10.8, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Switch(value: allowScreenshots, onChanged: onChanged, activeThumbColor: const Color(0xFF12C7B7)),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.mode, required this.selected, required this.onTap});

  final _RoomMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(color: selected ? mode.color.withValues(alpha: 0.10) : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: selected ? mode.color : const Color(0xFFEDE3D7), width: selected ? 1.4 : 1), boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.035), blurRadius: 12, offset: const Offset(0, 6))]),
        child: Row(
          children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: mode.color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(15)), child: Icon(mode.icon, color: mode.color, size: 20)),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mode.title, style: const TextStyle(color: Color(0xFF251538), fontSize: 14, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(mode.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.3, height: 1.2, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined, color: selected ? mode.color : const Color(0xFFD4C7BB), size: 20),
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.text, required this.icon, required this.onTap});

  final String text;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: const LinearGradient(colors: [Color(0xFF12C7B7), Color(0xFF8C5CF6)]), boxShadow: [BoxShadow(color: const Color(0xFF12C7B7).withValues(alpha: 0.20), blurRadius: 16, offset: const Offset(0, 8))]),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Colors.white, size: 19), const SizedBox(width: 7), Text(text, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900))]),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.text, required this.icon, required this.onTap});

  final String text;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(color: const Color(0xFFFAF7F1), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFEDE3D7))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: const Color(0xFF4A2A63), size: 19), const SizedBox(width: 7), Text(text, style: const TextStyle(color: Color(0xFF4A2A63), fontSize: 14, fontWeight: FontWeight.w900))]),
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
      padding: EdgeInsets.fromLTRB(14, 12, 14, 16 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 24, offset: const Offset(0, 8))]),
      child: child,
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: const Color(0xFFE0D5CB), borderRadius: BorderRadius.circular(99))));
  }
}

class _ReadyInfoRow extends StatelessWidget {
  const _ReadyInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 12, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text(value, style: const TextStyle(color: Color(0xFF251538), fontSize: 12.5, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
