import 'package:flutter/material.dart';

import '../data/control_center_api_service.dart';

class EconomyStoreControlCenterPage extends StatefulWidget {
  const EconomyStoreControlCenterPage({super.key});

  @override
  State<EconomyStoreControlCenterPage> createState() =>
      _EconomyStoreControlCenterPageState();
}

class _EconomyStoreControlCenterPageState
    extends State<EconomyStoreControlCenterPage> {
  static const _tracks = <String>['vip', 'svip', 'send', 'receive', 'room'];
  static const _storeItemTypes = <String>[
    'chat_bubble',
    'avatar_frame',
    'entrance_effect',
    'profile_decoration',
    'text_bubble',
    'name_gradient',
    'special_custom_id',
    'room_background',
    'gift',
    'gift_category',
    'love_bond_card',
    'event_asset',
    'badge',
    'theme',
    'profile_theme',
  ];

  final ControlCenterApiService _api = ControlCenterApiService();
  final TextEditingController _ruleTitle = TextEditingController();
  final TextEditingController _requiredCoins = TextEditingController();
  final TextEditingController _coinsPerExp = TextEditingController(text: '1');
  final TextEditingController _secondsPerExp = TextEditingController(
    text: '60',
  );
  final TextEditingController _timeExpCap = TextEditingController(text: '0');
  final TextEditingController _categoryKey = TextEditingController();
  final TextEditingController _categoryLabel = TextEditingController();
  final TextEditingController _categoryOrder = TextEditingController(text: '0');
  final TextEditingController _itemId = TextEditingController();
  final TextEditingController _itemName = TextEditingController();
  final TextEditingController _itemPrice = TextEditingController(text: '0');
  final TextEditingController _itemAssetUrl = TextEditingController();
  final TextEditingController _itemIconUrl = TextEditingController();
  final TextEditingController _itemOrder = TextEditingController(text: '0');
  final TextEditingController _assetTargetUser = TextEditingController();
  final TextEditingController _reason = TextEditingController(
    text: 'Control Center source-of-truth update',
  );

  List<ControlCenterEconomyRuleSet> _rules = const [];
  List<ControlCenterStoreCategory> _categories = const [];
  List<ControlCenterStoreItem> _items = const [];
  String _selectedTrack = 'vip';
  int _selectedLevel = 1;
  String _selectedCategory = 'avatar_frame';
  String _selectedItemType = 'avatar_frame';
  String? _selectedGrantItemId;
  bool _categoryActive = true;
  bool _itemActive = true;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.close();
    for (final controller in [
      _ruleTitle,
      _requiredCoins,
      _coinsPerExp,
      _secondsPerExp,
      _timeExpCap,
      _categoryKey,
      _categoryLabel,
      _categoryOrder,
      _itemId,
      _itemName,
      _itemPrice,
      _itemAssetUrl,
      _itemIconUrl,
      _itemOrder,
      _assetTargetUser,
      _reason,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  ControlCenterEconomyRuleSet? get _selectedRule {
    for (final rule in _rules) {
      if (rule.trackKey == _selectedTrack) return rule;
    }
    return _rules.isEmpty ? null : _rules.first;
  }

  List<ControlCenterEconomyRuleLevel> get _selectedLevels =>
      _selectedRule?.levels ?? const <ControlCenterEconomyRuleLevel>[];

  List<ControlCenterStoreItem> get _itemsForSelectedCategory => _items
      .where((item) => item.category == _selectedCategory)
      .toList(growable: false);

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final results = await Future.wait([
        _api.loadEconomyRuleSets(),
        _api.loadStoreCategories(),
        _api.loadStoreItems(),
      ]);
      if (!mounted) return;
      setState(() {
        _rules = results[0] as List<ControlCenterEconomyRuleSet>;
        _categories = results[1] as List<ControlCenterStoreCategory>;
        _items = results[2] as List<ControlCenterStoreItem>;
        _syncEconomySelection();
        _syncStoreSelection();
      });
    } catch (error) {
      _toast(error.toString(), danger: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _syncEconomySelection() {
    final rule = _selectedRule;
    if (rule == null) return;
    _ruleTitle.text = rule.title;
    if (rule.levels.isEmpty) {
      _selectedLevel = 1;
      _requiredCoins.text = '0';
      return;
    }
    if (!rule.levels.any((level) => level.level == _selectedLevel)) {
      _selectedLevel = rule.levels.first.level;
    }
    final level = rule.levels.firstWhere(
      (item) => item.level == _selectedLevel,
      orElse: () => rule.levels.first,
    );
    _requiredCoins.text =
        '${level.requiredCoinValue == 0 ? level.requiredExp : level.requiredCoinValue}';
  }

  void _syncStoreSelection() {
    if (_categories.isNotEmpty &&
        !_categories.any((category) => category.key == _selectedCategory)) {
      _selectedCategory = _categories.first.key;
    }
    _categoryKey.text = _selectedCategory;
    final category = _categories.where((item) => item.key == _selectedCategory);
    if (category.isNotEmpty) {
      final current = category.first;
      _categoryLabel.text = current.label;
      _categoryOrder.text = '${current.sortOrder}';
      _categoryActive = current.active;
    }
    _selectedItemType = _selectedCategory;
  }

  Future<void> _saveSelectedRuleLevel() async {
    final rule = _selectedRule;
    if (rule == null) return _toast('No economy rule set loaded', danger: true);
    final requiredCoins = int.tryParse(_requiredCoins.text.trim());
    if (requiredCoins == null || requiredCoins < 0) {
      return _toast('Enter a valid required coin value', danger: true);
    }
    final nextLevels = rule.levels
        .map((level) {
          if (level.level == _selectedLevel) {
            return level.toRuleJson(requiredCoins: requiredCoins);
          }
          return level.toRuleJson();
        })
        .toList(growable: false);
    try {
      await _api.updateEconomyRuleSet(
        trackKey: _selectedTrack,
        title: _ruleTitle.text.trim().isEmpty
            ? rule.title
            : _ruleTitle.text.trim(),
        levels: nextLevels,
        reason: _reason.text.trim(),
      );
      _toast('Economy rule saved');
      await _load();
    } catch (error) {
      _toast(error.toString(), danger: true);
    }
  }

  Future<void> _saveCategory() async {
    try {
      await _api.upsertStoreCategory({
        'category_key': _categoryKey.text.trim(),
        'label': _categoryLabel.text.trim(),
        'sort_order': int.tryParse(_categoryOrder.text.trim()) ?? 0,
        'is_active': _categoryActive,
        'reason': _reason.text.trim(),
      });
      _selectedCategory = _categoryKey.text.trim();
      _toast('Store category saved');
      await _load();
    } catch (error) {
      _toast(error.toString(), danger: true);
    }
  }

  Future<void> _saveItem() async {
    try {
      await _api.upsertStoreItem({
        'item_id': _itemId.text.trim(),
        'name': _itemName.text.trim(),
        'category': _selectedCategory,
        'item_type': _selectedItemType,
        'price_coins': int.tryParse(_itemPrice.text.trim()) ?? 0,
        'cdn_asset_url': _nullIfEmpty(_itemAssetUrl.text),
        'thumbnail_url': _nullIfEmpty(_itemIconUrl.text),
        'sort_order': int.tryParse(_itemOrder.text.trim()) ?? 0,
        'is_active': _itemActive,
        'reason': _reason.text.trim(),
      });
      _toast('Store item saved');
      await _load();
    } catch (error) {
      _toast(error.toString(), danger: true);
    }
  }

  void _loadItemIntoForm(ControlCenterStoreItem item) {
    setState(() {
      _selectedCategory = item.category;
      _selectedItemType = item.itemType;
      _itemId.text = item.itemId;
      _itemName.text = item.name;
      _itemPrice.text = '${item.priceCoins}';
      _itemAssetUrl.text = item.assetUrl ?? item.imageUrl ?? '';
      _itemIconUrl.text = item.thumbnailUrl ?? '';
      _itemOrder.text = '${item.sortOrder}';
      _itemActive = item.active;
      _syncStoreSelection();
    });
  }

  void _toast(String message, {bool danger = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.replaceFirst('Exception: ', '')),
        backgroundColor: danger
            ? const Color(0xFFE84C72)
            : const Color(0xFF12C7B7),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF7F1),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFAF7F1),
          foregroundColor: const Color(0xFF251538),
          elevation: 0,
          title: const Text(
            'Source Control Center',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          bottom: const TabBar(
            labelColor: Color(0xFF251538),
            unselectedLabelColor: Color(0xFF8C8198),
            indicatorColor: Color(0xFFFFC857),
            tabs: [
              Tab(text: 'Economy'),
              Tab(text: 'Store'),
              Tab(text: 'Asset Send'),
            ],
          ),
        ),
        body: _busy
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildEconomyPage(),
                  _buildStorePage(),
                  _buildAssetSendPage(),
                ],
              ),
      ),
    );
  }

  Widget _buildEconomyPage() {
    final rule = _selectedRule;
    final levels = _selectedLevels;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        _HeroPanel(
          icon: Icons.query_stats_rounded,
          title: 'Economy Rules',
          subtitle:
              'VIP, SVIP, sent, received and room level thresholds are backend rule sets.',
        ),
        _Panel(
          title: 'VIP / SVIP / Level Thresholds',
          children: [
            _Dropdown<String>(
              label: 'Rule track',
              value: _selectedTrack,
              items: _tracks,
              itemLabel: (track) => track.toUpperCase(),
              onChanged: (value) {
                setState(() {
                  _selectedTrack = value;
                  _syncEconomySelection();
                });
              },
            ),
            _Field(controller: _ruleTitle, label: 'Rule title'),
            if (levels.isNotEmpty)
              _Dropdown<int>(
                label: 'Level',
                value: _selectedLevel,
                items: levels.map((level) => level.level).toList(),
                itemLabel: (level) => 'Level $level',
                onChanged: (value) {
                  setState(() {
                    _selectedLevel = value;
                    _syncEconomySelection();
                  });
                },
              ),
            _Field(
              controller: _requiredCoins,
              label: _selectedTrack == 'vip' || _selectedTrack == 'svip'
                  ? 'Coins required for selected level'
                  : 'EXP / coins required for selected level',
              keyboardType: TextInputType.number,
            ),
            _ActionButton(
              icon: Icons.publish_rounded,
              label: 'Publish Selected Level Rule',
              onPressed: rule == null ? null : _saveSelectedRuleLevel,
            ),
          ],
        ),
        _Panel(
          title: 'Sent / Received EXP Timing',
          subtitle:
              'These controls need a backend timing-rule endpoint before they can save.',
          children: [
            _Field(
              controller: _coinsPerExp,
              label: 'Coins required for 1 EXP point',
              enabled: false,
            ),
            _Field(
              controller: _secondsPerExp,
              label: 'Time required for 1 EXP point',
              enabled: false,
            ),
            _Field(
              controller: _timeExpCap,
              label: 'Max EXP cap for time spent',
              enabled: false,
            ),
          ],
        ),
        _Panel(
          title: 'Ranking Display Toggles',
          subtitle:
              'Display-period toggles are ready in UI; backend config persistence is the next pass.',
          children: const [
            _DisabledSwitch(label: 'Daily'),
            _DisabledSwitch(label: 'Weekly'),
            _DisabledSwitch(label: 'Monthly'),
            _DisabledSwitch(label: 'Yearly'),
            _DisabledSwitch(label: 'Custom'),
            _DisabledSwitch(label: 'Life-Time'),
          ],
        ),
      ],
    );
  }

  Widget _buildStorePage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        _HeroPanel(
          icon: Icons.storefront_rounded,
          title: 'Store Catalog',
          subtitle:
              'Categories, order, prices and CDN assets are saved through backend Control Center APIs.',
        ),
        _Panel(
          title: 'Category',
          children: [
            if (_categories.isNotEmpty)
              _Dropdown<String>(
                label: 'Category list',
                value: _selectedCategory,
                items: _categories.map((item) => item.key).toList(),
                itemLabel: (key) {
                  final category = _categories.firstWhere(
                    (item) => item.key == key,
                  );
                  return '${category.sortOrder}. ${category.label}';
                },
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                    _syncStoreSelection();
                  });
                },
              ),
            _Field(controller: _categoryKey, label: 'Category key'),
            _Field(controller: _categoryLabel, label: 'Category name'),
            _Field(
              controller: _categoryOrder,
              label: 'Order in list',
              keyboardType: TextInputType.number,
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _categoryActive,
              onChanged: (value) => setState(() => _categoryActive = value),
              title: const Text(
                'Enable category tab',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            _ActionButton(
              icon: Icons.save_rounded,
              label: 'Save Category',
              onPressed: _saveCategory,
            ),
          ],
        ),
        _Panel(
          title: 'Item',
          children: [
            if (_itemsForSelectedCategory.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _itemsForSelectedCategory
                    .take(18)
                    .map(
                      (item) => ActionChip(
                        avatar: Icon(
                          item.active
                              ? Icons.check_circle_rounded
                              : Icons.pause_circle_rounded,
                          color: item.active
                              ? const Color(0xFF12C7B7)
                              : const Color(0xFFE84C72),
                        ),
                        label: Text(item.name),
                        onPressed: () => _loadItemIntoForm(item),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 10),
            _Field(controller: _itemId, label: 'Item ID'),
            _Field(controller: _itemName, label: 'Item name'),
            _Dropdown<String>(
              label: 'Asset type',
              value: _selectedItemType,
              items: _storeItemTypes,
              itemLabel: (type) => type.replaceAll('_', ' '),
              onChanged: (value) => setState(() => _selectedItemType = value),
            ),
            _Field(
              controller: _itemPrice,
              label: 'Price',
              keyboardType: TextInputType.number,
            ),
            _Field(controller: _itemAssetUrl, label: 'Asset URL'),
            _Field(controller: _itemIconUrl, label: 'Display icon URL'),
            _Field(
              controller: _itemOrder,
              label: 'Order in category',
              keyboardType: TextInputType.number,
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _itemActive,
              onChanged: (value) => setState(() => _itemActive = value),
              title: const Text(
                'Enable item',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            _ActionButton(
              icon: Icons.inventory_2_rounded,
              label: 'Save Item',
              onPressed: _saveItem,
            ),
          ],
        ),
        _Field(controller: _reason, label: 'Audit reason'),
      ],
    );
  }

  Widget _buildAssetSendPage() {
    final grantTypes = _categories.map((item) => item.key).toList();
    final grantItems = _selectedGrantItemId == null
        ? _itemsForSelectedCategory
        : _items
              .where((item) => item.itemId == _selectedGrantItemId)
              .toList(growable: false);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        _HeroPanel(
          icon: Icons.redeem_rounded,
          title: 'Send Asset',
          subtitle:
              'The UI is prepared. Granting needs a backend inventory-grant endpoint before it is enabled.',
        ),
        _Panel(
          title: 'Grant Preview',
          subtitle:
              'Search by public ID, custom ID or username needs the alphanumeric custom-ID migration first.',
          children: [
            _Field(
              controller: _assetTargetUser,
              label: 'User public/custom ID or username',
              enabled: false,
            ),
            if (grantTypes.isNotEmpty)
              _Dropdown<String>(
                label: 'Asset type',
                value: _selectedCategory,
                items: grantTypes,
                itemLabel: (type) => type.replaceAll('_', ' '),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                    _selectedGrantItemId = null;
                    _syncStoreSelection();
                  });
                },
              ),
            if (_itemsForSelectedCategory.isNotEmpty)
              _Dropdown<String>(
                label: 'Asset',
                value:
                    _selectedGrantItemId ??
                    _itemsForSelectedCategory.first.itemId,
                items: _itemsForSelectedCategory
                    .map((item) => item.itemId)
                    .toList(),
                itemLabel: (itemId) {
                  final item = _itemsForSelectedCategory.firstWhere(
                    (entry) => entry.itemId == itemId,
                  );
                  return item.name;
                },
                onChanged: (value) =>
                    setState(() => _selectedGrantItemId = value),
              ),
            ...grantItems.take(1).map((item) => _AssetPreview(item: item)),
            _ActionButton(
              icon: Icons.lock_clock_rounded,
              label: 'Grant Asset - Backend Endpoint Required',
              onPressed: null,
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF251538),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFFC857), size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
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

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.children, this.subtitle});

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFEDE3D7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF251538),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: const TextStyle(
                  color: Color(0xFF7B6A86),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ],
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: enabled ? Colors.white : const Color(0xFFF1EAE4),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> items;
  final String Function(T item) itemLabel;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeValue = items.contains(value) && items.isNotEmpty
        ? value
        : items.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: DropdownButtonFormField<T>(
        key: ValueKey<String>('$label-$safeValue-${items.length}'),
        initialValue: safeValue,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
        items: items
            .map(
              (item) => DropdownMenuItem<T>(
                value: item,
                child: Text(itemLabel(item)),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _DisabledSwitch extends StatelessWidget {
  const _DisabledSwitch({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      value: true,
      onChanged: null,
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

class _AssetPreview extends StatelessWidget {
  const _AssetPreview({required this.item});

  final ControlCenterStoreItem item;

  @override
  Widget build(BuildContext context) {
    final url = item.displayAssetUrl;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F1EA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 58,
              height: 58,
              color: const Color(0xFF251538),
              child: url.isEmpty
                  ? const Icon(Icons.image_rounded, color: Colors.white70)
                  : Image.network(url, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    color: Color(0xFF251538),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${item.itemType} - ${item.priceCoins} coins',
                  style: const TextStyle(
                    color: Color(0xFF7B6A86),
                    fontSize: 12,
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

String? _nullIfEmpty(String value) {
  final text = value.trim();
  return text.isEmpty ? null : text;
}
