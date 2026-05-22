import 'package:flutter/material.dart';

import '../data/control_center_api_service.dart';

class ControlCenterPage extends StatefulWidget {
  const ControlCenterPage({super.key});

  @override
  State<ControlCenterPage> createState() => _ControlCenterPageState();
}

enum _ControlSection { assets, stealth, users, economy, safety, reviews, logs }

class _ControlCenterPageState extends State<ControlCenterPage> {
  final ControlCenterApiService _api = ControlCenterApiService();

  AdminControlSummary? _summary;
  StealthState? _stealthState;
  List<AdminUser> _users = const [];
  List<UserBanItem> _userBans = const [];
  List<DeviceBanItem> _deviceBans = const [];
  List<SuperOwnerPoolItem> _coinPools = const [];
  List<SuperOwnerLogItem> _logs = const [];
  List<SuperOwnerReviewItem> _reviews = const [];
  List<ControlCenterStoreItem> _storeItems = const [];

  _ControlSection _section = _ControlSection.assets;
  _AssetCategory _selectedAssetCategory = _assetCategories.first;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  bool get _isSuperOwner => _summary?.isSuperOwnerPanel == true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await _api.loadSummary();
      final users = await _api.loadUsers();
      StealthState? stealth;
      var userBans = const <UserBanItem>[];
      var deviceBans = const <DeviceBanItem>[];
      var coinPools = const <SuperOwnerPoolItem>[];
      var logs = const <SuperOwnerLogItem>[];
      var reviews = const <SuperOwnerReviewItem>[];
      var storeItems = const <ControlCenterStoreItem>[];

