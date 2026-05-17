import 'dart:async';

import 'package:flutter/material.dart';

import '../data/gift_catalog_admin_api_service.dart';

class GiftCatalogEditorPage extends StatefulWidget {
  const GiftCatalogEditorPage({super.key});

  @override
  State<GiftCatalogEditorPage> createState() => _GiftCatalogEditorPageState();
}

class _GiftCatalogEditorPageState extends State<GiftCatalogEditorPage> {
  final GiftCatalogAdminApiService _api = const GiftCatalogAdminApiService();

  Map<String, dynamic>? _catalog;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  List<Map<String, dynamic>> get _categories {
    final items = (_catalog?['categories'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList();
    items.sort((a, b) {
      final left = _int(a['sort_order']);
      final right = _int(b['sort_order']);
      if (left != right) return left.compareTo(right);
      return '${a['key']}'.compareTo('${b['key']}');
    });
    return items;
  }

  List<Map<String, dynamic>> get _items {
    final raw = _catalog?['items'] as List<dynamic>? ??
        _catalog?['all'] as List<dynamic>? ??
        const <dynamic>[];
    final items = raw.whereType<Map<String, dynamic>>().toList();
    items.sort((a, b) {
      final left = _int(a['sort_order']);
      final right = _int(b['sort_order']);
      if (left != right) return left.compareTo(right);
      return '${a['id']}'.compareTo('${b['id']}');
    });
    return items;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog = await _api.getCatalog();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
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

  Future<String?> _reasonDialog({
    required String title,
    required String hint,
  }) async {
    final controller = TextEditingController(text: hint);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason required',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final reason = controller.text.trim();
              if (reason.length < 3) return;
              Navigator.pop(context, reason);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _runMutation(
    Future<void> Function(String reason) action,
    String title,
    String hint,
  ) async {
    final reason = await _reasonDialog(title: title, hint: hint);
    if (reason == null || reason.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await action(reason);
      if (!mounted) return;
      _showSnack('Saved');
      await _load();
    } catch (error) {
      if (!mounted) return;
      _showSnack(error.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _seedDefaults() async {
    await _runMutation(
      (reason) async => _api.seedDefaults(reason: reason),
      'Seed default gift catalog',
      'Initial admin DB gift catalog seed',
    );
  }

  Future<void> _toggleCategory(Map<String, dynamic> category) async {
    final key = '${category['key']}';
    final enabled = !_bool(category['is_enabled'], fallback: true);
    await _runMutation(
      (reason) async => _api.setCategoryEnabled(
        categoryKey: key,
        enabled: enabled,
        reason: reason,
      ),
      '${enabled ? 'Enable' : 'Disable'} category',
      '${enabled ? 'Enable' : 'Disable'} gift category $key',
    );
  }

  Future<void> _toggleGift(Map<String, dynamic> gift) async {
    final id = '${gift['id']}';
    final enabled = !_bool(gift['is_enabled'], fallback: true);
    await _runMutation(
      (reason) async => _api.setGiftEnabled(
        giftId: id,
        enabled: enabled,
        reason: reason,
      ),
      '${enabled ? 'Enable' : 'Disable'} gift',
      '${enabled ? 'Enable' : 'Disable'} gift $id',
    );
  }

  Future<void> _openCategoryEditor([Map<String, dynamic>? category]) async {
    final keyController = TextEditingController(text: '${category?['key'] ?? ''}');
    final labelController = TextEditingController(text: '${category?['label'] ?? ''}');
    final sortController = TextEditingController(text: '${category?['sort_order'] ?? 500}');
    final reasonController = TextEditingController(
      text: category == null ? 'Create gift category' : 'Update gift category',
    );
    var enabled = _bool(category?['is_enabled'], fallback: true);

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(
            category == null ? 'Add category' : 'Edit category',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: keyController,
                    enabled: category == null,
                    decoration: const InputDecoration(
                      labelText: 'Category key',
                      helperText: 'Example: cricket, premium, lucky',
                    ),
                  ),
                  TextField(
                    controller: labelController,
                    decoration: const InputDecoration(labelText: 'Display label'),
                  ),
                  TextField(
                    controller: sortController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Sort order'),
                  ),
                  SwitchListTile(
                    value: enabled,
                    onChanged: (value) => setLocal(() => enabled = value),
                    title: const Text('Enabled'),
                  ),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Reason required'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (shouldSave == true) {
      setState(() => _saving = true);
      try {
        await _api.upsertCategory(
          key: _cleanKey(keyController.text),
          label: labelController.text.trim(),
          enabled: enabled,
          sortOrder: int.tryParse(sortController.text.trim()) ?? 500,
          reason: reasonController.text.trim(),
        );
        if (!mounted) return;
        _showSnack('Category saved');
        await _load();
      } catch (error) {
        if (!mounted) return;
        _showSnack(error.toString().replaceFirst('Exception: ', ''), isError: true);
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }

    keyController.dispose();
    labelController.dispose();
    sortController.dispose();
    reasonController.dispose();
  }

  Future<void> _openGiftEditor([Map<String, dynamic>? gift]) async {
    if (_categories.isEmpty) {
      _showSnack('Create or seed at least one category before adding gifts.', isError: true);
      return;
    }

    final categoryKeys = _categories
        .map((category) => _cleanKey('${category['key']}'))
        .where((key) => key.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final firstCategoryKey = categoryKeys.isEmpty ? 'classic' : categoryKeys.first;
    var selectedCategoryKey = _cleanKey('${gift?['category'] ?? firstCategoryKey}');
    if (!categoryKeys.contains(selectedCategoryKey)) {
      selectedCategoryKey = firstCategoryKey;
    }
    var selectedDisplayMode = _cleanDisplayMode('${gift?['display_mode'] ?? 'normal'}');

    final giftIdController = TextEditingController(text: '${gift?['id'] ?? ''}');
    final nameController = TextEditingController(text: '${gift?['name'] ?? ''}');
    final giftTypeController = TextEditingController(text: '${gift?['gift_type'] ?? 'normal'}');
    final coinController = TextEditingController(text: '${gift?['coin_value'] ?? 0}');
    final minComboController = TextEditingController(text: '${gift?['min_combo'] ?? 1}');
    final maxComboController = TextEditingController(text: '${gift?['max_combo'] ?? 999}');
    final iconKeyController = TextEditingController(text: '${gift?['icon_key'] ?? ''}');
    final chatSymbolController = TextEditingController(text: '${gift?['chat_symbol'] ?? '🎁'}');
    final assetPathController = TextEditingController(text: '${gift?['asset_path'] ?? ''}');
    final videoAssetPathController = TextEditingController(text: '${gift?['video_asset_path'] ?? ''}');
    final cdnAssetPathController = TextEditingController(text: '${gift?['cdn_asset_path'] ?? ''}');
    final cdnVideoPathController = TextEditingController(text: '${gift?['cdn_video_path'] ?? ''}');
    final animationTypeController = TextEditingController(text: '${gift?['animation_type'] ?? 'image'}');
    final versionController = TextEditingController(text: '${gift?['version'] ?? 1}');
    final sortController = TextEditingController(text: '${gift?['sort_order'] ?? 500}');
    final maxMultiplierController = TextEditingController(text: '${gift?['max_multiplier'] ?? ''}');
    final reasonController = TextEditingController(text: gift == null ? 'Create gift item' : 'Update gift item');
    var enabled = _bool(gift?['is_enabled'], fallback: true);
    var slide = _bool(gift?['show_gift_slide'], fallback: true);
    var broadcast = _bool(gift?['show_premium_broadcast'], fallback: false);
    var flight = _bool(gift?['show_gift_flight'], fallback: true);

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(
            gift == null ? 'Add gift' : 'Edit gift',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(giftIdController, 'Gift ID', enabled: gift == null),
                  _field(nameController, 'Name'),
                  DropdownButtonFormField<String>(
                    value: selectedCategoryKey,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      helperText: 'Loaded from backend catalog categories',
                    ),
                    items: _categories.map((category) {
                      final key = _cleanKey('${category['key']}');
                      final label = '${category['label'] ?? key}';
                      final enabledText = _bool(category['is_enabled'], fallback: true) ? '' : ' (disabled)';
                      return DropdownMenuItem<String>(
                        value: key,
                        child: Text('$label • $key$enabledText'),
                      );
                    }).toList(growable: false),
                    onChanged: (value) {
                      if (value == null || value.trim().isEmpty) return;
                      setLocal(() => selectedCategoryKey = value);
                    },
                  ),
                  DropdownButtonFormField<String>(
                    value: selectedDisplayMode,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Display mode',
                      helperText: 'Normal = current size, Large 80% = big aspect-ratio-safe render',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'normal',
                        child: Text('Normal / current display'),
                      ),
                      DropdownMenuItem(
                        value: 'large_80',
                        child: Text('Large 80% screen display'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setLocal(() => selectedDisplayMode = _cleanDisplayMode(value));
                    },
                  ),
                  _field(giftTypeController, 'Gift type: normal / lucky'),
                  _field(coinController, 'Coin value', number: true),
                  Row(
                    children: [
                      Expanded(child: _field(minComboController, 'Minimum combo allowed', number: true)),
                      const SizedBox(width: 10),
                      Expanded(child: _field(maxComboController, 'Maximum combo allowed', number: true)),
                    ],
                  ),
                  _field(iconKeyController, 'Icon key'),
                  _field(chatSymbolController, 'Chat symbol'),
                  _field(assetPathController, 'Local asset path fallback'),
                  _field(videoAssetPathController, 'Local video path fallback'),
                  _field(cdnAssetPathController, 'CDN icon path or full URL'),
                  _field(cdnVideoPathController, 'CDN video path or full URL'),
                  _field(animationTypeController, 'Animation type: image / video'),
                  _field(versionController, 'Version', number: true),
                  _field(sortController, 'Sort order', number: true),
                  _field(maxMultiplierController, 'Max multiplier for lucky gift', number: true),
                  SwitchListTile(
                    value: enabled,
                    onChanged: (v) => setLocal(() => enabled = v),
                    title: const Text('Enabled'),
                  ),
                  SwitchListTile(
                    value: slide,
                    onChanged: (v) => setLocal(() => slide = v),
                    title: const Text('Show gift slide'),
                  ),
                  SwitchListTile(
                    value: broadcast,
                    onChanged: (v) => setLocal(() => broadcast = v),
                    title: const Text('Premium broadcast'),
                  ),
                  SwitchListTile(
                    value: flight,
                    onChanged: (v) => setLocal(() => flight = v),
                    title: const Text('Gift flight'),
                  ),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Reason required'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (shouldSave == true) {
      final minCombo = int.tryParse(minComboController.text.trim()) ?? 1;
      final maxCombo = int.tryParse(maxComboController.text.trim()) ?? 999;
      if (minCombo < 1 || maxCombo < minCombo) {
        _showSnack('Max combo must be greater than or equal to min combo', isError: true);
      } else {
        setState(() => _saving = true);
        try {
          await _api.upsertGift({
            'gift_id': giftIdController.text.trim(),
            'name': nameController.text.trim(),
            'category_key': selectedCategoryKey,
            'gift_type': _cleanKey(giftTypeController.text),
            'coin_value': int.tryParse(coinController.text.trim()) ?? 0,
            'min_combo': minCombo,
            'max_combo': maxCombo,
            'icon_key': _nullable(iconKeyController.text),
            'chat_symbol': _nullable(chatSymbolController.text),
            'asset_path': _nullable(assetPathController.text),
            'video_asset_path': _nullable(videoAssetPathController.text),
            'cdn_asset_path': _nullable(cdnAssetPathController.text),
            'cdn_video_path': _nullable(cdnVideoPathController.text),
            'animation_type': _cleanKey(animationTypeController.text),
            'display_mode': selectedDisplayMode,
            'is_enabled': enabled,
            'show_gift_slide': slide,
            'show_premium_broadcast': broadcast,
            'show_gift_flight': flight,
            'version': int.tryParse(versionController.text.trim()) ?? 1,
            'sort_order': int.tryParse(sortController.text.trim()) ?? 500,
            'max_multiplier': maxMultiplierController.text.trim().isEmpty ? null : int.tryParse(maxMultiplierController.text.trim()),
            'metadata_json': null,
            'reason': reasonController.text.trim(),
          });
          if (!mounted) return;
          _showSnack('Gift saved');
          await _load();
        } catch (error) {
          if (!mounted) return;
          _showSnack(error.toString().replaceFirst('Exception: ', ''), isError: true);
        } finally {
          if (mounted) setState(() => _saving = false);
        }
      }
    }

    for (final controller in [
      giftIdController,
      nameController,
      giftTypeController,
      coinController,
      minComboController,
      maxComboController,
      iconKeyController,
      chatSymbolController,
      assetPathController,
      videoAssetPathController,
      cdnAssetPathController,
      cdnVideoPathController,
      animationTypeController,
      versionController,
      sortController,
      maxMultiplierController,
      reasonController,
    ]) {
      controller.dispose();
    }
  }

  TextField _field(
    TextEditingController controller,
    String label, {
    bool enabled = true,
    bool number = false,
  }) =>
      TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: label),
      );

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)),
          backgroundColor: isError ? const Color(0xFFE84C72) : const Color(0xFF251538),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7F1),
        foregroundColor: const Color(0xFF251538),
        elevation: 0,
        title: const Text('Gift Catalog Editor', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(onPressed: _saving ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      floatingActionButton: _saving
          ? const FloatingActionButton(
              onPressed: null,
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          : FloatingActionButton.extended(
              onPressed: () => _openGiftEditor(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Gift'),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  children: [
                    _HeaderCard(
                      source: '${_catalog?['source'] ?? 'unknown'}',
                      cdnBase: '${_catalog?['cdn_base_url'] ?? ''}',
                      itemCount: _items.length,
                      categoryCount: _categories.length,
                      onSeed: _saving ? null : _seedDefaults,
                      onAddCategory: _saving ? null : () => _openCategoryEditor(),
                    ),
                    const SizedBox(height: 16),
                    const _SectionTitle('Categories'),
                    const SizedBox(height: 8),
                    ..._categories.map(
                      (category) => _CategoryCard(
                        category: category,
                        onEdit: () => _openCategoryEditor(category),
                        onToggle: () => _toggleCategory(category),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _SectionTitle('Gifts'),
                    const SizedBox(height: 8),
                    ..._items.map(
                      (gift) => _GiftCard(
                        gift: gift,
                        onEdit: () => _openGiftEditor(gift),
                        onToggle: () => _toggleGift(gift),
                      ),
                    ),
                  ],
                ),
    );
  }

  String _cleanKey(String value) => value.trim().toLowerCase().replaceAll(' ', '_');

  String _cleanDisplayMode(String value) {
    final clean = value.trim().toLowerCase();
    return clean == 'large_80' ? 'large_80' : 'normal';
  }

  String? _nullable(String value) {
    final text = value.trim();
    return text.isEmpty || text == 'null' ? null : text;
  }

  int _int(dynamic value) => value is int ? value : int.tryParse('${value ?? ''}') ?? 0;

  bool _bool(dynamic value, {required bool fallback}) {
    if (value is bool) return value;
    final text = '${value ?? ''}'.toLowerCase();
    if (text == 'true' || text == '1') return true;
    if (text == 'false' || text == '0') return false;
    return fallback;
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.source,
    required this.cdnBase,
    required this.itemCount,
    required this.categoryCount,
    required this.onSeed,
    required this.onAddCategory,
  });

  final String source;
  final String cdnBase;
  final int itemCount;
  final int categoryCount;
  final VoidCallback? onSeed;
  final VoidCallback? onAddCategory;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: [Color(0xFF120D1F), Color(0xFF4A2A63), Color(0xFFFFC857)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Backend-owned gift catalog',
              style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Source: $source • Categories: $categoryCount • Gifts: $itemCount',
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              cdnBase.isEmpty ? 'CDN base not set' : cdnBase,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFFFF0A8), fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onSeed,
                  icon: const Icon(Icons.playlist_add_check_rounded),
                  label: const Text('Seed defaults'),
                ),
                OutlinedButton.icon(
                  onPressed: onAddCategory,
                  icon: const Icon(Icons.category_rounded),
                  label: const Text('Add category'),
                ),
              ],
            ),
          ],
        ),
      );
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.onEdit, required this.onToggle});

  final Map<String, dynamic> category;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final enabled = category['is_enabled'] == true;
    return _BaseCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: enabled ? const Color(0xFF12C7B7) : const Color(0xFF8C8198),
          child: const Icon(Icons.category_rounded, color: Colors.white),
        ),
        title: Text(
          '${category['label']}',
          style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF251538)),
        ),
        subtitle: Text('${category['key']} • sort ${category['sort_order']}'),
        trailing: Wrap(
          spacing: 6,
          children: [
            IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_rounded)),
            Switch(value: enabled, onChanged: (_) => onToggle()),
          ],
        ),
      ),
    );
  }
}

