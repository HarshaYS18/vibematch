import 'package:flutter/material.dart';

class FamilyPage extends StatefulWidget {
  const FamilyPage({super.key});

  @override
  State<FamilyPage> createState() => _FamilyPageState();
}

class _FamilyPageState extends State<FamilyPage> {
  final TextEditingController _chatController = TextEditingController();
  final TextEditingController _familyNameController = TextEditingController();
  final TextEditingController _vipRequirementController = TextEditingController(text: 'VIP 5');

  bool _hasFamily = true;
  bool _isOwner = true;
  bool _isAdmin = true;
  int _selectedTab = 0;
  int _familyLevel = 12;
  String _familyName = '🌊 SYNDICATE MEMBERS 🔥';
  String _familyId = 'azk105637';
  String _familyTier = 'Bronze Family';
  String _minimumVip = 'VIP 5';
  String _pendingCoverLabel = 'A';

  final List<_FamilyMember> _members = const [
    _FamilyMember(name: '☬Mıηę🔥', avatarText: 'M', contribution: '13.53M', roles: ['Head', 'Sergeant'], following: true, colors: [Color(0xFF4DB6E8), Color(0xFFE9F4FF)]),
    _FamilyMember(name: '♡Î âm Diâmöñd♡༄', avatarText: 'D', contribution: '21.83M', roles: ['Administrator', 'Sergeant'], following: false, colors: [Color(0xFFB23224), Color(0xFFFFD1C7)]),
    _FamilyMember(name: 'βђavya 🖤', avatarText: 'B', contribution: '18.8M', roles: ['Administrator', 'Sergeant'], following: false, colors: [Color(0xFF4E8F3A), Color(0xFFFFE6F1)]),
    _FamilyMember(name: 'ⓇUTHVIK ram🔵', avatarText: 'R', contribution: '8.27M', roles: ['Administrator', 'Major General'], following: true, colors: [Color(0xFF111111), Color(0xFFBDBDBD)]),
    _FamilyMember(name: 'NOEL~♡', avatarText: 'N', contribution: '6.4M', roles: ['Administrator', 'Major General'], following: true, colors: [Color(0xFF4A2A21), Color(0xFFE0B399)]),
    _FamilyMember(name: '€nem4💜', avatarText: 'E', contribution: '9.45M', roles: ['Major General'], following: true, colors: [Color(0xFF8C5CF6), Color(0xFFFFB8D7)]),
    _FamilyMember(name: '➳Flyer_9', avatarText: 'F', contribution: '5.45M', roles: ['Major General'], following: false, colors: [Color(0xFF251538), Color(0xFFFFD36A)]),
    _FamilyMember(name: 'Abhimanyu🏹', avatarText: 'A', contribution: '4.89M', roles: ['Major General'], following: false, colors: [Color(0xFF9A5CFF), Color(0xFFFFB8E4)]),
    _FamilyMember(name: '♓A⚡💜', avatarText: 'A', contribution: '2.84M', roles: ['Soldier'], following: true, colors: [Color(0xFF0EA5E9), Color(0xFFFFB8D7)]),
    _FamilyMember(name: '༄KAJAL༄', avatarText: 'K', contribution: '2.66M', roles: ['Soldier'], following: false, colors: [Color(0xFFE84C72), Color(0xFFFFD1DF)]),
  ];

  final List<_FamilyVibe> _vibes = [
    const _FamilyVibe(author: '☬Mıηę🔥', avatarText: 'M', caption: '🚩MAARI 🤝 DAIMOND 🔥', tag: 'HOT', likes: 17, comments: 2, isVideo: true, colors: [Color(0xFFB20E12), Color(0xFFFF4A1D)]),
    const _FamilyVibe(author: '♡Î âm Diâmöñd♡༄', avatarText: 'D', caption: 'Family event prep tonight. Everyone join voice room by 9 PM.', tag: 'EVENT', likes: 42, comments: 11, isVideo: false, colors: [Color(0xFF251538), Color(0xFF8C5CF6)]),
  ];