      try { stealth = await _api.loadMyStealthState(); } catch (_) {}
      try { userBans = await _api.loadUserBans(); } catch (_) {}
      try { storeItems = await _api.loadStoreItems(); } catch (_) {}
      if (summary.isSuperOwnerPanel) {
        try { deviceBans = await _api.loadDeviceBans(); } catch (_) {}
        try { coinPools = await _api.loadCoinPools(); } catch (_) {}
        try { logs = await _api.loadSuperOwnerLogs(); } catch (_) {}
        try { reviews = await _api.loadReviewItems(); } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _summary = summary;
        _stealthState = stealth;
        _users = users;
        _userBans = userBans;
        _deviceBans = deviceBans;
        _coinPools = coinPools;
        _logs = logs;
        _reviews = reviews;
        _storeItems = storeItems;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _toast(String message, {bool danger = false}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: danger ? const Color(0xFFE84C72) : const Color(0xFF12C7B7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        content: Text(message, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
      ));
  }

  Future<void> _runAction(Future<void> Function() action, String success) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      _toast(success);
      await _load();
    } catch (error) {
      if (!mounted) return;
      _toast(error.toString().replaceFirst('Exception: ', ''), danger: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<ControlCenterStoreItem> get _selectedAssets {
    return _storeItems.where((item) => item.category == _selectedAssetCategory.storeCategory || _selectedAssetCategory.aliases.contains(item.category)).toList(growable: false)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  AdminUser? _findUserByPublicId(String text) {
    final id = int.tryParse(text.trim());
    if (id == null) return null;
    for (final user in _users) {
      if (user.publicUserId == id || user.id == id) return user;
    }
    return null;
  }

  Future<void> _toggleMyStealth(bool enabled) {
    return _runAction(
      () => _api.toggleMyStealth(enabled: enabled, reason: enabled ? 'Control Center enabled hidden presence' : 'Control Center disabled hidden presence'),
      enabled ? 'Stealth mode enabled.' : 'Stealth mode disabled.',
    );
  }

  Future<void> _openGrantStealthSheet() async {
    if (!_isSuperOwner) {
      _toast('Only Founder Owner can grant stealth eligibility.', danger: true);
      return;
    }
    final userId = TextEditingController();
    final reason = TextEditingController(text: 'Founder Owner stealth control update');
    var enabled = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => _SheetFrame(
          title: 'Stealth grant',
          subtitle: 'Grant or revoke USE_STEALTH. Backend stores permission and audit log.',
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: userId, keyboardType: TextInputType.number, decoration: _input('Target public/internal user ID')),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: enabled,
              onChanged: (value) => setSheetState(() => enabled = value),
              title: const Text('Enable stealth eligibility', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
            ),
            TextField(controller: reason, maxLines: 2, decoration: _input('Reason / audit note')),
            const SizedBox(height: 12),
            _PrimaryButton(
              busy: _busy,
              label: enabled ? 'Grant stealth' : 'Revoke stealth',
              icon: enabled ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              onPressed: () {
                final user = _findUserByPublicId(userId.text);
                final safeReason = reason.text.trim();
                if (user == null || safeReason.isEmpty) {
                  _toast('Valid user ID and reason are required.', danger: true);
                  return;
                }
                Navigator.of(context).pop();
                _runAction(
                  () => _api.grantStealth(targetUserId: user.id, enabled: enabled, reason: safeReason),
                  enabled ? 'Stealth eligibility granted.' : 'Stealth eligibility revoked.',
                );
              },
            ),
          ]),
        ),
      ),
    );
    userId.dispose();
    reason.dispose();
  }

  Future<void> _openAssetSheet([ControlCenterStoreItem? existing]) async {
    final category = existing == null
        ? _selectedAssetCategory
        : _assetCategories.firstWhere((item) => item.storeCategory == existing.category || item.aliases.contains(existing.category), orElse: () => _selectedAssetCategory);
    var selectedCategory = category;
    final itemId = TextEditingController(text: existing?.itemId ?? '');
    final name = TextEditingController(text: existing?.name ?? '');
    final imageUrl = TextEditingController(text: existing?.imageUrl ?? existing?.assetUrl ?? '');
    final thumbnailUrl = TextEditingController(text: existing?.thumbnailUrl ?? '');
    final price = TextEditingController(text: '${existing?.priceCoins ?? 0}');
    final sortOrder = TextEditingController(text: '${existing?.sortOrder ?? 0}');
    final reason = TextEditingController(text: existing == null ? 'Super Owner asset catalog add' : 'Super Owner asset catalog update');
    var isActive = existing?.active ?? true;
    var isFeatured = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => _SheetFrame(
          title: existing == null ? 'Add asset' : 'Edit asset',
          subtitle: 'Save CDN/Object Storage URLs into backend catalog. Binary upload connects next.',
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<_AssetCategory>(
              initialValue: selectedCategory,
              decoration: _input('Category'),
              items: _assetCategories.map((item) => DropdownMenuItem(value: item, child: Text(item.title))).toList(growable: false),
              onChanged: existing == null ? (value) { if (value != null) setSheetState(() => selectedCategory = value); } : null,
            ),
            const SizedBox(height: 10),
            TextField(controller: itemId, enabled: existing == null, decoration: _input('Asset ID key')),
            const SizedBox(height: 10),
            TextField(controller: name, decoration: _input('Display name')),
            const SizedBox(height: 10),
            TextField(controller: imageUrl, decoration: _input('Image / WebP / Lottie URL')),
            const SizedBox(height: 10),
            TextField(controller: thumbnailUrl, decoration: _input('Thumbnail URL optional')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: price, keyboardType: TextInputType.number, decoration: _input('Price'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: sortOrder, keyboardType: TextInputType.number, decoration: _input('Sort'))),
            ]),
            SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, value: isActive, onChanged: (value) => setSheetState(() => isActive = value), title: const Text('Enabled')),
            SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, value: isFeatured, onChanged: (value) => setSheetState(() => isFeatured = value), title: const Text('Default / featured')),
            TextField(controller: reason, maxLines: 2, decoration: _input('Reason / audit note')),
            const SizedBox(height: 12),
            _PrimaryButton(
              busy: _busy,
              label: existing == null ? 'Save asset' : 'Update asset',
              icon: Icons.cloud_upload_rounded,
              onPressed: () {
                final id = itemId.text.trim().toLowerCase().replaceAll(' ', '_');
                final assetUrl = imageUrl.text.trim();
                final safeReason = reason.text.trim();
                if (id.isEmpty || name.text.trim().isEmpty || assetUrl.isEmpty || safeReason.isEmpty) {
                  _toast('Asset ID, name, URL, and reason are required.', danger: true);
                  return;
                }
                Navigator.of(context).pop();
                _runAction(() => _api.upsertStoreItem({
                  'item_id': id,
                  'name': name.text.trim(),
                  'category': selectedCategory.storeCategory,
                  'item_type': selectedCategory.storeItemType,
                  'description': selectedCategory.description,
                  'price_coins': int.tryParse(price.text.trim()) ?? 0,
                  'currency_type': 'coin',
                  'ownership_type': selectedCategory.freeByDefault ? 'free' : 'permanent',
                  'cdn_asset_url': assetUrl,
                  'image_url': assetUrl,
                  'thumbnail_url': thumbnailUrl.text.trim().isEmpty ? assetUrl : thumbnailUrl.text.trim(),
                  'is_active': isActive,
                  'is_featured': isFeatured,
                  'sort_order': int.tryParse(sortOrder.text.trim()) ?? 0,
                  'visibility': 'public',
                  'reason': safeReason,
                }), 'Asset saved to backend catalog.');
              },
            ),
          ]),
        ),
      ),
    );
    itemId.dispose(); name.dispose(); imageUrl.dispose(); thumbnailUrl.dispose(); price.dispose(); sortOrder.dispose(); reason.dispose();
  }

  Future<void> _toggleAsset(ControlCenterStoreItem item) {
    return _runAction(() => _api.upsertStoreItem({
      'item_id': item.itemId,
      'name': item.name,
      'category': item.category,
      'item_type': item.itemType,
      'price_coins': item.priceCoins,
      'cdn_asset_url': item.displayAssetUrl,
      'image_url': item.imageUrl ?? item.displayAssetUrl,
      'thumbnail_url': item.thumbnailUrl ?? item.displayAssetUrl,
      'is_active': !item.active,
      'sort_order': item.sortOrder,
      'reason': item.active ? 'Super Owner disabled asset' : 'Super Owner enabled asset',
    }), item.active ? 'Asset disabled.' : 'Asset enabled.');
  }

  Future<void> _setAssetDefault(ControlCenterStoreItem item) {
    return _runAction(() => _api.upsertStoreItem({
      'item_id': item.itemId,
      'name': item.name,
      'category': item.category,
      'item_type': item.itemType,
      'price_coins': item.priceCoins,
      'cdn_asset_url': item.displayAssetUrl,
      'image_url': item.imageUrl ?? item.displayAssetUrl,
      'thumbnail_url': item.thumbnailUrl ?? item.displayAssetUrl,
      'is_active': true,
      'is_featured': true,
      'sort_order': 0,
      'reason': 'Super Owner set default/featured asset',
    }), 'Asset marked as default/featured.');
  }

  InputDecoration _input(String label) => InputDecoration(labelText: label, isDense: true, filled: true, fillColor: const Color(0xFFFAF7F1), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF12C7B7)))
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : RefreshIndicator(
                    color: const Color(0xFF12C7B7),
                    onRefresh: _load,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      slivers: [
                        SliverToBoxAdapter(child: _Header(summary: _summary, onRefresh: _load)),
                        SliverToBoxAdapter(child: _SectionTabs(selected: _section, onChanged: (section) => setState(() => _section = section))),
                        SliverPadding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 120), sliver: SliverToBoxAdapter(child: _buildSection())),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildSection() {
    switch (_section) {
      case _ControlSection.assets:
        return _AssetsSection(selectedCategory: _selectedAssetCategory, categories: _assetCategories, items: _selectedAssets, onCategoryChanged: (category) => setState(() => _selectedAssetCategory = category), onAddAsset: () => _openAssetSheet(), onEditAsset: _openAssetSheet, onToggleAsset: _toggleAsset, onSetDefault: _setAssetDefault);
      case _ControlSection.stealth:
        return _StealthSection(state: _stealthState, isSuperOwner: _isSuperOwner, users: _users, busy: _busy, onToggleMine: _toggleMyStealth, onGrantTap: _openGrantStealthSheet);
      case _ControlSection.users:
        return _UsersSection(users: _users);
      case _ControlSection.economy:
        return _EconomySection(pools: _coinPools);
      case _ControlSection.safety:
        return _SafetySection(userBans: _userBans, deviceBans: _deviceBans);
      case _ControlSection.reviews:
        return _ReviewsSection(reviews: _reviews);
      case _ControlSection.logs:
        return _LogsSection(logs: _logs);
    }
  }
}

