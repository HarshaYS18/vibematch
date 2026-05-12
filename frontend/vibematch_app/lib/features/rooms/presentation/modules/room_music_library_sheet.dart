import 'package:flutter/material.dart';

import '../../data/device_audio_library_service.dart';
import '../../data/room_music_controller.dart';
import '../widgets/room_theme.dart';

class RoomMusicLibrarySheet extends StatefulWidget {
  const RoomMusicLibrarySheet({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const RoomMusicLibrarySheet(),
      ),
    );
  }

  @override
  State<RoomMusicLibrarySheet> createState() => _RoomMusicLibrarySheetState();
}

class _RoomMusicLibrarySheetState extends State<RoomMusicLibrarySheet> {
  final DeviceAudioLibraryService _libraryService = DeviceAudioLibraryService();
  final TextEditingController _searchController = TextEditingController();

  List<RoomMusicTrack> _songs = <RoomMusicTrack>[];
  final Set<String> _selectedIds = <String>{};
  bool _loading = true;
  String _query = '';

  List<RoomMusicTrack> get _filteredSongs {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _songs;
    return _songs.where((song) {
      return song.title.toLowerCase().contains(q) ||
          song.artist.toLowerCase().contains(q);
    }).toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _loadSongs();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSongs() async {
    final songs = await _libraryService.scanSongs();
    if (!mounted) return;
    setState(() {
      _songs = songs;
      _loading = false;
    });
  }

  void _toggleSelectAll() {
    final visible = _filteredSongs;
    final allSelected =
        visible.isNotEmpty &&
        visible.every((song) => _selectedIds.contains(song.id));

    setState(() {
      if (allSelected) {
        for (final song in visible) {
          _selectedIds.remove(song.id);
        }
      } else {
        _selectedIds.addAll(visible.map((song) => song.id));
      }
    });
  }

  Future<void> _addSelected() async {
    final selected = _songs
        .where((song) => _selectedIds.contains(song.id))
        .toList(growable: false);

    await RoomMusicController.instance.addTracks(selected);

    if (!mounted) return;
    Navigator.pop(context);
  }

  String _durationLabel(int durationMs) {
    if (durationMs <= 0) return '--:--';
    final duration = Duration(milliseconds: durationMs);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final visible = _filteredSongs;

    return Scaffold(
      backgroundColor: RoomColors.deep,
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF100824), Color(0xFF081820), Color(0xFF24103B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                    const Expanded(
                      child: Text(
                        'Add Room Music',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _toggleSelectAll,
                      child: const Text('Select all'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search audio files',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Colors.white70,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : visible.isEmpty
                    ? Center(
                        child: Text(
                          'No audio files found',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final song = visible[index];
                          final selected = _selectedIds.contains(song.id);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? RoomColors.aqua.withValues(alpha: 0.16)
                                  : Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: selected
                                    ? RoomColors.aqua.withValues(alpha: 0.48)
                                    : Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: ListTile(
                              onTap: () {
                                setState(() {
                                  selected
                                      ? _selectedIds.remove(song.id)
                                      : _selectedIds.add(song.id);
                                });
                              },
                              leading: Checkbox(
                                value: selected,
                                onChanged: (_) {
                                  setState(() {
                                    selected
                                        ? _selectedIds.remove(song.id)
                                        : _selectedIds.add(song.id);
                                  });
                                },
                              ),
                              title: Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              subtitle: Text(
                                song.artist.trim().isEmpty
                                    ? 'Device audio'
                                    : song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.58),
                                ),
                              ),
                              trailing: Text(
                                _durationLabel(song.durationMs),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.72),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF090D16).withValues(alpha: 0.92),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _selectedIds.isEmpty ? null : _addSelected,
                    icon: const Icon(Icons.playlist_add_rounded),
                    label: Text('Add ${_selectedIds.length} songs'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