  final List<_FamilyChatMessage> _messages = [
    const _FamilyChatMessage(sender: '☬Mıηę🔥', text: 'Everyone push family contribution before settlement.', time: '2m', mine: false),
    const _FamilyChatMessage(sender: 'Founder', text: 'Done. I will create the room tonight.', time: 'Just now', mine: true),
  ];

  int get _adminCapacity {
    if (_familyLevel >= 30) return 5;
    if (_familyLevel >= 20) return 4;
    if (_familyLevel >= 10) return 3;
    return 2;
  }

  int get _adminCount => _members.where((member) => member.roles.contains('Administrator')).length;

  bool get _canPostFamilyVibe => _isOwner || _isAdmin;

  @override
  void dispose() {
    _chatController.dispose();
    _familyNameController.dispose();
    _vipRequirementController.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF251538),
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      );
  }

  void _openOwnerActions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _FamilyActionsSheet(
        isOwner: _isOwner,
        isAdmin: _isAdmin,
        adminCount: _adminCount,
        adminCapacity: _adminCapacity,
        onSetAdmins: () {
          Navigator.pop(context);
          _openSetAdminsSheet();
        },
        onDisband: () {
          Navigator.pop(context);
          _openDisbandSheet();
        },
        onExit: () {
          Navigator.pop(context);
          _openExitFamilySheet();
        },
      ),
    );
  }

  void _openSetAdminsSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SetFamilyAdminsSheet(
        members: _members,
        adminCapacity: _adminCapacity,
        onSave: () => _toast('Family admin changes saved locally. Backend will enforce max $_adminCapacity admins.'),
      ),
    );
  }

  void _openDisbandSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmFamilySheet(
        title: 'Disband family?',
        body: 'Only the owner can disband the family. Members will be removed and you can create a new family after disbanding.',
        actionText: 'Disband',
        danger: true,
        onConfirm: () {
          Navigator.pop(context);
          setState(() => _hasFamily = false);
          _toast('Family disbanded locally. Backend will own this later.');
        },
      ),
    );
  }

  void _openExitFamilySheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmFamilySheet(
        title: 'Exit family?',
        body: 'Every member except the owner can exit. One user can join only one family at a time.',
        actionText: 'Exit',
        danger: false,
        onConfirm: () {
          Navigator.pop(context);
          setState(() => _hasFamily = false);
          _toast('Exited family locally. Backend will own this later.');
        },
      ),
    );
  }

  void _openCreateFamilyFlow() {
    _familyNameController.text = _familyName;
    _vipRequirementController.text = _minimumVip;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateFamilySheet(
        familyNameController: _familyNameController,
        vipRequirementController: _vipRequirementController,
        coverLabel: _pendingCoverLabel,
        onPickCover: () => _toast('Family cover photo picker will connect to image picker/backend upload later.'),
        onCreate: () {
          final name = _familyNameController.text.trim();
          final vip = _vipRequirementController.text.trim();
          if (name.isEmpty || vip.isEmpty) {
            _toast('Family name and minimum VIP level are required.');
            return;
          }
          Navigator.pop(context);
          setState(() {
            _hasFamily = true;
            _isOwner = true;
            _isAdmin = true;
            _familyName = name;
            _minimumVip = vip;
            _familyId = 'vm${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
          });
          _toast('Family created locally. Backend will enforce one-family-per-user.');
        },
      ),
    );
  }

  void _openMembersPage() {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => FamilyMembersPage(
          members: _members,
          onInvite: () => _toast('Invite member flow will connect later.'),
        ),
      ),
    );
  }

  void _postFamilyVibe() {
    if (!_canPostFamilyVibe) {
      _toast('Only family owner/admins can post in family channel.');
      return;
    }

    setState(() {
      _vibes.insert(
        0,
        const _FamilyVibe(
          author: 'Founder',
          avatarText: 'F',
          caption: 'New family channel update posted locally.',
          tag: 'NEW',
          likes: 0,
          comments: 0,
          isVideo: false,
          colors: [Color(0xFF12C7B7), Color(0xFF6D5DF6)],
        ),
      );
    });
    _toast('Family Vibe posted locally. Backend family-channel post API later.');
  }

  void _sendChatMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.insert(0, _FamilyChatMessage(sender: 'Founder', text: text, time: 'Just now', mine: true));
      _chatController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasFamily) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: _NoFamilyState(onCreateFamily: _openCreateFamilyFlow),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _FamilyTopHero(
                familyName: _familyName,
                familyId: _familyId,
                familyTier: _familyTier,
                familyLevel: _familyLevel,
                memberCount: _members.length,
                maxMembers: 200,
                rankLabel: 'NO.99+',
                onBack: () => Navigator.pop(context),
                onShare: () => _toast('Family share/invite card will open here.'),
                onStore: () => _toast('Family shop/rewards will open here.'),
                onActions: _openOwnerActions,
              ),
            ),
            SliverToBoxAdapter(
              child: _FamilyMembersStrip(
                members: _members.take(5).toList(),
                totalCount: 30,
                onOpenMembers: _openMembersPage,
                onInvite: () => _toast('Invite to family flow will connect later.'),
              ),
            ),
            SliverToBoxAdapter(
              child: _FamilyChannelTabs(
                selectedIndex: _selectedTab,
                canPost: _canPostFamilyVibe,
                onSelected: (index) => setState(() => _selectedTab = index),
                onPost: _postFamilyVibe,
              ),
            ),
            if (_selectedTab == 0)
              SliverList.separated(
                itemCount: _vibes.length,
                separatorBuilder: (_, _) => const SizedBox(height: 18),
                itemBuilder: (context, index) => _FamilyVibeCard(vibe: _vibes[index]),
              )
            else
              SliverToBoxAdapter(
                child: _FamilyChatModule(
                  messages: _messages,
                  controller: _chatController,
                  onSend: _sendChatMessage,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

class _FamilyTopHero extends StatelessWidget {
  const _FamilyTopHero({
    required this.familyName,
    required this.familyId,
    required this.familyTier,
    required this.familyLevel,
    required this.memberCount,
    required this.maxMembers,
    required this.rankLabel,
    required this.onBack,
    required this.onShare,
    required this.onStore,
    required this.onActions,
  });

  final String familyName;
  final String familyId;
  final String familyTier;
  final int familyLevel;
  final int memberCount;
  final int maxMembers;
  final String rankLabel;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onStore;
  final VoidCallback onActions;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 388,
      child: Stack(
        children: [
          Container(
            height: 190,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F172A), Color(0xFF251538), Color(0xFFE84C72)],
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: _FamilyHeroPainter())),
                Positioned(
                  top: 12,
                  left: 8,
                  right: 8,
                  child: Row(
                    children: [
                      _HeroIconButton(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
                      const Spacer(),
                      _HeroIconButton(icon: Icons.reply_rounded, onTap: onShare),
                      const SizedBox(width: 12),
                      _HeroIconButton(icon: Icons.storefront_rounded, onTap: onStore, showDot: true),
                      const SizedBox(width: 12),
                      _HeroIconButton(icon: Icons.settings_rounded, onTap: onActions),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            top: 116,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E8),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFFFD1B4), width: 1.3),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 18, offset: const Offset(0, 9))],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        Container(
                          width: 86,
                          height: 86,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: const LinearGradient(colors: [Color(0xFF111827), Color(0xFFFF4A1D)]),
                          ),
                          child: const Center(child: Text('A', style: TextStyle(color: Color(0xFFFFD36A), fontSize: 54, fontWeight: FontWeight.w900))),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(familyName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF111111), fontSize: 16.5, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Flexible(child: Text('ID:$familyId', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF9A9A9A), fontSize: 13, fontWeight: FontWeight.w700))),
                                  const SizedBox(width: 5),
                                  const Icon(Icons.copy_rounded, size: 14, color: Color(0xFFB0B0B0)),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  const Icon(Icons.person_rounded, size: 17, color: Color(0xFFB8B8B8)),
                                  const SizedBox(width: 5),
                                  Text('$memberCount/$maxMembers', style: const TextStyle(color: Color(0xFF111111), fontSize: 13, fontWeight: FontWeight.w900)),
                                  const Text(' | Make Friends', style: TextStyle(color: Color(0xFF444444), fontSize: 13, fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFFFD400), Color(0xFFFF8A00)]),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(rankLabel, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF12C7B7), Color(0xFFC99A3B)]),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 25),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(familyTier, style: const TextStyle(color: Color(0xFF4A2A21), fontSize: 14, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 7),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                minHeight: 7,
                                value: (familyLevel % 10) / 10,
                                backgroundColor: const Color(0xFFE8CDB5),
                                color: const Color(0xFF7A4A20),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: const Color(0xFFFFE3C9), borderRadius: BorderRadius.circular(999)),
                        child: const Icon(Icons.chevron_right_rounded, color: Color(0xFF4A2A21), size: 28),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FamilyMembersStrip extends StatelessWidget {
  const _FamilyMembersStrip({required this.members, required this.totalCount, required this.onOpenMembers, required this.onInvite});

  final List<_FamilyMember> members;
  final int totalCount;
  final VoidCallback onOpenMembers;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 14),
      child: Column(
        children: [
          InkWell(
            onTap: onOpenMembers,
            borderRadius: BorderRadius.circular(14),
            child: Row(
              children: [
                const Text('Family member', style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFF0F0F2), borderRadius: BorderRadius.circular(999)),
                  child: Text('$totalCount', style: const TextStyle(color: Color(0xFF9A9A9A), fontSize: 12, fontWeight: FontWeight.w900)),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded, color: Colors.black, size: 31),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: members.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 18),
              itemBuilder: (context, index) {
                if (index == members.length) {
                  return _InviteMemberCircle(onInvite: onInvite);
                }
                return _FamilyMemberBubble(member: members[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FamilyChannelTabs extends StatelessWidget {
  const _FamilyChannelTabs({required this.selectedIndex, required this.canPost, required this.onSelected, required this.onPost});

  final int selectedIndex;
  final bool canPost;
  final ValueChanged<int> onSelected;
  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Row(
        children: [
          _ChannelTab(label: 'Vibes', selected: selectedIndex == 0, onTap: () => onSelected(0)),
          const SizedBox(width: 10),
          _ChannelTab(label: 'Chat', selected: selectedIndex == 1, onTap: () => onSelected(1)),
          const Spacer(),
          if (selectedIndex == 0 && canPost)
            InkWell(
              onTap: onPost,
              borderRadius: BorderRadius.circular(9),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(color: const Color(0xFF63FF2E), borderRadius: BorderRadius.circular(9)),
                child: const Row(
                  children: [
                    Icon(Icons.edit_rounded, color: Colors.black, size: 20),
                    SizedBox(width: 6),
                    Text('Post', style: TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FamilyVibeCard extends StatelessWidget {
  const _FamilyVibeCard({required this.vibe});

  final _FamilyVibe vibe;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _GradientAvatar(text: vibe.avatarText, colors: vibe.colors, radius: 28),
              const SizedBox(width: 11),
              Expanded(child: Text(vibe.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w900))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE8E8E8)), borderRadius: BorderRadius.circular(999)),
                child: const Text('Following', style: TextStyle(color: Color(0xFF333333), fontSize: 14, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.more_vert_rounded, color: Color(0xFF9A9A9A), size: 26),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 305,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), gradient: LinearGradient(colors: vibe.colors)),
            child: Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: _FamilyVibeMediaPainter(isVideo: vibe.isVideo))),
                if (vibe.isVideo)
                  const Center(child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 52)),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 86,
                        height: 86,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(color: const Color(0xFFFFE100), borderRadius: BorderRadius.circular(9)),
                        child: ClipRRect(borderRadius: BorderRadius.circular(7), child: _GradientAvatar(text: vibe.avatarText, colors: const [Color(0xFF111111), Color(0xFF777777)], radius: 40)),
                      ),
                      Positioned(
                        right: -18,
                        top: 27,
                        child: Container(width: 35, height: 35, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.close_rounded, color: Color(0xFFB0B0B0), size: 20)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(vibe.caption, style: const TextStyle(color: Color(0xFF333333), fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFFEAF6FF), borderRadius: BorderRadius.circular(999)),
            child: Text('# ${vibe.tag} ›', style: const TextStyle(color: Color(0xFF7FA8D8), fontSize: 13, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.thumb_up_alt_outlined, color: Colors.black, size: 31),
              const SizedBox(width: 7),
              Text('${vibe.likes}', style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(width: 28),
              const Icon(Icons.mode_comment_outlined, color: Colors.black, size: 31),
              const SizedBox(width: 7),
              Text('${vibe.comments}', style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(width: 28),
              const Icon(Icons.reply_rounded, color: Colors.black, size: 32),
            ],
          ),
        ],
      ),
    );
  }
}

class _FamilyChatModule extends StatelessWidget {
  const _FamilyChatModule({required this.messages, required this.controller, required this.onSend});

  final List<_FamilyChatMessage> messages;
  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 26),
      child: Container(
        decoration: BoxDecoration(color: const Color(0xFFF7F7F8), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFECECEC))),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              child: const Row(
                children: [
                  Icon(Icons.forum_rounded, color: Color(0xFF63FF2E)),
                  SizedBox(width: 8),
                  Text('Family Chat', style: TextStyle(color: Colors.black, fontSize: 19, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            ListView.separated(
              shrinkWrap: true,
              reverse: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(14),
              itemCount: messages.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _FamilyChatBubble(message: messages[index]),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: 'Message family members...',
                        filled: true,
                        fillColor: const Color(0xFFF3F3F5),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: onSend,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.send_rounded, color: Colors.white)),
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

class FamilyMembersPage extends StatefulWidget {
  const FamilyMembersPage({super.key, required this.members, required this.onInvite});

  final List<_FamilyMember> members;
  final VoidCallback onInvite;

  @override
  State<FamilyMembersPage> createState() => _FamilyMembersPageState();
}

class _FamilyMembersPageState extends State<FamilyMembersPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.members.where((member) => member.name.toLowerCase().contains(_query.toLowerCase())).toList();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 30),
          children: [
            Row(
              children: [
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 28)),
                const SizedBox(width: 6),
                const Text('Family member', style: TextStyle(color: Colors.black, fontSize: 26, fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search member',
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFB0B0B0), size: 31),
                filled: true,
                fillColor: const Color(0xFFF0F0F4),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Text('All members (${visible.length})', style: const TextStyle(color: Color(0xFF999999), fontSize: 17, fontWeight: FontWeight.w500)),
                const Spacer(),
                const Icon(Icons.sort_rounded, color: Colors.black, size: 26),
                const SizedBox(width: 6),
                const Text('Default sorting', style: TextStyle(color: Color(0xFF444444), fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 24),
            ...visible.map((member) => _FamilyMemberListRow(member: member, onInvite: widget.onInvite)),
          ],
        ),
      ),
    );
  }
}