class _GiftCard extends StatelessWidget {
  const _GiftCard({required this.gift, required this.onEdit, required this.onToggle});

  final Map<String, dynamic> gift;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final enabled = gift['is_enabled'] == true;
    final imageUrl = '${gift['asset_url'] ?? ''}'.trim();
    final displayMode = '${gift['display_mode'] ?? 'normal'}';
    return _BaseCard(
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: const Color(0xFF251538),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl.isEmpty
                ? const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFFC857))
                : Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.card_giftcard_rounded,
                      color: Color(0xFFFFC857),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${gift['name']}',
                  style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF251538)),
                ),
                const SizedBox(height: 3),
                Text(
                  '${gift['id']} • ${gift['category']} • ${gift['coin_value']} coins • combo ${gift['min_combo'] ?? 1}-${gift['max_combo'] ?? 999}',
                  style: const TextStyle(color: Color(0xFF7B6A86), fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  'display $displayMode • ${gift['cdn_asset_path'] ?? 'no cdn icon'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF8C8198)),
                ),
              ],
            ),
          ),
          IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_rounded)),
          Switch(value: enabled, onChanged: (_) => onToggle()),
        ],
      ),
    );
  }
}

class _BaseCard extends StatelessWidget {
  const _BaseCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFEDE3D7)),
        ),
        child: child,
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(color: Color(0xFF251538), fontSize: 17, fontWeight: FontWeight.w900),
      );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFE84C72), size: 42),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
}
