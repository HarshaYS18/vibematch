import 'dart:convert';

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
  final ControlCenterApiService _api = ControlCenterApiService();
  final TextEditingController _track = TextEditingController(text: 'vip');
  final TextEditingController _ruleTitle = TextEditingController(
    text: 'VIP Levels',
  );
  final TextEditingController _ruleLevels = TextEditingController(
    text: '[{"level":1,"required_exp":100000}]',
  );
  final TextEditingController _categoryKey = TextEditingController(
    text: 'avatar_frame',
  );
  final TextEditingController _categoryLabel = TextEditingController(
    text: 'Avatar Frames',
  );
  final TextEditingController _itemId = TextEditingController(
    text: 'frame_example',
  );
  final TextEditingController _itemName = TextEditingController(
    text: 'Example Frame',
  );
  final TextEditingController _itemCategory = TextEditingController(
    text: 'avatar_frame',
  );
  final TextEditingController _itemType = TextEditingController(
    text: 'avatar_frame',
  );
  final TextEditingController _itemPrice = TextEditingController(text: '0');
  final TextEditingController _itemAssetUrl = TextEditingController();
  final TextEditingController _targetUserId = TextEditingController();
  final TextEditingController _reason = TextEditingController(
    text: 'Control Center source-of-truth update',
  );

  List<ControlCenterEconomyRuleSet> _rules = const [];
  List<ControlCenterStoreCategory> _categories = const [];
  List<ControlCenterStoreItem> _items = const [];
  StealthState? _stealth;
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
      _track,
      _ruleTitle,
      _ruleLevels,
      _categoryKey,
      _categoryLabel,
      _itemId,
      _itemName,
      _itemCategory,
      _itemType,
      _itemPrice,
      _itemAssetUrl,
      _targetUserId,
      _reason,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final results = await Future.wait([
        _api.loadEconomyRuleSets(),
        _api.loadStoreCategories(),
        _api.loadStoreItems(),
        _api.loadMyStealthState(),
      ]);
      if (!mounted) return;
      setState(() {
        _rules = results[0] as List<ControlCenterEconomyRuleSet>;
        _categories = results[1] as List<ControlCenterStoreCategory>;
        _items = results[2] as List<ControlCenterStoreItem>;
        _stealth = results[3] as StealthState;
      });
    } catch (error) {
      _toast(error.toString(), danger: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveRule() async {
    try {
      final decoded = jsonDecode(_ruleLevels.text.trim());
      final levels = decoded is List
          ? decoded
                .whereType<Map>()
                .map((item) => item.cast<String, dynamic>())
                .toList(growable: false)
          : <Map<String, dynamic>>[];
      await _api.updateEconomyRuleSet(
        trackKey: _track.text.trim(),
        title: _ruleTitle.text.trim(),
        levels: levels,
        reason: _reason.text.trim(),
      );
      _toast('Economy rule set published');
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
        'reason': _reason.text.trim(),
      });
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
        'category': _itemCategory.text.trim(),
        'item_type': _itemType.text.trim(),
        'price_coins': int.tryParse(_itemPrice.text.trim()) ?? 0,
        'cdn_asset_url': _itemAssetUrl.text.trim().isEmpty
            ? null
            : _itemAssetUrl.text.trim(),
        'reason': _reason.text.trim(),
      });
      _toast('Store item saved');
      await _load();
    } catch (error) {
      _toast(error.toString(), danger: true);
    }
  }

  Future<void> _toggleStealth(bool enabled) async {
    try {
      final next = await _api.toggleMyStealth(
        enabled: enabled,
        reason: _reason.text.trim(),
      );
      setState(() => _stealth = next);
      _toast('Stealth updated');
    } catch (error) {
      _toast(error.toString(), danger: true);
    }
  }

  Future<void> _grantStealth(bool enabled) async {
    final target = int.tryParse(_targetUserId.text.trim());
    if (target == null) return _toast('Enter a backend user ID', danger: true);
    try {
      await _api.grantStealth(
        targetUserId: target,
        enabled: enabled,
        reason: _reason.text.trim(),
      );
      _toast(enabled ? 'Stealth granted' : 'Stealth revoked');
    } catch (error) {
      _toast(error.toString(), danger: true);
    }
  }

  void _toast(String message, {bool danger = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: danger
            ? const Color(0xFFE84C72)
            : const Color(0xFF12C7B7),
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
        title: const Text('Economy & Store Source'),
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              children: [
                _Section(
                  title: 'Economy Rules',
                  children: [
                    _SummaryLine(text: '${_rules.length} rule sets loaded'),
                    ..._rules
                        .take(6)
                        .map(
                          (rule) => _SummaryLine(
                            text:
                                '${rule.trackKey} v${rule.version} · ${rule.levelCount} levels',
                          ),
                        ),
                    _Field(controller: _track, label: 'Track key'),
                    _Field(controller: _ruleTitle, label: 'Rule title'),
                    _Field(
                      controller: _ruleLevels,
                      label: 'Levels JSON',
                      maxLines: 4,
                    ),
                    _ActionButton(
                      label: 'Publish Rule Set',
                      onPressed: _saveRule,
                    ),
                  ],
                ),
                _Section(
                  title: 'Store Catalog',
                  children: [
                    _SummaryLine(
                      text:
                          '${_categories.length} categories · ${_items.length} items',
                    ),
                    _Field(controller: _categoryKey, label: 'Category key'),
                    _Field(controller: _categoryLabel, label: 'Category label'),
                    _ActionButton(
                      label: 'Save Category',
                      onPressed: _saveCategory,
                    ),
                    const Divider(height: 24),
                    _Field(controller: _itemId, label: 'Item ID'),
                    _Field(controller: _itemName, label: 'Item name'),
                    _Field(controller: _itemCategory, label: 'Category'),
                    _Field(controller: _itemType, label: 'Item type'),
                    _Field(
                      controller: _itemPrice,
                      label: 'Price coins',
                      keyboardType: TextInputType.number,
                    ),
                    _Field(controller: _itemAssetUrl, label: 'CDN asset URL'),
                    _ActionButton(label: 'Save Item', onPressed: _saveItem),
                  ],
                ),
                _Section(
                  title: 'Stealth',
                  children: [
                    _SummaryLine(
                      text:
                          'Mine: ${_stealth?.enabled == true ? 'enabled' : 'off'} · allowed: ${_stealth?.canUseStealth == true ? 'yes' : 'no'}',
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            label: 'Enable Mine',
                            onPressed: () => _toggleStealth(true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ActionButton(
                            label: 'Disable Mine',
                            onPressed: () => _toggleStealth(false),
                          ),
                        ),
                      ],
                    ),
                    _Field(
                      controller: _targetUserId,
                      label: 'Target backend user ID',
                      keyboardType: TextInputType.number,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            label: 'Grant',
                            onPressed: () => _grantStealth(true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ActionButton(
                            label: 'Revoke',
                            onPressed: () => _grantStealth(false),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                _Field(controller: _reason, label: 'Audit reason'),
              ],
            ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
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
    this.maxLines = 1,
    this.keyboardType,
  });
  final TextEditingController controller;
  final String label;
  final int maxLines;
  final TextInputType? keyboardType;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    return FilledButton(onPressed: onPressed, child: Text(label));
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF7B6A86),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