class _FamilyMemberListRow extends StatelessWidget {
  const _FamilyMemberListRow({required this.member, required this.onInvite});

  final _FamilyMember member;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 23),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GradientAvatar(text: member.avatarText, colors: member.colors, radius: 38),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: member.roles.map((role) => _RoleBadge(role: role)).toList(),
                ),
                const SizedBox(height: 8),
                Text('Quarterly Contribution: ${member.contribution}', style: const TextStyle(color: Color(0xFFB2B2B2), fontSize: 15, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: onInvite,
            borderRadius: BorderRadius.circular(9),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: member.following ? const Color(0xFFF5F5F7) : const Color(0xFF63FF2E), borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.black, size: 26),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetFamilyAdminsSheet extends StatefulWidget {
  const _SetFamilyAdminsSheet({required this.members, required this.adminCapacity, required this.onSave});

  final List<_FamilyMember> members;
  final int adminCapacity;
  final VoidCallback onSave;

  @override
  State<_SetFamilyAdminsSheet> createState() => _SetFamilyAdminsSheetState();
}

class _SetFamilyAdminsSheetState extends State<_SetFamilyAdminsSheet> {
  late final Set<String> _selectedAdmins = widget.members.where((member) => member.roles.contains('Administrator')).map((member) => member.name).toSet();

  void _toggleAdmin(_FamilyMember member) {
    if (member.roles.contains('Head')) return;
    setState(() {
      if (_selectedAdmins.contains(member.name)) {
        _selectedAdmins.remove(member.name);
      } else if (_selectedAdmins.length < widget.adminCapacity) {
        _selectedAdmins.add(member.name);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Set family admins', style: TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('Admins: ${_selectedAdmins.length}/${widget.adminCapacity}. Default starts at 2 and capacity grows as family level increases. Family level resets quarterly.', style: const TextStyle(color: Color(0xFF777777), fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: widget.members.map((member) {
                  final selected = _selectedAdmins.contains(member.name);
                  final lockedHead = member.roles.contains('Head');
                  return InkWell(
                    onTap: () => _toggleAdmin(member),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 9),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: selected ? const Color(0xFFEFFFE9) : const Color(0xFFF7F7F8), borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        children: [
                          _GradientAvatar(text: member.avatarText, colors: member.colors, radius: 24),
                          const SizedBox(width: 10),
                          Expanded(child: Text(member.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w900))),
                          Text(lockedHead ? 'Owner' : selected ? 'Admin' : 'Member', style: TextStyle(color: selected ? const Color(0xFF2BA300) : const Color(0xFF777777), fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _PrimarySheetButton(text: 'Save admins', danger: false, onTap: () { Navigator.pop(context); widget.onSave(); }),
        ],
      ),
    );
  }
}

class _CreateFamilySheet extends StatelessWidget {
  const _CreateFamilySheet({required this.familyNameController, required this.vipRequirementController, required this.coverLabel, required this.onPickCover, required this.onCreate});

  final TextEditingController familyNameController;
  final TextEditingController vipRequirementController;
  final String coverLabel;
  final VoidCallback onPickCover;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Create Family', style: TextStyle(color: Colors.black, fontSize: 23, fontWeight: FontWeight.w900)),
          const SizedBox(height: 7),
          const Text('One person can create only one family. You can create a new one after exiting or disbanding your current family.', style: TextStyle(color: Color(0xFF777777), fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Center(
            child: InkWell(
              onTap: onPickCover,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: const LinearGradient(colors: [Color(0xFF111827), Color(0xFFE84C72)])),
                child: Center(child: Text(coverLabel, style: const TextStyle(color: Color(0xFFFFD36A), fontSize: 54, fontWeight: FontWeight.w900))),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SheetTextField(controller: familyNameController, label: 'Family name', hint: 'Enter family name'),
          const SizedBox(height: 12),
          _SheetTextField(controller: vipRequirementController, label: 'Minimum VIP level required to join', hint: 'Example: VIP 5'),
          const SizedBox(height: 16),
          _PrimarySheetButton(text: 'Create Family', danger: false, onTap: onCreate),
        ],
      ),
    );
  }
}

class _FamilyActionsSheet extends StatelessWidget {
  const _FamilyActionsSheet({required this.isOwner, required this.isAdmin, required this.adminCount, required this.adminCapacity, required this.onSetAdmins, required this.onDisband, required this.onExit});

  final bool isOwner;
  final bool isAdmin;
  final int adminCount;
  final int adminCapacity;
  final VoidCallback onSetAdmins;
  final VoidCallback onDisband;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Align(alignment: Alignment.centerLeft, child: Text('Family options', style: TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.w900))),
          const SizedBox(height: 12),
          if (isOwner) ...[
            _ActionTile(icon: Icons.admin_panel_settings_rounded, title: 'Set admins', subtitle: 'Current admins $adminCount/$adminCapacity. Max 5 admins later.', onTap: onSetAdmins),
            _ActionTile(icon: Icons.delete_forever_rounded, title: 'Disband family', subtitle: 'Owner only. Members can join/create another family after disband.', danger: true, onTap: onDisband),
          ] else
            _ActionTile(icon: Icons.logout_rounded, title: 'Exit family', subtitle: 'Everyone except owner can exit family.', onTap: onExit),
        ],
      ),
    );
  }
}

