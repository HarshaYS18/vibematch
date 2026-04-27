import 'package:flutter/material.dart';

class VibesPage extends StatefulWidget {
  const VibesPage({super.key});

  @override
  State<VibesPage> createState() => _VibesPageState();
}

class _VibesPageState extends State<VibesPage> {
  String _selectedFilter = 'All';

  final List<String> _filters = const [
    'All',
    'Following',
    'Photos',
    'Videos',
    'Mentions',
    'Trending',
  ];

  final List<_VibeItem> _vibes = [
    _VibeItem(
      authorName: 'Founder',
      authorId: '6922022',
      avatarText: 'F',
      timeAgo: '2m ago',
      mediaType: _VibeMediaType.photo,
      caption:
          'Building the new Vibe Match Vibes page. Photos, videos, comments and mentions are coming together. @all',
      tag: 'Update',
      likes: 1280,
      comments: 86,
      shares: 19,
      views: 12500,
      isFollowing: true,
      usesMentionAll: true,
      mentions: const [],
      colors: const [
        Color(0xFF6D5DF6),
        Color(0xFFE84C72),
      ],
    ),
    _VibeItem(
      authorName: 'Akhil',
      authorId: '6418001293',
      avatarText: 'A',
      timeAgo: '18m ago',
      mediaType: _VibeMediaType.video,
      caption:
          'Late Night Chill room was crazy today 🔥 thanks @riya and @founder for joining.',
      tag: 'Room',
      likes: 846,
      comments: 42,
      shares: 11,
      views: 8200,
      isFollowing: true,
      usesMentionAll: false,
      mentions: const ['Riya', 'Founder'],
      colors: const [
        Color(0xFF12C7B7),
        Color(0xFF6D5DF6),
      ],
    ),
    _VibeItem(
      authorName: 'Meera',
      authorId: '6418004771',
      avatarText: 'M',
      timeAgo: '1h ago',
      mediaType: _VibeMediaType.text,
      caption:
          'A clean profile should show identity clearly: bio, age, gender, interests, VIP/SVIP, CP, Vibes and presence.',
      tag: 'Design',
      likes: 2400,
      comments: 171,
      shares: 44,
      views: 24000,
      isFollowing: false,
      usesMentionAll: false,
      mentions: const [],
      colors: const [
        Color(0xFFC99A3B),
        Color(0xFFE84C72),
      ],
    ),
  ];

  List<_VibeItem> get _visibleVibes {
    if (_selectedFilter == 'Following') {
      return _vibes.where((vibe) => vibe.isFollowing).toList();
    }

    if (_selectedFilter == 'Photos') {
      return _vibes
          .where((vibe) => vibe.mediaType == _VibeMediaType.photo)
          .toList();
    }

    if (_selectedFilter == 'Videos') {
      return _vibes
          .where((vibe) => vibe.mediaType == _VibeMediaType.video)
          .toList();
    }

    if (_selectedFilter == 'Mentions') {
      return _vibes
          .where((vibe) => vibe.usesMentionAll || vibe.mentions.isNotEmpty)
          .toList();
    }

    if (_selectedFilter == 'Trending') {
      final sorted = [..._vibes];
      sorted.sort((a, b) => b.views.compareTo(a.views));
      return sorted;
    }

    return _vibes;
  }

