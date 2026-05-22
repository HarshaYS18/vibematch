import 'package:flutter/material.dart';

import '../data/control_center_api_service.dart';

class ControlCenterPage extends StatefulWidget {
  const ControlCenterPage({super.key});

  @override
  State<ControlCenterPage> createState() => _ControlCenterPageState();
}

enum _ControlSection { assets, users, economy, safety, reviews, logs }

class _ControlCenterPageState extends State<ControlCenterPage> {
  final ControlCenterApiService _api = ControlCenterApiService();

  AdminControlSummary? _summary;
  List<AdminUser> _users = const [];
  List<UserBanItem> _userBans = const [];
  List<DeviceBanItem> _deviceBans = const [];
  List<SuperOwnerPoolItem> _coinPools = const [];
  List<SuperOwnerLogItem> _logs = const [];
  List<SuperOwnerReviewItem> _reviews = const [];
  List<ControlCenterStoreCategory> _storeCategories = const [];
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
      var userBans = const <UserBanItem>[];
      var deviceBans = const <DeviceBanItem>[];
      var coinPools = const <SuperOwnerPoolItem>[];
      var logs = const <SuperOwnerLogItem>[];
      var reviews = const <SuperOwnerReviewItem>[];
      var categories = const <ControlCenterStoreCategory>[];
      var items = const <ControlCenterStoreItem>[];

      try { userBans = await _api.loadUserBans(); } catch (_) {}
      if (summary.isSuperOwnerPanel || summary.isOwnerPanel || summary.isSuperAdminPanel) {
        try { categories = await _api.loadStoreCategories(); } catch (_) {}
        try { items = await _api.loadStoreItems(); } catch (_) {}
      }
      if (summary.isSuperOwnerPanel) {
        try { deviceBans = await _api.loadDeviceBans(); } catch (_) {}
        try { coinPools = await _api.loadCoinPools(); } catch (_) {}
        try { logs = await _api.loadSuperOwnerLogs(); } catch (_) {}
        try { reviews = await _api.loadReviewItems(); } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _summary = summary;
        _users = users;
        _userBans = userBans;
        _deviceBans = deviceBans;
        _coinPools = coinPools;
        _logs = logs;
        _reviews = reviews;
        _storeCategories = categories;
        _storeItems = items;
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
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: danger ? const Color(0xFFE84C72) : const Color(0xFF12C7B7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          content: Text(message, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
        ),
      );
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
    return _storeItems.where((item) {
      if (item.category == _selectedAssetCategory.storeCategory) return true;
      if (_selectedAssetCategory.aliases.contains(item.category)) return true;
      return false;
    }).toList(growable: false)
      ..sort((a, b) {
        final order = a.sortOrder.compareTo(b.sortOrder);
        if (order != 0) return order;
        return a.name.compareTo(b.name);
      });
  }