class _ConfirmFamilySheet extends StatelessWidget {
  const _ConfirmFamilySheet({required this.title, required this.body, required this.actionText, required this.danger, required this.onConfirm});

  final String title;
  final String body;
  final String actionText;
  final bool danger;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF777777), fontSize: 13, height: 1.35, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _SecondarySheetButton(text: 'Cancel', onTap: () => Navigator.pop(context))),
              const SizedBox(width: 10),
              Expanded(child: _PrimarySheetButton(text: actionText, danger: danger, onTap: onConfirm)),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoFamilyState extends StatelessWidget {
  const _NoFamilyState({required this.onCreateFamily});

  final VoidCallback onCreateFamily;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(32), gradient: const LinearGradient(colors: [Color(0xFF251538), Color(0xFFE84C72)])),
              child: const Icon(Icons.diversity_3_rounded, color: Colors.white, size: 52),
            ),
            const SizedBox(height: 18),
            const Text('No family joined', style: TextStyle(color: Colors.black, fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('A member can join only one family. Create a new family by selecting cover photo, family name and minimum VIP level required to join.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF777777), fontSize: 13.5, height: 1.35, fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),
            InkWell(
              onTap: onCreateFamily,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
                decoration: BoxDecoration(color: const Color(0xFF63FF2E), borderRadius: BorderRadius.circular(999)),
                child: const Text('Create Family', style: TextStyle(color: Colors.black, fontSize: 17, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(14),
      padding: EdgeInsets.fromLTRB(18, 12, 18, 18 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 28, offset: const Offset(0, 12))]),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 42, height: 5, decoration: BoxDecoration(color: const Color(0xFFE0D5CB), borderRadius: BorderRadius.circular(999))),
            const SizedBox(height: 16),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}

class _SheetTextField extends StatelessWidget {
  const _SheetTextField({required this.controller, required this.label, required this.hint});

  final TextEditingController controller;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.black, fontSize: 13.5, fontWeight: FontWeight.w900)),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFF3F3F5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap, this.danger = false});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFE84C72) : const Color(0xFF251538);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: const Color(0xFFFAF7F1), borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: Color(0xFF777777), fontSize: 11.5, fontWeight: FontWeight.w700))]),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF999999)),
          ],
        ),
      ),
    );
  }
}