  void _showAction(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF251538),
        ),
      );
  }

  void _openCreateVibe() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateVibePage(
          onPublish: (newVibe) {
            setState(() {
              _vibes.insert(0, newVibe);
              _selectedFilter = 'All';
            });

            _showAction(
              'Vibe published locally. Backend API will connect later.',
            );
          },
        ),
      ),
    );
  }

  void _openComments(_VibeItem vibe) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VibeCommentsPage(vibe: vibe),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleVibes = _visibleVibes;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Vibes',
                        style: TextStyle(
                          color: Color(0xFF251538),
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.7,
                        ),
                      ),
                    ),
                    _RoundIconButton(
                      icon: Icons.add_rounded,
                      onTap: _openCreateVibe,
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 44,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 9),
                  itemBuilder: (context, index) {
                    final filter = _filters[index];
                    final selected = filter == _selectedFilter;

                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      },
                      borderRadius: BorderRadius.circular(99),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFF251538)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF251538)
                                : const Color(0xFFECE2D8),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF251538).withValues(
                                alpha: selected ? 0.10 : 0.04,
                              ),
                              blurRadius: 14,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            filter,
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF7A6B86),
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (visibleVibes.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyVibesState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 116),
                sliver: SliverList.separated(
                  itemCount: visibleVibes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final vibe = visibleVibes[index];

                    return _VibeCard(
                      vibe: vibe,
                      onProfileTap: () => _showAction(
                        '${vibe.authorName} profile will open.',
                      ),
                      onLikeTap: () {
                        setState(() {
                          final realIndex = _vibes.indexOf(vibe);
                          if (realIndex != -1) {
                            _vibes[realIndex] = vibe.copyWith(
                              likes: vibe.likes + 1,
                            );
                          }
                        });
                      },
                      onCommentTap: () => _openComments(vibe),
                      onShareTap: () => _showAction('Share Vibe will open.'),
                      onMoreTap: () => _showAction('Vibe options will open.'),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateVibe,
        backgroundColor: const Color(0xFF251538),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.auto_awesome_rounded),
        label: const Text(
          'Create Vibe',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class CreateVibePage extends StatefulWidget {
  const CreateVibePage({
    super.key,
    required this.onPublish,
  });

  final ValueChanged<_VibeItem> onPublish;

  @override
  State<CreateVibePage> createState() => _CreateVibePageState();
}

class _CreateVibePageState extends State<CreateVibePage> {
  final TextEditingController _captionController = TextEditingController();

  _VibeMediaType _selectedType = _VibeMediaType.photo;
  bool _commentsEnabled = true;
  bool _usesMentionAll = false;
  final List<String> _mentions = [];

  @override
  void initState() {
    super.initState();
    _captionController.addListener(_handleCaptionChanged);
  }

  @override
  void dispose() {
    _captionController.removeListener(_handleCaptionChanged);
    _captionController.dispose();
    super.dispose();
  }

  void _handleCaptionChanged() {
    final text = _captionController.text;

    final mentionRegex = RegExp(r'(^|\s)@(?!all\b)([a-zA-Z0-9_]{2,24})');
    final extracted = mentionRegex
        .allMatches(text)
        .map((match) => match.group(2))
        .whereType<String>()
        .map((name) {
          if (name.isEmpty) return name;
          return '${name[0].toUpperCase()}${name.substring(1)}';
        })
        .toSet()
        .toList();

    final hasAll = RegExp(r'(^|\s)@all\b', caseSensitive: false).hasMatch(text);

    setState(() {
      _mentions
        ..clear()
        ..addAll(extracted);
      _usesMentionAll = hasAll;
    });
  }

  void _showAction(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF251538),
        ),
      );
  }

  void _insertMention(String mention) {
    final text = _captionController.text;
    final selection = _captionController.selection;
    final cursor = selection.baseOffset < 0 ? text.length : selection.baseOffset;

    final before = text.substring(0, cursor);
    final after = text.substring(cursor);
    final insert = '@$mention ';

    _captionController.value = TextEditingValue(
      text: '$before$insert$after',
      selection: TextSelection.collapsed(offset: before.length + insert.length),
    );
  }

  void _publish() {
    final caption = _captionController.text.trim();

    if (caption.isEmpty) {
      _showAction('Write a caption before publishing.');
      return;
    }

    final newVibe = _VibeItem(
      authorName: 'Founder',
      authorId: '6922022',
      avatarText: 'F',
      timeAgo: 'Just now',
      mediaType: _selectedType,
      caption: caption,
      tag: _selectedType.label,
      likes: 0,
      comments: 0,
      shares: 0,
      views: 1,
      isFollowing: true,
      usesMentionAll: _usesMentionAll,
      mentions: List<String>.from(_mentions),
      colors: _selectedType.colors,
    );

    widget.onPublish(newVibe);

    if (_usesMentionAll) {
      _showAction(
        'All followers will be notified after backend is connected.',
      );
    } else if (_mentions.isNotEmpty) {
      _showAction(
        'Mention notifications will be sent after backend is connected.',
      );
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final captionNotEmpty = _captionController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
          children: [
            Row(
              children: [
                _RoundIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Create Vibe',
                    style: TextStyle(
                      color: Color(0xFF251538),
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                InkWell(
                  onTap: captionNotEmpty ? _publish : null,
                  borderRadius: BorderRadius.circular(18),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: captionNotEmpty
                          ? const Color(0xFF251538)
                          : const Color(0xFFE2D9CF),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      'Publish',
                      style: TextStyle(
                        color: captionNotEmpty
                            ? Colors.white
                            : const Color(0xFF8C8198),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _CreateTypePicker(
              selectedType: _selectedType,
              onSelected: (type) {
                setState(() {
                  _selectedType = type;
                });
              },
            ),
            const SizedBox(height: 16),
            _CreateMediaBox(
              type: _selectedType,
              onTap: () => _showAction(
                '${_selectedType.label} picker will open when media upload is connected.',
              ),
            ),
            const SizedBox(height: 16),
            _CaptionComposer(
              controller: _captionController,
              commentsEnabled: _commentsEnabled,
              onToggleComments: () {
                setState(() {
                  _commentsEnabled = !_commentsEnabled;
                });
              },
              onInsertMention: _insertMention,
            ),
            const SizedBox(height: 14),
            _MentionPreview(
              usesMentionAll: _usesMentionAll,
              mentions: _mentions,
              commentsEnabled: _commentsEnabled,
            ),
            const SizedBox(height: 18),
            _PublishWideButton(
              enabled: captionNotEmpty,
              onTap: _publish,
            ),
          ],
        ),
      ),
    );
  }
}

class VibeCommentsPage extends StatefulWidget {
  const VibeCommentsPage({
    super.key,
    required this.vibe,
  });

  final _VibeItem vibe;

  @override
  State<VibeCommentsPage> createState() => _VibeCommentsPageState();
}

class _VibeCommentsPageState extends State<VibeCommentsPage> {
  final TextEditingController _commentController = TextEditingController();

  final List<_VibeComment> _comments = const [
    _VibeComment(
      name: 'Riya',
      avatarText: 'R',
      text: 'This looks premium 🔥 @founder',
      time: '2m ago',
    ),
    _VibeComment(
      name: 'Akhil',
      avatarText: 'A',
      text: 'Need this in live rooms too!',
      time: '5m ago',
    ),
  ].toList();

  void _sendComment() {
    final text = _commentController.text.trim();

    if (text.isEmpty) return;

    setState(() {
      _comments.insert(
        0,
        _VibeComment(
          name: 'Founder',
          avatarText: 'F',
          text: text,
          time: 'Just now',
        ),
      );
      _commentController.clear();
    });

    final hasAll = RegExp(r'(^|\s)@all\b', caseSensitive: false).hasMatch(text);
    final mentions = RegExp(r'(^|\s)@(?!all\b)([a-zA-Z0-9_]{2,24})')
        .allMatches(text)
        .map((match) => match.group(2))
        .whereType<String>()
        .toList();

    if (hasAll) {
      _showAction('All followers will be notified later.');
    } else if (mentions.isNotEmpty) {
      _showAction(
        'Mention notification will be sent to ${mentions.join(', ')} later.',
      );
    }
  }

  void _showAction(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF251538),
        ),
      );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFECE2D8)),
                ),
              ),
              child: Row(
                children: [
                  _RoundIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Comments',
                      style: TextStyle(
                        color: Color(0xFF251538),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                itemCount: _comments.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final comment = _comments[index];

                  return _CommentCard(comment: comment);
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFECE2D8))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Comment with @name or @all...',
                        hintStyle: const TextStyle(
                          color: Color(0xFF8C8198),
                          fontWeight: FontWeight.w600,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFFAF7F1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(
                            color: Color(0xFFECE2D8),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(
                            color: Color(0xFFECE2D8),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(
                            color: Color(0xFF12C7B7),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: _sendComment,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF251538),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VibeCard extends StatelessWidget {
  const _VibeCard({
    required this.vibe,
    required this.onProfileTap,
    required this.onLikeTap,
    required this.onCommentTap,
    required this.onShareTap,
    required this.onMoreTap,
  });

  final _VibeItem vibe;
  final VoidCallback onProfileTap;
  final VoidCallback onLikeTap;
  final VoidCallback onCommentTap;
  final VoidCallback onShareTap;
  final VoidCallback onMoreTap;

  bool get _hasMentions {
    return vibe.usesMentionAll || vibe.mentions.isNotEmpty;
  }

  String get _mentionDisplayText {
    final names = <String>[];

    names.addAll(vibe.mentions);

    if (vibe.usesMentionAll &&
        !names.any((name) => name.toLowerCase() == 'all')) {
      names.add('all');
    }

    return names.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final isTextOnly = vibe.mediaType == _VibeMediaType.text;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onCommentTap,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: _panelDecoration(radius: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: onProfileTap,
                    customBorder: const CircleBorder(),
                    child: _AvatarBubble(
                      text: vibe.avatarText,
                      colors: vibe.colors,
                      size: 48,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: InkWell(
                      onTap: onProfileTap,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vibe.authorName,
                            style: const TextStyle(
                              color: Color(0xFF251538),
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ID ${vibe.authorId} • ${vibe.timeAgo}',
                            style: const TextStyle(
                              color: Color(0xFF8C8198),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _VibeTag(label: vibe.tag, color: vibe.colors.first),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: onMoreTap,
                    borderRadius: BorderRadius.circular(99),
                    child: const Padding(
                      padding: EdgeInsets.all(5),
                      child: Icon(
                        Icons.more_horiz_rounded,
                        color: Color(0xFF8C8198),
                      ),
                    ),
                  ),
                ],
              ),
              if (!isTextOnly) ...[
                const SizedBox(height: 13),
                _VibeMediaPreview(vibe: vibe),
                const SizedBox(height: 13),
              ] else
                const SizedBox(height: 12),
              Text(
                vibe.caption,
                style: TextStyle(
                  color: const Color(0xFF5E526B),
                  fontSize: isTextOnly ? 14 : 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 11),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    icon: Icons.remove_red_eye_rounded,
                    label: _formatCount(vibe.views),
                    color: const Color(0xFF6D5DF6),
                  ),
                  if (_hasMentions)
                    _InfoChip(
                      icon: Icons.alternate_email_rounded,
                      label: _mentionDisplayText,
                      color: vibe.usesMentionAll
                          ? const Color(0xFFC99A3B)
                          : const Color(0xFF6D5DF6),
                    ),
                ],
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  _ActionPill(
                    icon: Icons.favorite_rounded,
                    label: _formatCount(vibe.likes),
                    color: const Color(0xFFE84C72),
                    onTap: onLikeTap,
                  ),
                  const SizedBox(width: 9),
                  _ActionPill(
                    icon: Icons.chat_bubble_rounded,
                    label: _formatCount(vibe.comments),
                    color: const Color(0xFF6D5DF6),
                    onTap: onCommentTap,
                  ),
                  const Spacer(),
                  _ActionPill(
                    icon: Icons.ios_share_rounded,
                    label: _formatCount(vibe.shares),
                    color: const Color(0xFF12C7B7),
                    onTap: onShareTap,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VibeMediaPreview extends StatelessWidget {
  const _VibeMediaPreview({
    required this.vibe,
  });

  final _VibeItem vibe;

  @override
  Widget build(BuildContext context) {
    final isVideo = vibe.mediaType == _VibeMediaType.video;

    return Container(
      height: 190,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: vibe.colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: vibe.colors.first.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -34,
            top: -38,
            child: Container(
              height: 130,
              width: 130,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -40,
            bottom: -44,
            child: Container(
              height: 130,
              width: 130,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Center(
            child: Container(
              height: 62,
              width: 62,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
                ),
              ),
              child: Icon(
                isVideo ? Icons.play_arrow_rounded : Icons.photo_rounded,
                color: Colors.white,
                size: isVideo ? 42 : 32,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateTypePicker extends StatelessWidget {
  const _CreateTypePicker({
    required this.selectedType,
    required this.onSelected,
  });

  final _VibeMediaType selectedType;
  final ValueChanged<_VibeMediaType> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = [
      _VibeMediaType.photo,
      _VibeMediaType.video,
      _VibeMediaType.text,
    ];

    return Row(
      children: items.map((type) {
        final selected = type == selectedType;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: type == items.last ? 0 : 9,
            ),
            child: InkWell(
              onTap: () => onSelected(type),
              borderRadius: BorderRadius.circular(22),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: selected
                      ? LinearGradient(
                          colors: type.colors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: selected ? null : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: selected
                        ? Colors.transparent
                        : const Color(0xFFECE2D8),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: type.colors.first.withValues(
                        alpha: selected ? 0.18 : 0.04,
                      ),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      type.icon,
                      color: selected ? Colors.white : type.colors.first,
                      size: 24,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      type.label,
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : const Color(0xFF251538),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CreateMediaBox extends StatelessWidget {
  const _CreateMediaBox({
    required this.type,
    required this.onTap,
  });

  final _VibeMediaType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isText = type == _VibeMediaType.text;

    return InkWell(
      onTap: isText ? null : onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: isText ? 104 : 178,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              type.colors.first.withValues(alpha: 0.12),
              type.colors.last.withValues(alpha: 0.13),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFECE2D8)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isText
                    ? Icons.edit_note_rounded
                    : type == _VibeMediaType.photo
                        ? Icons.add_photo_alternate_rounded
                        : Icons.video_library_rounded,
                color: type.colors.first,
                size: 42,
              ),
              const SizedBox(height: 10),
              Text(
                isText ? 'Text-only selected' : 'Tap to add ${type.label}',
                style: const TextStyle(
                  color: Color(0xFF251538),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isText
                    ? 'Caption will be posted without media'
                    : 'Local placeholder now • upload API later',
                style: const TextStyle(
                  color: Color(0xFF7A6B86),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptionComposer extends StatelessWidget {
  const _CaptionComposer({
    required this.controller,
    required this.commentsEnabled,
    required this.onToggleComments,
    required this.onInsertMention,
  });

  final TextEditingController controller;
  final bool commentsEnabled;
  final VoidCallback onToggleComments;
  final ValueChanged<String> onInsertMention;

  @override
  Widget build(BuildContext context) {
    final suggestions = ['all', 'riya', 'akhil', 'meera', 'kiran'];

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: _panelDecoration(radius: 28),
      child: Column(
        children: [
          Row(
            children: [
              const _AvatarBubble(
                text: 'F',
                colors: [
                  Color(0xFFFFD36A),
                  Color(0xFFE84C72),
                ],
                size: 46,
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Text(
                  'Caption',
                  style: TextStyle(
                    color: Color(0xFF251538),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              InkWell(
                onTap: onToggleComments,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: commentsEnabled
                        ? const Color(0xFF12C7B7).withValues(alpha: 0.11)
                        : const Color(0xFFE84C72).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    commentsEnabled ? 'Comments ON' : 'Comments OFF',
                    style: TextStyle(
                      color: commentsEnabled
                          ? const Color(0xFF05796D)
                          : const Color(0xFFE84C72),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          TextField(
            controller: controller,
            minLines: 5,
            maxLines: 8,
            style: const TextStyle(
              color: Color(0xFF251538),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
            decoration: InputDecoration(
              hintText:
                  'Write a caption... use @name to mention someone or @all to notify your followers.',
              hintStyle: const TextStyle(
                color: Color(0xFF9B90A5),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              filled: true,
              fillColor: const Color(0xFFFAF7F1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: const BorderSide(color: Color(0xFFECE2D8)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: const BorderSide(color: Color(0xFFECE2D8)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: const BorderSide(
                  color: Color(0xFF12C7B7),
                  width: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: suggestions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final mention = suggestions[index];

                return InkWell(
                  onTap: () => onInsertMention(mention),
                  borderRadius: BorderRadius.circular(99),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: mention == 'all'
                          ? const Color(0xFFFFD36A)
                          : const Color(0xFF251538),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Center(
                      child: Text(
                        '@$mention',
                        style: TextStyle(
                          color: mention == 'all'
                              ? const Color(0xFF251538)
                              : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MentionPreview extends StatelessWidget {
  const _MentionPreview({
    required this.usesMentionAll,
    required this.mentions,
    required this.commentsEnabled,
  });

  final bool usesMentionAll;
  final List<String> mentions;
  final bool commentsEnabled;

  @override
  Widget build(BuildContext context) {
    final names = <String>[
      ...mentions,
      if (usesMentionAll) 'all',
    ];

    final hasMentions = names.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(radius: 26),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: hasMentions
                  ? const Color(0xFF6D5DF6).withValues(alpha: 0.13)
                  : const Color(0xFF8C8198).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(
              hasMentions
                  ? Icons.alternate_email_rounded
                  : Icons.notifications_none_rounded,
              color: hasMentions
                  ? const Color(0xFF6D5DF6)
                  : const Color(0xFF8C8198),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hasMentions
                  ? names.join(', ')
                  : commentsEnabled
                      ? 'No mentions yet'
                      : 'Comments are disabled for this Vibe',
              style: const TextStyle(
                color: Color(0xFF251538),
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PublishWideButton extends StatelessWidget {
  const _PublishWideButton({
    required this.enabled,
    required this.onTap,
  });

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 56,
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  colors: [
                    Color(0xFF251538),
                    Color(0xFF6D5DF6),
                    Color(0xFFE84C72),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: enabled ? null : const Color(0xFFE2D9CF),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            if (enabled)
              BoxShadow(
                color: const Color(0xFF6D5DF6).withValues(alpha: 0.22),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
          ],
        ),
        child: Center(
          child: Text(
            enabled ? 'Publish Vibe' : 'Write caption to publish',
            style: TextStyle(
              color: enabled ? Colors.white : const Color(0xFF8C8198),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({
    required this.comment,
  });

  final _VibeComment comment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: _panelDecoration(radius: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AvatarBubble(
            text: comment.avatarText,
            colors: const [
              Color(0xFF6D5DF6),
              Color(0xFFE84C72),
            ],
            size: 40,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.name,
                  style: const TextStyle(
                    color: Color(0xFF251538),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  comment.text,
                  style: const TextStyle(
                    color: Color(0xFF5E526B),
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  comment.time,
                  style: const TextStyle(
                    color: Color(0xFF8C8198),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarBubble extends StatelessWidget {
  const _AvatarBubble({
    required this.text,
    required this.colors,
    required this.size,
  });

  final String text;
  final List<Color> colors;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      padding: const EdgeInsets.all(2.4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: colors.first,
              fontSize: size * 0.38,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFECE2D8)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF251538).withValues(alpha: 0.045),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: const Color(0xFF251538),
            size: 21,
          ),
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF251538),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF251538),
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _VibeTag extends StatelessWidget {
  const _VibeTag({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF251538),
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmptyVibesState extends StatelessWidget {
  const _EmptyVibesState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(22),
        padding: const EdgeInsets.all(20),
        decoration: _panelDecoration(radius: 28),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFF8C8198),
              size: 44,
            ),
            SizedBox(height: 12),
            Text(
              'No Vibes here',
              style: TextStyle(
                color: Color(0xFF251538),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Create a photo, video or text Vibe to start.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF7A6B86),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _panelDecoration({double radius = 28}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: const Color(0xFFECE2D8)),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF251538).withValues(alpha: 0.045),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

String _formatCount(int value) {
  if (value >= 1000000) {
    final result = value / 1000000;
    return '${result.toStringAsFixed(result >= 10 ? 0 : 1)}M';
  }

  if (value >= 1000) {
    final result = value / 1000;
    return '${result.toStringAsFixed(result >= 10 ? 0 : 1)}K';
  }

  return value.toString();
}

enum _VibeMediaType {
  photo,
  video,
  text,
}

extension _VibeMediaTypeX on _VibeMediaType {
  String get label {
    switch (this) {
      case _VibeMediaType.photo:
        return 'Photo';
      case _VibeMediaType.video:
        return 'Video';
      case _VibeMediaType.text:
        return 'Text';
    }
  }

  IconData get icon {
    switch (this) {
      case _VibeMediaType.photo:
        return Icons.photo_rounded;
      case _VibeMediaType.video:
        return Icons.videocam_rounded;
      case _VibeMediaType.text:
        return Icons.short_text_rounded;
    }
  }

  List<Color> get colors {
    switch (this) {
      case _VibeMediaType.photo:
        return const [
          Color(0xFF6D5DF6),
          Color(0xFFE84C72),
        ];
      case _VibeMediaType.video:
        return const [
          Color(0xFF12C7B7),
          Color(0xFF6D5DF6),
        ];
      case _VibeMediaType.text:
        return const [
          Color(0xFFC99A3B),
          Color(0xFFE84C72),
        ];
    }
  }
}

class _VibeItem {
  const _VibeItem({
    required this.authorName,
    required this.authorId,
    required this.avatarText,
    required this.timeAgo,
    required this.mediaType,
    required this.caption,
    required this.tag,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.views,
    required this.isFollowing,
    required this.usesMentionAll,
    required this.mentions,
    required this.colors,
  });

  final String authorName;
  final String authorId;
  final String avatarText;
  final String timeAgo;
  final _VibeMediaType mediaType;
  final String caption;
  final String tag;
  final int likes;
  final int comments;
  final int shares;
  final int views;
  final bool isFollowing;
  final bool usesMentionAll;
  final List<String> mentions;
  final List<Color> colors;

  _VibeItem copyWith({
    int? likes,
    int? comments,
    int? shares,
    int? views,
  }) {
    return _VibeItem(
      authorName: authorName,
      authorId: authorId,
      avatarText: avatarText,
      timeAgo: timeAgo,
      mediaType: mediaType,
      caption: caption,
      tag: tag,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      shares: shares ?? this.shares,
      views: views ?? this.views,
      isFollowing: isFollowing,
      usesMentionAll: usesMentionAll,
      mentions: mentions,
      colors: colors,
    );
  }
}

class _VibeComment {
  const _VibeComment({
    required this.name,
    required this.avatarText,
    required this.text,
    required this.time,
  });

  final String name;
  final String avatarText;
  final String text;
  final String time;
}