  Future<void> _openAddAssetSheet([ControlCenterStoreItem? existing]) async {
    final category = existing == null
        ? _selectedAssetCategory
        : _assetCategories.firstWhere(
            (item) => item.storeCategory == existing.category || item.aliases.contains(existing.category),
            orElse: () => _selectedAssetCategory,
          );
    var selectedCategory = category;
    final itemId = TextEditingController(text: existing?.itemId ?? '');
    final name = TextEditingController(text: existing?.name ?? '');
    final imageUrl = TextEditingController(text: existing?.imageUrl ?? existing?.assetUrl ?? '');
    final thumbnailUrl = TextEditingController(text: existing?.thumbnailUrl ?? '');
    final price = TextEditingController(text: '${existing?.priceCoins ?? 0}');
    final sortOrder = TextEditingController(text: '${existing?.sortOrder ?? 0}');
    final reason = TextEditingController(text: existing == null ? 'Super Owner asset catalog add' : 'Super Owner asset catalog update');
    var isActive = existing?.active ?? true;
    var isDefault = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.86),
                padding: EdgeInsets.fromLTRB(14, 10, 14, MediaQuery.paddingOf(context).bottom + 14),
                decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
                child: ListView(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: const Color(0xFFE0D5CB), borderRadius: BorderRadius.circular(999)))),
                    const SizedBox(height: 14),
                    Text(existing == null ? 'Add asset' : 'Edit asset', style: const TextStyle(color: Color(0xFF251538), fontSize: 19, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    const Text('CDN/object-storage URL based now. Binary upload will connect to media storage next.', style: TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<_AssetCategory>(
                      initialValue: selectedCategory,
                      decoration: _input('Category'),
                      items: _assetCategories.map((item) => DropdownMenuItem(value: item, child: Text(item.title))).toList(growable: false),
                      onChanged: existing == null ? (value) { if (value != null) setSheetState(() => selectedCategory = value); } : null,
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: itemId, enabled: existing == null, decoration: _input('Asset ID key, e.g. cricket_night_01')),
                    const SizedBox(height: 10),
                    TextField(controller: name, decoration: _input('Display name')),
                    const SizedBox(height: 10),
                    TextField(controller: imageUrl, decoration: _input('Image/CDN/WebP/Lottie URL')),
                    const SizedBox(height: 10),
                    TextField(controller: thumbnailUrl, decoration: _input('Thumbnail URL optional')),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: TextField(controller: price, keyboardType: TextInputType.number, decoration: _input('Price coins'))),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: sortOrder, keyboardType: TextInputType.number, decoration: _input('Sort order'))),
                    ]),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: isActive,
                      onChanged: (value) => setSheetState(() => isActive = value),
                      title: const Text('Enabled', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                      subtitle: const Text('Disabled assets stay in DB but app should not render them.', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: isDefault,
                      onChanged: (value) => setSheetState(() => isDefault = value),
                      title: const Text('Set as default / featured', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                      subtitle: const Text('For backgrounds this becomes the default/featured candidate for this category.', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
                    ),
                    TextField(controller: reason, maxLines: 2, decoration: _input('Reason / audit note')),
                    const SizedBox(height: 14),
                    _PrimaryButton(
                      busy: _busy,
                      label: existing == null ? 'Save asset' : 'Update asset',
                      icon: Icons.cloud_upload_rounded,
                      onPressed: () {
                        final id = itemId.text.trim().toLowerCase().replaceAll(' ', '_');
                        final displayName = name.text.trim();
                        final assetUrl = imageUrl.text.trim();
                        final safeReason = reason.text.trim();
                        if (id.isEmpty || displayName.isEmpty || assetUrl.isEmpty || safeReason.isEmpty) {
                          _toast('Asset ID, name, URL, and reason are required.', danger: true);
                          return;
                        }
                        Navigator.of(context).pop();
                        _runAction(
                          () => _api.upsertStoreItem({
                            'item_id': id,
                            'name': displayName,
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
                            'is_featured': isDefault,
                            'sort_order': int.tryParse(sortOrder.text.trim()) ?? 0,
                            'visibility': 'public',
                            'reason': safeReason,
                          }),
                          existing == null ? 'Asset added to Control Center catalog.' : 'Asset updated in Control Center catalog.',
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    itemId.dispose();
    name.dispose();
    imageUrl.dispose();
    thumbnailUrl.dispose();
    price.dispose();
    sortOrder.dispose();
    reason.dispose();
  }

  Future<void> _toggleAsset(ControlCenterStoreItem item) {
    return _runAction(
      () => _api.upsertStoreItem({
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
      }),
      item.active ? 'Asset disabled.' : 'Asset enabled.',
    );
  }

  Future<void> _setAssetDefault(ControlCenterStoreItem item) {
    return _runAction(
      () => _api.upsertStoreItem({
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
      }),
      'Asset marked as default/featured.',
    );
  }

  InputDecoration _input(String label) => InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFFAF7F1),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      );

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
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
                        SliverToBoxAdapter(child: _Header(summary: summary, onRefresh: _load)),
                        SliverToBoxAdapter(child: _SectionTabs(selected: _section, onChanged: (section) => setState(() => _section = section))),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 120),
                          sliver: SliverToBoxAdapter(child: _buildSection()),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildSection() {
    switch (_section) {
      case _ControlSection.assets:
        return _AssetsSection(
          selectedCategory: _selectedAssetCategory,
          categories: _assetCategories,
          backendCategories: _storeCategories,
          items: _selectedAssets,
          allItemsCount: _storeItems.length,
          onCategoryChanged: (category) => setState(() => _selectedAssetCategory = category),
          onAddAsset: () => _openAddAssetSheet(),
          onEditAsset: _openAddAssetSheet,
          onToggleAsset: _toggleAsset,
          onSetDefault: _setAssetDefault,
        );
      case _ControlSection.users:
        return _UsersSection(users: _users, isSuperOwner: _isSuperOwner);
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

  final String title;
  final String storeCategory;
  final String storeItemType;
  final String description;
  final IconData icon;
  final Color color;
  final List<String> aliases;
  final bool freeByDefault;
}

const List<_AssetCategory> _assetCategories = [
  _AssetCategory(title: 'Chatroom backgrounds', storeCategory: 'room_background_chat_room', storeItemType: 'room_background', description: 'Normal live room wallpapers and background themes', icon: Icons.wallpaper_rounded, color: Color(0xFF12C7B7), aliases: ['room_background', 'theme']),
  _AssetCategory(title: 'Cricket backgrounds', storeCategory: 'room_background_cricket', storeItemType: 'room_background', description: 'Cricket Mode only backgrounds, stadiums and scorer themes', icon: Icons.sports_cricket_rounded, color: Color(0xFF65B741), freeByDefault: true),
  _AssetCategory(title: 'Normal gifts', storeCategory: 'gift_normal', storeItemType: 'gift', description: 'Gift icons and standard gift catalog visuals', icon: Icons.card_giftcard_rounded, color: Color(0xFFFF7AA2), aliases: ['gift']),
  _AssetCategory(title: 'Lucky gifts', storeCategory: 'gift_lucky', storeItemType: 'gift', description: 'Lucky gift icons, multipliers and animation assets', icon: Icons.casino_rounded, color: Color(0xFFFFC857)),
  _AssetCategory(title: 'Gift animations', storeCategory: 'gift_animation', storeItemType: 'gift', description: 'WebP/Lottie/video overlays for gifts and global broadcasts', icon: Icons.auto_awesome_rounded, color: Color(0xFF8C5CF6)),
  _AssetCategory(title: 'Avatar frames', storeCategory: 'avatar_frame', storeItemType: 'avatar_frame', description: 'Profile, seat and chat avatar frames', icon: Icons.filter_frames_rounded, color: Color(0xFF4E8CFF)),
  _AssetCategory(title: 'VIP / SVIP badges', storeCategory: 'vip_badge', storeItemType: 'badge', description: 'VIP, SVIP, frozen VIP and official badge assets', icon: Icons.workspace_premium_rounded, color: Color(0xFFFFB84D), aliases: ['badge']),
  _AssetCategory(title: 'Entrance effects', storeCategory: 'entrance_effect', storeItemType: 'entrance_effect', description: 'Room entry animation, sound and luxury effect assets', icon: Icons.rocket_launch_rounded, color: Color(0xFFE84C72)),
  _AssetCategory(title: 'Chat bubbles', storeCategory: 'chat_bubble', storeItemType: 'chat_bubble', description: 'Inbox and chatroom bubble designs', icon: Icons.chat_bubble_rounded, color: Color(0xFF00A8CC)),
  _AssetCategory(title: 'Animated emojis', storeCategory: 'animated_emoji', storeItemType: 'event_asset', description: 'Seat/avatar reaction animations and emoji assets', icon: Icons.emoji_emotions_rounded, color: Color(0xFFFF9F1C)),
  _AssetCategory(title: 'Event banners', storeCategory: 'event_asset', storeItemType: 'event_asset', description: 'Home banners, events, campaign and rules graphics', icon: Icons.campaign_rounded, color: Color(0xFF7B61FF), aliases: ['event_asset']),
];

class _Header extends StatelessWidget {
  const _Header({required this.summary, required this.onRefresh});
  final AdminControlSummary? summary;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final role = summary?.currentPrimaryRole.replaceAll('_', ' ').toUpperCase() ?? 'CONTROL CENTER';
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF120D1F), Color(0xFF4A2A63), Color(0xFFFFC857)]),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.16), blurRadius: 24, offset: const Offset(0, 12))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFFFFC857))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Super Owner Control Center', style: TextStyle(color: Colors.white, fontSize: 18, height: 1, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(role, style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w800)),
          ])),
          IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh_rounded, color: Colors.white)),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _Metric(label: 'Users', value: '${summary?.usersCount ?? 0}'),
          _Metric(label: 'Active', value: '${summary?.activeUsersCount ?? 0}'),
          _Metric(label: 'Banned', value: '${summary?.bannedUsersCount ?? 0}'),
          _Metric(label: 'Officials', value: '${summary?.officialUsersCount ?? 0}'),
        ]),
      ]),
    );
  }
}