class _AssetCategory {
  const _AssetCategory({required this.title, required this.storeCategory, required this.storeItemType, required this.description, required this.icon, required this.color, this.aliases = const [], this.freeByDefault = false});
  final String title; final String storeCategory; final String storeItemType; final String description; final IconData icon; final Color color; final List<String> aliases; final bool freeByDefault;
}

const List<_AssetCategory> _assetCategories = [
  _AssetCategory(title: 'Chatroom backgrounds', storeCategory: 'room_background_chat_room', storeItemType: 'room_background', description: 'Normal live room wallpapers and background themes', icon: Icons.wallpaper_rounded, color: Color(0xFF12C7B7), aliases: ['room_background', 'theme']),
  _AssetCategory(title: 'Cricket backgrounds', storeCategory: 'room_background_cricket', storeItemType: 'room_background', description: 'Cricket Mode only backgrounds and stadium themes', icon: Icons.sports_cricket_rounded, color: Color(0xFF65B741), freeByDefault: true),
  _AssetCategory(title: 'Normal gifts', storeCategory: 'gift_normal', storeItemType: 'gift', description: 'Gift icons and standard gift visuals', icon: Icons.card_giftcard_rounded, color: Color(0xFFFF7AA2), aliases: ['gift']),
  _AssetCategory(title: 'Lucky gifts', storeCategory: 'gift_lucky', storeItemType: 'gift', description: 'Lucky gift icons and animation assets', icon: Icons.casino_rounded, color: Color(0xFFFFC857)),
  _AssetCategory(title: 'Gift animations', storeCategory: 'gift_animation', storeItemType: 'gift', description: 'WebP/Lottie/video overlays for gifts', icon: Icons.auto_awesome_rounded, color: Color(0xFF8C5CF6)),
  _AssetCategory(title: 'Avatar frames', storeCategory: 'avatar_frame', storeItemType: 'avatar_frame', description: 'Profile, seat and chat avatar frames', icon: Icons.filter_frames_rounded, color: Color(0xFF4E8CFF)),
  _AssetCategory(title: 'VIP / SVIP badges', storeCategory: 'vip_badge', storeItemType: 'badge', description: 'VIP, SVIP and official badge assets', icon: Icons.workspace_premium_rounded, color: Color(0xFFFFB84D), aliases: ['badge']),
  _AssetCategory(title: 'Entrance effects', storeCategory: 'entrance_effect', storeItemType: 'entrance_effect', description: 'Room entry animation and sound assets', icon: Icons.rocket_launch_rounded, color: Color(0xFFE84C72)),
  _AssetCategory(title: 'Chat bubbles', storeCategory: 'chat_bubble', storeItemType: 'chat_bubble', description: 'Inbox and chatroom bubble designs', icon: Icons.chat_bubble_rounded, color: Color(0xFF00A8CC)),
  _AssetCategory(title: 'Animated emojis', storeCategory: 'animated_emoji', storeItemType: 'event_asset', description: 'Seat/avatar reaction animations', icon: Icons.emoji_emotions_rounded, color: Color(0xFFFF9F1C)),
  _AssetCategory(title: 'Event banners', storeCategory: 'event_asset', storeItemType: 'event_asset', description: 'Home banners and campaign graphics', icon: Icons.campaign_rounded, color: Color(0xFF7B61FF), aliases: ['event_asset']),
];

