import 'package:flutter/material.dart';

import '../../data/device_audio_library_service.dart';
import '../../data/room_music_controller.dart';
import '../widgets/room_theme.dart';

class RoomMusicLibrarySheet extends StatefulWidget {
  const RoomMusicLibrarySheet({
    super.key,
    required this.controller,
  });

  final RoomMusicController controller;

  static Future<void> open(
    BuildContext context, {
    required RoomMusicController controller,
  }) {
    return Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => RoomMusicLibrarySheet(controller: controller),
      ),
    );
  }

  @override
  State<RoomMusicLibrarySheet> createState() => _RoomMusicLibrarySheetState();
}

class _RoomMusicLibrarySheetState extends State<RoomMusicLibrarySheet>
    with SingleTickerProviderStateMixin {
  final DeviceAudioLibraryService _libraryService = DeviceAudioLibraryService();
  final TextEditingController _searchController = TextEditingController();

  late final TabController _tabController;

  List<RoomMusicTrack> _songs = <RoomMusicTrack>[];
  final Set<String> _selectedIds = <String>{};
  final Set<String> _selectedAddedIds = <String>{};
  bool _isEditingAddedSongs = false;
  bool _loading = true;
  String _query = '';

  List<RoomMusicTrack> get _addedSongs =>
      widget.controller.state.value.playlist;

  Set<String> get _addedIds =>
      _addedSongs.map((track) => track.id).toSet();

  List<RoomMusicTrack> get _newSongs {
    final availableSongs = _songs
        .where((song) => !_addedIds.contains(song.id))
        .toList(growable: false);

    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return availableSongs;

    return availableSongs.where((song) {
      return song.title.toLowerCase().contains(q) ||
          song.artist.toLowerCase().contains(q);
    }).toList(growable: false);
  }

  List<RoomMusicTrack> get _filteredAddedSongs {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _addedSongs;

    return _addedSongs.where((song) {
      return song.title.toLowerCase().contains(q) ||
          song.artist.toLowerCase().contains(q);
    }).toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSongs();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  void _toggleSelectAllAddedSongs() {
    final visible = _filteredAddedSongs;
    final allSelected =
        visible.isNotEmpty &&
        visible.every((song) => _selectedAddedIds.contains(song.id));

    setState(() {
      if (allSelected) {
        for (final song in visible) {
          _selectedAddedIds.remove(song.id);
        }
      } else {
        _selectedAddedIds.addAll(visible.map((song) => song.id));
      }
    });
  }

  Future<void> _deleteSelectedAddedSongs() async {
    final ids = _selectedAddedIds.toList(growable: false);
    for (final id in ids) {
      await widget.controller.removeTrack(id);
    }

    if (!mounted) return;
    setState(() {
      _selectedAddedIds.clear();
      if (_addedSongs.isEmpty) {
        _isEditingAddedSongs = false;
      }
    });
  }

  void _toggleSelectAllNewSongs() {
    final visible = _newSongs;
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
        .where((song) => !_addedIds.contains(song.id))
        .toList(growable: false);

    await widget.controller.addTracks(selected);

    if (!mounted) return;
    setState(() {
      _selectedIds.clear();
      _tabController.animateTo(0);
    });
  }

  Future<void> _removeAddedSong(RoomMusicTrack song) async {
    await widget.controller.removeTrack(song.id);
    if (!mounted) return;
    setState(() {
      _selectedIds.remove(song.id);
      _selectedAddedIds.remove(song.id);
    });
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
    final newSongs = _newSongs;
    final addedSongs = _filteredAddedSongs;

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
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                    const Expanded(
                      child: Text(
                        'Room Music',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _tabController,
                      builder: (context, _) {
                        final isNewSongsTab = _tabController.index == 1;
                        if (!isNewSongsTab) {
                          if (_isEditingAddedSongs) {
                            if (_selectedAddedIds.isNotEmpty) {
                              return TextButton.icon(
                                onPressed: _deleteSelectedAddedSongs,
                                icon: const Icon(Icons.delete_rounded, size: 18),
                                label: Text('Delete ${_selectedAddedIds.length}'),
                              );
                            }

                            return TextButton(
                              onPressed: () {
                                setState(() {
                                  _isEditingAddedSongs = false;
                                  _selectedAddedIds.clear();
                                });
                              },
                              child: const Text('Done'),
                            );
                          }

                          return TextButton(
                            onPressed: _addedSongs.isEmpty
                                ? null
                                : () {
                                    setState(() {
                                      _isEditingAddedSongs = true;
                                      _selectedAddedIds.clear();
                                    });
                                  },
                            child: const Text('Edit'),
                          );
                        }

                        return TextButton(
                          onPressed: newSongs.isEmpty ? null : _toggleSelectAllNewSongs,
                          child: const Text('Select all'),
                        );
                      },
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
                    hintText: 'Search songs',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Colors.white70,
                    ),
                    suffixIcon: _query.trim().isEmpty
                        ? null
                        : IconButton(
                            onPressed: _searchController.clear,
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white60,
                            ),
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
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        colors: [
                          RoomColors.aqua.withValues(alpha: 0.95),
                          RoomColors.violet.withValues(alpha: 0.88),
                        ],
                      ),
                    ),
                    labelColor: const Color(0xFF061015),
                    unselectedLabelColor: Colors.white70,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                    tabs: [
                      Tab(text: 'Added (${_addedSongs.length})'),
                      Tab(text: 'New (${newSongs.length})'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildAddedSongsList(addedSongs),
                          _buildNewSongsList(newSongs),
                        ],
                      ),
              ),
              AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) {
                  if (_tabController.index != 1) {
                    return const SizedBox.shrink();
                  }

                  return Container(
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
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddedSongsList(List<RoomMusicTrack> songs) {
    if (_addedSongs.isEmpty) {
      return _EmptyMusicState(
        icon: Icons.library_music_rounded,
        title: 'No songs added yet',
        subtitle: 'Open New Songs and add audio files to your room playlist.',
        actionLabel: 'Browse New Songs',
        onAction: () => _tabController.animateTo(1),
      );
    }

    if (songs.isEmpty) {
      return const _EmptyMusicState(
        icon: Icons.search_off_rounded,
        title: 'No added songs match',
        subtitle: 'Try another song name or clear the search.',
      );
    }

    return ValueListenableBuilder<RoomMusicState>(
      valueListenable: widget.controller.state,
      builder: (context, state, _) {
        return Column(
          children: [
            if (_isEditingAddedSongs)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: _toggleSelectAllAddedSongs,
                      icon: const Icon(Icons.checklist_rounded, size: 18),
                      label: const Text('Select all'),
                    ),
                    const Spacer(),
                    Text(
                      '${_selectedAddedIds.length} selected',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 18),
                itemCount: songs.length,
                itemBuilder: (context, index) {
            final song = songs[index];
            final playlistIndex = state.playlist.indexWhere(
              (track) => track.id == song.id,
            );
            final active = state.currentTrack?.id == song.id;

            final selectedForDelete = _selectedAddedIds.contains(song.id);

            return _MusicSongTile(
              song: song,
              selected: active || selectedForDelete,
              leading: _isEditingAddedSongs
                  ? Checkbox(
                      value: selectedForDelete,
                      onChanged: (_) {
                        setState(() {
                          selectedForDelete
                              ? _selectedAddedIds.remove(song.id)
                              : _selectedAddedIds.add(song.id);
                        });
                      },
                    )
                  : Icon(
                      active
                          ? state.isPlaying
                              ? Icons.equalizer_rounded
                              : Icons.pause_circle_outline_rounded
                          : Icons.music_note_rounded,
                      color: active ? RoomColors.aqua : Colors.white70,
                    ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (active)
                    Icon(
                      state.isPlaying
                          ? Icons.equalizer_rounded
                          : Icons.pause_circle_outline_rounded,
                      color: RoomColors.aqua,
                      size: 18,
                    )
                  else
                    const Icon(
                      Icons.music_note_rounded,
                      color: Colors.white54,
                      size: 18,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    _durationLabel(song.durationMs),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.60),
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                  if (_isEditingAddedSongs) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Remove',
                      onPressed: () => _removeAddedSong(song),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white60,
                        size: 18,
                      ),
                    ),
                  ],
                ],
              ),
              onTap: () {
                if (_isEditingAddedSongs) {
                  setState(() {
                    selectedForDelete
                        ? _selectedAddedIds.remove(song.id)
                        : _selectedAddedIds.add(song.id);
                  });
                  return;
                }

                if (playlistIndex >= 0) {
                  widget.controller.playIndex(playlistIndex);
                }
              },
            );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNewSongsList(List<RoomMusicTrack> songs) {
    if (_songs.isEmpty) {
      return const _EmptyMusicState(
        icon: Icons.folder_off_rounded,
        title: 'No audio files found',
        subtitle: 'We could not find audio files on this device.',
      );
    }

    if (songs.isEmpty) {
      return _EmptyMusicState(
        icon: Icons.check_circle_rounded,
        title: 'No new songs left',
        subtitle: _query.trim().isEmpty
            ? 'All discovered songs are already added.'
            : 'No new songs match your search.',
        actionLabel: _query.trim().isEmpty ? null : 'Clear Search',
        onAction: _query.trim().isEmpty ? null : _searchController.clear,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 18),
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        final selected = _selectedIds.contains(song.id);

        return _MusicSongTile(
          song: song,
          selected: selected,
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
          trailing: Text(
            _durationLabel(song.durationMs),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          onTap: () {
            setState(() {
              selected
                  ? _selectedIds.remove(song.id)
                  : _selectedIds.add(song.id);
            });
          },
        );
      },
    );
  }
}

class _MusicSongTile extends StatelessWidget {
  const _MusicSongTile({
    required this.song,
    required this.selected,
    required this.leading,
    required this.trailing,
    required this.onTap,
  });

  final RoomMusicTrack song;
  final bool selected;
  final Widget leading;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
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
        dense: true,
        onTap: onTap,
        leading: leading,
        title: Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
        subtitle: Text(
          song.artist.trim().isEmpty ? 'Device audio' : song.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.58),
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
        trailing: trailing,
      ),
    );
  }
}

class _EmptyMusicState extends StatelessWidget {
  const _EmptyMusicState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: RoomColors.aqua.withValues(alpha: 0.80),
              size: 46,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