class _SectionTabs extends StatelessWidget {
  const _SectionTabs({required this.selected, required this.onChanged});
  final _ControlSection selected;
  final ValueChanged<_ControlSection> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, String label, _ControlSection section})>[
      (icon: Icons.auto_awesome_rounded, label: 'Assets', section: _ControlSection.assets),
      (icon: Icons.people_alt_rounded, label: 'Users', section: _ControlSection.users),
      (icon: Icons.account_balance_wallet_rounded, label: 'Economy', section: _ControlSection.economy),
      (icon: Icons.shield_rounded, label: 'Safety', section: _ControlSection.safety),
      (icon: Icons.fact_check_rounded, label: 'Reviews', section: _ControlSection.reviews),
      (icon: Icons.receipt_long_rounded, label: 'Logs', section: _ControlSection.logs),
    ];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          final active = item.section == selected;
          return GestureDetector(
            onTap: () => onChanged(item.section),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: active ? const Color(0xFF251538) : Colors.white, borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFFEDE3D7))),
              child: Row(children: [Icon(item.icon, size: 16, color: active ? Colors.white : const Color(0xFF7B6A86)), const SizedBox(width: 6), Text(item.label, style: TextStyle(color: active ? Colors.white : const Color(0xFF251538), fontSize: 11.5, fontWeight: FontWeight.w900))]),
            ),
          );
        },
      ),
    );
  }
}