class _Header extends StatelessWidget {
  const _Header({required this.summary, required this.onRefresh});
  final AdminControlSummary? summary; final VoidCallback onRefresh;
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.fromLTRB(14, 10, 14, 10), padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF120D1F), Color(0xFF4A2A63), Color(0xFFFFC857)]), borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.16), blurRadius: 24, offset: const Offset(0, 12))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFFFFC857))), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Super Owner Control Center', style: TextStyle(color: Colors.white, fontSize: 18, height: 1, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text((summary?.currentPrimaryRole ?? 'control_center').replaceAll('_', ' ').toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w800))])), IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh_rounded, color: Colors.white))]), const SizedBox(height: 14), Wrap(spacing: 8, runSpacing: 8, children: [_Metric(label: 'Users', value: '${summary?.usersCount ?? 0}'), _Metric(label: 'Active', value: '${summary?.activeUsersCount ?? 0}'), _Metric(label: 'Banned', value: '${summary?.bannedUsersCount ?? 0}'), _Metric(label: 'Officials', value: '${summary?.officialUsersCount ?? 0}')])])) ;
}

class _SectionTabs extends StatelessWidget {
  const _SectionTabs({required this.selected, required this.onChanged});
  final _ControlSection selected; final ValueChanged<_ControlSection> onChanged;
  @override
  Widget build(BuildContext context) {
    final items = [_TabSpec(Icons.auto_awesome_rounded, 'Assets', _ControlSection.assets), _TabSpec(Icons.visibility_off_rounded, 'Stealth', _ControlSection.stealth), _TabSpec(Icons.people_alt_rounded, 'Users', _ControlSection.users), _TabSpec(Icons.account_balance_wallet_rounded, 'Economy', _ControlSection.economy), _TabSpec(Icons.shield_rounded, 'Safety', _ControlSection.safety), _TabSpec(Icons.fact_check_rounded, 'Reviews', _ControlSection.reviews), _TabSpec(Icons.receipt_long_rounded, 'Logs', _ControlSection.logs)];
    return SizedBox(height: 48, child: ListView.separated(padding: const EdgeInsets.symmetric(horizontal: 14), scrollDirection: Axis.horizontal, itemCount: items.length, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (context, index) { final item = items[index]; final active = item.section == selected; return GestureDetector(onTap: () => onChanged(item.section), child: AnimatedContainer(duration: const Duration(milliseconds: 180), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: active ? const Color(0xFF251538) : Colors.white, borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFFEDE3D7))), child: Row(children: [Icon(item.icon, size: 16, color: active ? Colors.white : const Color(0xFF7B6A86)), const SizedBox(width: 6), Text(item.label, style: TextStyle(color: active ? Colors.white : const Color(0xFF251538), fontSize: 11.5, fontWeight: FontWeight.w900))]))); }));
  }
}