class _PrimarySheetButton extends StatelessWidget {
  const _PrimarySheetButton({required this.text, required this.danger, required this.onTap});

  final String text;
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 50,
        decoration: BoxDecoration(color: danger ? const Color(0xFFE84C72) : const Color(0xFF251538), borderRadius: BorderRadius.circular(18)),
        child: Center(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900))),
      ),
    );
  }
}

class _SecondarySheetButton extends StatelessWidget {
  const _SecondarySheetButton({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 50,
        decoration: BoxDecoration(color: const Color(0xFFFAF7F1), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFECE2D8))),
        child: Center(child: Text(text, style: const TextStyle(color: Color(0xFF4A2A63), fontSize: 14, fontWeight: FontWeight.w900))),
      ),
    );
  }
}

class _ChannelTab extends StatelessWidget {
  const _ChannelTab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(color: selected ? Colors.black : const Color(0xFFF3F3F5), borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : const Color(0xFF777777), fontSize: 15, fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _FamilyMemberBubble extends StatelessWidget {
  const _FamilyMemberBubble({required this.member});

  final _FamilyMember member;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      child: Column(
        children: [
          _GradientAvatar(text: member.avatarText, colors: member.colors, radius: 38),
          const SizedBox(height: 8),
          Text(member.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF999999), fontSize: 11.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _InviteMemberCircle extends StatelessWidget {
  const _InviteMemberCircle({required this.onInvite});

  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onInvite,
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        width: 84,
        child: Column(
          children: [
            Container(width: 76, height: 76, decoration: const BoxDecoration(color: Color(0xFFF5F5F7), shape: BoxShape.circle), child: const Icon(Icons.add_rounded, color: Colors.black, size: 42)),
            const SizedBox(height: 8),
            const Text('Invite to join', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Color(0xFF999999), fontSize: 11.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _GradientAvatar extends StatelessWidget {
  const _GradientAvatar({required this.text, required this.colors, required this.radius});

  final String text;
  final List<Color> colors;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: colors.first,
      child: Container(
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors)),
        child: Center(child: Text(text, style: TextStyle(color: Colors.white, fontSize: radius * 0.72, fontWeight: FontWeight.w900))),
      ),
    );
  }
}

class _HeroIconButton extends StatelessWidget {
  const _HeroIconButton({required this.icon, required this.onTap, this.showDot = false});

  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, color: Colors.white, size: 34),
          if (showDot)
            Positioned(right: -1, top: -1, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFE84C72), shape: BoxShape.circle))),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == 'Administrator';
    final isHead = role == 'Head';
    final color = isHead ? const Color(0xFFFFB23F) : isAdmin ? const Color(0xFF8C35F6) : role == 'Soldier' ? const Color(0xFF1BA7FF) : const Color(0xFFFF8A34);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isAdmin ? Icons.person_rounded : Icons.workspace_premium_rounded, color: Colors.white, size: 12),
          const SizedBox(width: 3),
          Text(role, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _FamilyChatBubble extends StatelessWidget {
  const _FamilyChatBubble({required this.message});

  final _FamilyChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: message.mine ? Colors.black : Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFECECEC))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.sender, style: TextStyle(color: message.mine ? Colors.white : Colors.black, fontSize: 12, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(message.text, style: TextStyle(color: message.mine ? Colors.white.withValues(alpha: 0.88) : const Color(0xFF444444), fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(message.time, style: TextStyle(color: message.mine ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF999999), fontSize: 10, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _FamilyHeroPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.08);
    for (var i = 0; i < 9; i++) {
      canvas.drawCircle(Offset(size.width * (i / 8), size.height * 0.8), 70 - i * 4, paint);
    }
    final wingPaint = Paint()
      ..color = const Color(0xFFFFD36A).withValues(alpha: 0.12)
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 5; i++) {
      canvas.drawArc(Rect.fromLTWH(size.width * 0.18 - i * 22, -30 + i * 6, 220, 170), 0.2, 2.4, false, wingPaint);
      canvas.drawArc(Rect.fromLTWH(size.width * 0.58 + i * 8, -30 + i * 6, 220, 170), 0.5, 2.4, false, wingPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FamilyVibeMediaPainter extends CustomPainter {
  const _FamilyVibeMediaPainter({required this.isVideo});

  final bool isVideo;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..color = Colors.white.withValues(alpha: 0.26);
    final star = Path()
      ..moveTo(size.width * 0.50, size.height * 0.14)
      ..lineTo(size.width * 0.60, size.height * 0.38)
      ..lineTo(size.width * 0.86, size.height * 0.40)
      ..lineTo(size.width * 0.66, size.height * 0.56)
      ..lineTo(size.width * 0.74, size.height * 0.82)
      ..lineTo(size.width * 0.50, size.height * 0.66)
      ..lineTo(size.width * 0.26, size.height * 0.82)
      ..lineTo(size.width * 0.34, size.height * 0.56)
      ..lineTo(size.width * 0.14, size.height * 0.40)
      ..lineTo(size.width * 0.40, size.height * 0.38)
      ..close();
    canvas.drawPath(star, paint);
    final glow = Paint()..color = Colors.white.withValues(alpha: 0.12);
    canvas.drawCircle(Offset(size.width * 0.18, size.height * 0.22), 42, glow);
    canvas.drawCircle(Offset(size.width * 0.84, size.height * 0.72), 55, glow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FamilyMember {
  const _FamilyMember({required this.name, required this.avatarText, required this.contribution, required this.roles, required this.following, required this.colors});

  final String name;
  final String avatarText;
  final String contribution;
  final List<String> roles;
  final bool following;
  final List<Color> colors;
}

class _FamilyVibe {
  const _FamilyVibe({required this.author, required this.avatarText, required this.caption, required this.tag, required this.likes, required this.comments, required this.isVideo, required this.colors});

  final String author;
  final String avatarText;
  final String caption;
  final String tag;
  final int likes;
  final int comments;
  final bool isVideo;
  final List<Color> colors;
}

class _FamilyChatMessage {
  const _FamilyChatMessage({required this.sender, required this.text, required this.time, required this.mine});

  final String sender;
  final String text;
  final String time;
  final bool mine;
}
