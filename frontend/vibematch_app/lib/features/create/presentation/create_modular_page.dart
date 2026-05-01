import 'package:flutter/material.dart';

import '../../rooms/presentation/live_room_page.dart';
import '../controllers/create_room_controller.dart';
import 'sheets/create_language_sheet.dart';
import 'sheets/create_room_ready_sheet.dart';
import 'widgets/create_header.dart';
import 'widgets/create_mode_section.dart';
import 'widgets/create_room_form_card.dart';
import 'widgets/create_rules_card.dart';
import 'widgets/create_ui_helpers.dart';

class CreateModularPage extends StatefulWidget {
  const CreateModularPage({super.key});

  @override
  State<CreateModularPage> createState() => _CreateModularPageState();
}

class _CreateModularPageState extends State<CreateModularPage> {
  late final TextEditingController _roomNameController;
  late final CreateRoomController _controller;

  @override
  void initState() {
    super.initState();
    _roomNameController = TextEditingController(text: 'Late Night Chill');
    _controller = CreateRoomController()..addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    _roomNameController.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) setState(() {});
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

  void _openLanguageSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateLanguageSheet(
        languages: CreateRoomController.languages,
        selectedLanguage: _controller.selectedLanguage,
        onLanguageSelected: _controller.selectLanguage,
      ),
    );
  }

  void _createRoom() {
    final roomName = _roomNameController.text.trim();
    if (roomName.isEmpty) {
      _toast('Enter a room name');
      return;
    }

    final roomId = _controller.generateRoomId();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CreateRoomReadySheet(
        roomName: roomName,
        roomId: roomId,
        selectedMode: _controller.selectedMode,
        selectedLanguage: _controller.selectedLanguage,
        onEditTap: () => Navigator.pop(context),
        onEnterTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LiveRoomPage(
                roomName: roomName,
                roomId: roomId,
                language: _controller.selectedLanguage,
                modeTitle: _controller.selectedMode.title,
                onlineCount: 1,
              ),
            ),
          );
        },
      ),
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
            SliverToBoxAdapter(
              child: CreateHeader(
                onHelpTap: () => _toast('Create room help opened'),
              ),
            ),
            SliverToBoxAdapter(
              child: CreateRoomFormCard(
                roomNameController: _roomNameController,
                selectedLanguage: _controller.selectedLanguage,
                roomImageSelected: _controller.roomImageSelected,
                onToggleImage: () {
                  final selected = _controller.toggleRoomImage();
                  _toast(selected ? 'Mock room image selected' : 'Room image removed');
                },
                onLanguageTap: _openLanguageSheet,
              ),
            ),
            SliverToBoxAdapter(
              child: CreateModeSection(
                selectedMode: _controller.selectedMode,
                onModeSelected: _controller.selectMode,
              ),
            ),
            const SliverToBoxAdapter(child: CreateRulesCard()),
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
          child: CreatePrimaryButton(
            text: 'Create Room',
            icon: Icons.add_circle_rounded,
            onTap: _createRoom,
          ),
        ),
      ),
    );
  }
}