class _TabSpec { const _TabSpec(this.icon, this.label, this.section); final IconData icon; final String label; final _ControlSection section; }

class _StealthSection extends StatelessWidget {
  const _StealthSection({required this.state, required this.isSuperOwner, required this.users, required this.busy, required this.onToggleMine, required this.onGrantTap});
  final StealthState? state; final bool isSuperOwner; final List<AdminUser> users; final bool busy; final ValueChanged<bool> onToggleMine; final VoidCallback onGrantTap;
  @override
  Widget build(BuildContext context) { final canUse = state?.canUseStealth == true; final enabled = state?.enabled == true; final officials = users.where((user) => user.primaryRole != 'user').take(10); return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(width: 50, height: 50, decoration: BoxDecoration(color: const Color(0xFF251538), borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.visibility_off_rounded, color: Color(0xFFFFC857))), const SizedBox(width: 12), const Expanded(child: _PanelTitle(title: 'Stealth Control', subtitle: 'Hidden presence eligibility and personal stealth switch. Grants are backend-controlled and audit logged.'))]), const SizedBox(height: 12), _MiniRecord(icon: Icons.person_pin_circle_rounded, title: 'My stealth state', subtitle: canUse ? 'Eligible for hidden presence' : 'No stealth eligibility on this account', trailing: enabled ? 'Enabled' : 'Off'), SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, value: enabled, onChanged: !canUse || busy ? null : onToggleMine, title: const Text('Hide my room presence', style: TextStyle(color: Color(0xFF251538), fontSize: 13, fontWeight: FontWeight.w900)), subtitle: const Text('Supported room surfaces should hide official presence according to backend rules.', style: TextStyle(color: Color(0xFF7B6A86), fontSize: 10.5, fontWeight: FontWeight.w700)))])), if (isSuperOwner) _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Expanded(child: _PanelTitle(title: 'Founder stealth grants', subtitle: 'Grant or revoke USE_STEALTH for selected accounts.')), _SmallButton(label: 'Grant', icon: Icons.key_rounded, onTap: onGrantTap)]), const SizedBox(height: 12), ...officials.map((user) => _MiniRecord(icon: Icons.admin_panel_settings_rounded, title: user.title, subtitle: 'ID ${user.publicUserId} • ${user.roleLabel}', trailing: 'Official'))]))]); }
}