class _AssetsSection extends StatelessWidget {
  const _AssetsSection({required this.selectedCategory, required this.categories, required this.backendCategories, required this.items, required this.allItemsCount, required this.onCategoryChanged, required this.onAddAsset, required this.onEditAsset, required this.onToggleAsset, required this.onSetDefault});

  final _AssetCategory selectedCategory;
  final List<_AssetCategory> categories;
  final List<ControlCenterStoreCategory> backendCategories;
  final List<ControlCenterStoreItem> items;
  final int allItemsCount;
  final ValueChanged<_AssetCategory> onCategoryChanged;
  final VoidCallback onAddAsset;
  final ValueChanged<ControlCenterStoreItem> onEditAsset;
  final ValueChanged<ControlCenterStoreItem> onToggleAsset;
  final ValueChanged<ControlCenterStoreItem> onSetDefault;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: _PanelTitle(title: 'Asset Control Center', subtitle: 'One backend source for CDN assets, categories, enable/disable and defaults.')),
            _SmallButton(label: 'Add', icon: Icons.add_rounded, onTap: onAddAsset),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: categories.map((category) {
            final active = category.storeCategory == selectedCategory.storeCategory;
            return GestureDetector(
              onTap: () => onCategoryChanged(category),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: active ? category.color : const Color(0xFFFAF7F1), borderRadius: BorderRadius.circular(16), border: Border.all(color: active ? category.color : const Color(0xFFEDE3D7))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(category.icon, color: active ? Colors.white : category.color, size: 16), const SizedBox(width: 6), Text(category.title, style: TextStyle(color: active ? Colors.white : const Color(0xFF251538), fontSize: 10.8, fontWeight: FontWeight.w900))]),
              ),
            );
          }).toList(growable: false)),
        ]),
      ),
      const SizedBox(height: 12),
      _CategoryExplainer(category: selectedCategory, itemsCount: items.length, totalItems: allItemsCount),
      const SizedBox(height: 12),
      if (items.isEmpty)
        _EmptyPanel(icon: selectedCategory.icon, title: 'No assets in ${selectedCategory.title}', subtitle: 'Tap Add and save CDN/Object Storage URLs into this category.')
      else
        ...items.map((item) => _AssetCard(item: item, onEdit: () => onEditAsset(item), onToggle: () => onToggleAsset(item), onDefault: () => onSetDefault(item))),
    ]);
  }
}