class _AssetsSection extends StatelessWidget {
  const _AssetsSection({required this.selectedCategory, required this.categories, required this.items, required this.onCategoryChanged, required this.onAddAsset, required this.onEditAsset, required this.onToggleAsset, required this.onSetDefault});
  final _AssetCategory selectedCategory; final List<_AssetCategory> categories; final List<ControlCenterStoreItem> items; final ValueChanged<_AssetCategory> onCategoryChanged; final VoidCallback onAddAsset; final ValueChanged<ControlCenterStoreItem> onEditAsset; final ValueChanged<ControlCenterStoreItem> onToggleAsset; final ValueChanged<ControlCenterStoreItem> onSetDefault;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Expanded(child: _PanelTitle(title: 'Asset Control Center', subtitle: 'One backend source for CDN assets, categories, enable/disable and defaults.')), _SmallButton(label: 'Add', icon: Icons.add_rounded, onTap: onAddAsset)]), const SizedBox(height: 12), Wrap(spacing: 8, runSpacing: 8, children: categories.map((category) { final active = category.storeCategory == selectedCategory.storeCategory; return GestureDetector(onTap: () => onCategoryChanged(category), child: AnimatedContainer(duration: const Duration(milliseconds: 180), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: active ? category.color : const Color(0xFFFAF7F1), borderRadius: BorderRadius.circular(16), border: Border.all(color: active ? category.color : const Color(0xFFEDE3D7))), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(category.icon, color: active ? Colors.white : category.color, size: 16), const SizedBox(width: 6), Text(category.title, style: TextStyle(color: active ? Colors.white : const Color(0xFF251538), fontSize: 10.8, fontWeight: FontWeight.w900))]))); }).toList(growable: false))])), _Panel(child: Row(children: [Container(width: 48, height: 48, decoration: BoxDecoration(color: selectedCategory.color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(18)), child: Icon(selectedCategory.icon, color: selectedCategory.color)), const SizedBox(width: 12), Expanded(child: _PanelTitle(title: selectedCategory.title, subtitle: selectedCategory.description)), _StatusPill(text: '${items.length} assets', color: selectedCategory.color)])), if (items.isEmpty) _EmptyPanel(icon: selectedCategory.icon, title: 'No assets in ${selectedCategory.title}', subtitle: 'Tap Add and save CDN/Object Storage URLs into this category.') else ...items.map((item) => _AssetCard(item: item, onEdit: () => onEditAsset(item), onToggle: () => onToggleAsset(item), onDefault: () => onSetDefault(item)))]);
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({required this.item, required this.onEdit, required this.onToggle, required this.onDefault});
  final ControlCenterStoreItem item; final VoidCallback onEdit; final VoidCallback onToggle; final VoidCallback onDefault;
  @override
  Widget build(BuildContext context) { final url = item.displayAssetUrl; return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFEDE3D7))), child: Row(children: [Container(width: 58, height: 58, clipBehavior: Clip.antiAlias, decoration: BoxDecoration(color: const Color(0xFF251538), borderRadius: BorderRadius.circular(18)), child: url.isEmpty ? const Icon(Icons.image_rounded, color: Colors.white) : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, color: Colors.white))), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF251538), fontSize: 13.2, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text('${item.itemType} • ${item.category}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 10.5, fontWeight: FontWeight.w700)), const SizedBox(height: 5), Row(children: [_StatusPill(text: item.active ? 'Enabled' : 'Disabled', color: item.active ? const Color(0xFF12C7B7) : const Color(0xFFE84C72)), const SizedBox(width: 6), _StatusPill(text: item.priceCoins == 0 ? 'Free' : '${item.priceCoins} coins', color: const Color(0xFFFFC857))])])), PopupMenuButton<String>(icon: const Icon(Icons.more_horiz_rounded, color: Color(0xFF251538)), onSelected: (value) { if (value == 'edit') onEdit(); if (value == 'toggle') onToggle(); if (value == 'default') onDefault(); }, itemBuilder: (context) => [const PopupMenuItem(value: 'edit', child: Text('Edit asset')), PopupMenuItem(value: 'toggle', child: Text(item.active ? 'Disable' : 'Enable')), const PopupMenuItem(value: 'default', child: Text('Set default/featured'))]) ])); }
}