class _CategoryExplainer extends StatelessWidget {
  const _CategoryExplainer({required this.category, required this.itemsCount, required this.totalItems});
  final _AssetCategory category;
  final int itemsCount;
  final int totalItems;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Row(children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(color: category.color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(18)), child: Icon(category.icon, color: category.color)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(category.title, style: const TextStyle(color: Color(0xFF251538), fontSize: 14.5, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(category.description, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, height: 1.2, fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text('Category key: ${category.storeCategory} • Type: ${category.storeItemType}', style: const TextStyle(color: Color(0xFF9B8AA7), fontSize: 10, fontWeight: FontWeight.w800)),
        ])),
        _Metric(label: 'Assets', value: '$itemsCount'),
      ]),
    );
  }
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({required this.item, required this.onEdit, required this.onToggle, required this.onDefault});
  final ControlCenterStoreItem item;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDefault;

  @override
  Widget build(BuildContext context) {
    final url = item.displayAssetUrl;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFEDE3D7))),
      child: Row(children: [
        Container(
          width: 58,
          height: 58,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: const Color(0xFF251538), borderRadius: BorderRadius.circular(18)),
          child: url.isEmpty ? const Icon(Icons.image_rounded, color: Colors.white) : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, color: Colors.white)),
        ),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF251538), fontSize: 13.2, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text('${item.itemType} • ${item.category}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 10.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Row(children: [
            _StatusPill(text: item.active ? 'Enabled' : 'Disabled', color: item.active ? const Color(0xFF12C7B7) : const Color(0xFFE84C72)),
            const SizedBox(width: 6),
            _StatusPill(text: item.priceCoins == 0 ? 'Free' : '${item.priceCoins} coins', color: const Color(0xFFFFC857)),
          ]),
        ])),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_horiz_rounded, color: Color(0xFF251538)),
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'toggle') onToggle();
            if (value == 'default') onDefault();
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit asset')),
            PopupMenuItem(value: 'toggle', child: Text(item.active ? 'Disable' : 'Enable')),
            const PopupMenuItem(value: 'default', child: Text('Set default/featured')),
          ],
        ),
      ]),
    );
  }
}

class _UsersSection extends StatelessWidget {
  const _UsersSection({required this.users, required this.isSuperOwner});
  final List<AdminUser> users;
  final bool isSuperOwner;
  @override
  Widget build(BuildContext context) => _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _PanelTitle(title: 'Users & roles', subtitle: '${users.length} users loaded • role hierarchy remains backend-controlled'),
    const SizedBox(height: 12),
    ...users.take(18).map((user) => _MiniRecord(icon: Icons.person_rounded, title: user.title, subtitle: 'ID ${user.publicUserId} • ${user.roleLabel}', trailing: user.isBanned ? 'Banned' : user.isActive ? 'Active' : 'Inactive')),
  ]));
}

class _EconomySection extends StatelessWidget {
  const _EconomySection({required this.pools});
  final List<SuperOwnerPoolItem> pools;
  @override
  Widget build(BuildContext context) => _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _PanelTitle(title: 'Economy source of truth', subtitle: 'Coin pools, wallet ledgers, VIP/SVIP and store catalog controls'),
    const SizedBox(height: 12),
    if (pools.isEmpty) const Text('No coin pools loaded yet.', style: TextStyle(color: Color(0xFF7B6A86), fontSize: 12, fontWeight: FontWeight.w700)) else ...pools.map((pool) => _MiniRecord(icon: Icons.account_balance_wallet_rounded, title: pool.poolType, subtitle: 'Owner ${pool.ownerUserId ?? 'Platform'} • Reserved ${pool.reservedBalance}', trailing: '${pool.balance}')),
  ]));
}