class _UsersSection extends StatelessWidget { const _UsersSection({required this.users}); final List<AdminUser> users; @override Widget build(BuildContext context) => _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const _PanelTitle(title: 'Users & roles', subtitle: 'Role hierarchy remains backend-controlled'), const SizedBox(height: 12), ...users.take(18).map((user) => _MiniRecord(icon: Icons.person_rounded, title: user.title, subtitle: 'ID ${user.publicUserId} • ${user.roleLabel}', trailing: user.isBanned ? 'Banned' : user.isActive ? 'Active' : 'Inactive'))])); }
class _EconomySection extends StatelessWidget { const _EconomySection({required this.pools}); final List<SuperOwnerPoolItem> pools; @override Widget build(BuildContext context) => _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const _PanelTitle(title: 'Economy source of truth', subtitle: 'Coin pools, wallet ledgers, VIP/SVIP and store catalog controls'), const SizedBox(height: 12), if (pools.isEmpty) const Text('No coin pools loaded yet.', style: TextStyle(color: Color(0xFF7B6A86), fontSize: 12, fontWeight: FontWeight.w700)) else ...pools.map((pool) => _MiniRecord(icon: Icons.account_balance_wallet_rounded, title: pool.poolType, subtitle: 'Owner ${pool.ownerUserId ?? 'Platform'} • Reserved ${pool.reservedBalance}', trailing: '${pool.balance}'))])); }
class _SafetySection extends StatelessWidget { const _SafetySection({required this.userBans, required this.deviceBans}); final List<UserBanItem> userBans; final List<DeviceBanItem> deviceBans; @override Widget build(BuildContext context) => _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const _PanelTitle(title: 'Safety & moderation', subtitle: 'Active user/device bans and protected moderation state'), const SizedBox(height: 12), ...userBans.take(10).map((ban) => _MiniRecord(icon: Icons.block_rounded, title: 'User ${ban.userId}', subtitle: ban.reason, trailing: ban.isActive ? 'Active' : 'Expired')), ...deviceBans.take(10).map((ban) => _MiniRecord(icon: Icons.phonelink_lock_rounded, title: ban.deviceId, subtitle: ban.reason, trailing: ban.isActive ? 'Active' : 'Lifted')), if (userBans.isEmpty && deviceBans.isEmpty) const Text('No bans loaded.', style: TextStyle(color: Color(0xFF7B6A86), fontSize: 12, fontWeight: FontWeight.w700))])); }
class _ReviewsSection extends StatelessWidget { const _ReviewsSection({required this.reviews}); final List<SuperOwnerReviewItem> reviews; @override Widget build(BuildContext context) => _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const _PanelTitle(title: 'Review queues', subtitle: 'Custom backgrounds, reports, media safety and pending approvals'), const SizedBox(height: 12), if (reviews.isEmpty) const Text('No review items loaded.', style: TextStyle(color: Color(0xFF7B6A86), fontSize: 12, fontWeight: FontWeight.w700)) else ...reviews.map((item) => _MiniRecord(icon: Icons.fact_check_rounded, title: item.title, subtitle: item.reason, trailing: item.status))])); }
class _LogsSection extends StatelessWidget { const _LogsSection({required this.logs}); final List<SuperOwnerLogItem> logs; @override Widget build(BuildContext context) => _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const _PanelTitle(title: 'Audit logs', subtitle: 'Sensitive actions remain reason-required and audit logged'), const SizedBox(height: 12), if (logs.isEmpty) const Text('No audit logs loaded.', style: TextStyle(color: Color(0xFF7B6A86), fontSize: 12, fontWeight: FontWeight.w700)) else ...logs.take(30).map((log) => _MiniRecord(icon: Icons.receipt_long_rounded, title: log.action, subtitle: log.reason.isEmpty ? 'Actor ${log.actorUserId ?? '-'} → Target ${log.targetUserId ?? '-'}' : log.reason, trailing: log.resourceType ?? 'audit'))])); }