class _SafetySection extends StatelessWidget {
  const _SafetySection({required this.userBans, required this.deviceBans});
  final List<UserBanItem> userBans;
  final List<DeviceBanItem> deviceBans;
  @override
  Widget build(BuildContext context) => Column(children: [
    _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _PanelTitle(title: 'Safety & moderation', subtitle: 'Active user/device bans and protected moderation state'),
      const SizedBox(height: 12),
      ...userBans.take(10).map((ban) => _MiniRecord(icon: Icons.block_rounded, title: 'User ${ban.userId}', subtitle: ban.reason, trailing: ban.isActive ? 'Active' : 'Expired')),
      ...deviceBans.take(10).map((ban) => _MiniRecord(icon: Icons.phonelink_lock_rounded, title: ban.deviceId, subtitle: ban.reason, trailing: ban.isActive ? 'Active' : 'Lifted')),
      if (userBans.isEmpty && deviceBans.isEmpty) const Text('No bans loaded.', style: TextStyle(color: Color(0xFF7B6A86), fontSize: 12, fontWeight: FontWeight.w700)),
    ])),
  ]);
}

class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({required this.reviews});
  final List<SuperOwnerReviewItem> reviews;
  @override
  Widget build(BuildContext context) => _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _PanelTitle(title: 'Review queues', subtitle: 'Custom backgrounds, reports, media safety and pending approvals'),
    const SizedBox(height: 12),
    if (reviews.isEmpty) const Text('No review items loaded.', style: TextStyle(color: Color(0xFF7B6A86), fontSize: 12, fontWeight: FontWeight.w700)) else ...reviews.map((item) => _MiniRecord(icon: Icons.fact_check_rounded, title: item.title, subtitle: item.reason, trailing: item.status)),
  ]));
}

class _LogsSection extends StatelessWidget {
  const _LogsSection({required this.logs});
  final List<SuperOwnerLogItem> logs;
  @override
  Widget build(BuildContext context) => _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _PanelTitle(title: 'Audit logs', subtitle: 'Sensitive actions remain reason-required and audit logged'),
    const SizedBox(height: 12),
    if (logs.isEmpty) const Text('No audit logs loaded.', style: TextStyle(color: Color(0xFF7B6A86), fontSize: 12, fontWeight: FontWeight.w700)) else ...logs.take(30).map((log) => _MiniRecord(icon: Icons.receipt_long_rounded, title: log.action, subtitle: log.reason.isEmpty ? 'Actor ${log.actorUserId ?? '-'} → Target ${log.targetUserId ?? '-'}' : log.reason, trailing: log.resourceType ?? 'audit')),
  ]));
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFEDE3D7)), boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 8))]), child: child);
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Color(0xFF251538), fontSize: 15.5, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, height: 1.2, fontWeight: FontWeight.w700))]);
}

class _MiniRecord extends StatelessWidget {
  const _MiniRecord({required this.icon, required this.title, required this.subtitle, required this.trailing});
  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFFAF7F1), borderRadius: BorderRadius.circular(18)), child: Row(children: [Icon(icon, color: const Color(0xFF8C5CF6), size: 18), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF251538), fontSize: 12.5, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 10.5, fontWeight: FontWeight.w700))])), const SizedBox(width: 6), _StatusPill(text: trailing, color: const Color(0xFF12C7B7))]));
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8), decoration: BoxDecoration(color: const Color(0xFF251538), borderRadius: BorderRadius.circular(999)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: Colors.white, size: 15), const SizedBox(width: 5), Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900))])));
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.busy, required this.label, required this.icon, required this.onPressed});
  final bool busy;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: busy ? null : onPressed, icon: Icon(icon, size: 17), label: Text(busy ? 'Saving...' : label), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF251538), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)))));
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white24)), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(value, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w700))]));
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4), decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)), child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w900)));
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => _Panel(child: Column(children: [Icon(icon, color: const Color(0xFF8C5CF6), size: 34), const SizedBox(height: 10), Text(title, style: const TextStyle(color: Color(0xFF251538), fontSize: 14, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w700))]));
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(22), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline_rounded, color: Color(0xFFE84C72), size: 38), const SizedBox(height: 10), Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF251538), fontSize: 13, fontWeight: FontWeight.w800)), const SizedBox(height: 14), _SmallButton(label: 'Retry', icon: Icons.refresh_rounded, onTap: onRetry)])));
}