class _SheetFrame extends StatelessWidget { const _SheetFrame({required this.title, required this.subtitle, required this.child}); final String title; final String subtitle; final Widget child; @override Widget build(BuildContext context) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom), child: Container(constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.86), padding: EdgeInsets.fromLTRB(14, 10, 14, MediaQuery.paddingOf(context).bottom + 14), decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))), child: ListView(shrinkWrap: true, physics: const BouncingScrollPhysics(), children: [Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: const Color(0xFFE0D5CB), borderRadius: BorderRadius.circular(999)))), const SizedBox(height: 14), Text(title, style: const TextStyle(color: Color(0xFF251538), fontSize: 19, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w700)), const SizedBox(height: 14), child]))); }
class _Panel extends StatelessWidget { const _Panel({required this.child}); final Widget child; @override Widget build(BuildContext context) => Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFEDE3D7)), boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 8))]), child: child); }
class _PanelTitle extends StatelessWidget { const _PanelTitle({required this.title, required this.subtitle}); final String title; final String subtitle; @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Color(0xFF251538), fontSize: 15.5, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, height: 1.2, fontWeight: FontWeight.w700))]); }
class _MiniRecord extends StatelessWidget { const _MiniRecord({required this.icon, required this.title, required this.subtitle, required this.trailing}); final IconData icon; final String title; final String subtitle; final String trailing; @override Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFFAF7F1), borderRadius: BorderRadius.circular(18)), child: Row(children: [Icon(icon, color: const Color(0xFF8C5CF6), size: 18), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF251538), fontSize: 12.5, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 10.5, fontWeight: FontWeight.w700))])), const SizedBox(width: 6), _StatusPill(text: trailing, color: const Color(0xFF12C7B7))])); }
class _SmallButton extends StatelessWidget { const _SmallButton({required this.label, required this.icon, required this.onTap}); final String label; final IconData icon; final VoidCallback onTap; @override Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8), decoration: BoxDecoration(color: const Color(0xFF251538), borderRadius: BorderRadius.circular(999)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: Colors.white, size: 15), const SizedBox(width: 5), Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900))]))); }
class _PrimaryButton extends StatelessWidget { const _PrimaryButton({required this.busy, required this.label, required this.icon, required this.onPressed}); final bool busy; final String label; final IconData icon; final VoidCallback onPressed; @override Widget build(BuildContext context) => SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: busy ? null : onPressed, icon: Icon(icon, size: 17), label: Text(busy ? 'Saving...' : label), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF251538), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))))); }
class _Metric extends StatelessWidget { const _Metric({required this.label, required this.value}); final String label; final String value; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white24)), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(value, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w700))])); }
class _StatusPill extends StatelessWidget { const _StatusPill({required this.text, required this.color}); final String text; final Color color; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4), decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)), child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w900))); }
class _EmptyPanel extends StatelessWidget { const _EmptyPanel({required this.icon, required this.title, required this.subtitle}); final IconData icon; final String title; final String subtitle; @override Widget build(BuildContext context) => _Panel(child: Column(children: [Icon(icon, color: const Color(0xFF8C5CF6), size: 34), const SizedBox(height: 10), Text(title, style: const TextStyle(color: Color(0xFF251538), fontSize: 14, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w700))])); }
class _ErrorState extends StatelessWidget { const _ErrorState({required this.message, required this.onRetry}); final String message; final VoidCallback onRetry; @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(22), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline_rounded, color: Color(0xFFE84C72), size: 38), const SizedBox(height: 10), Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF251538), fontSize: 13, fontWeight: FontWeight.w800)), const SizedBox(height: 14), _SmallButton(label: 'Retry', icon: Icons.refresh_rounded, onTap: onRetry)]))); }
