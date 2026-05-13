import 'package:flutter/material.dart';

import '../../../../shared/gradient_names/gradient_name_style.dart';
import '../../../../shared/gradient_names/gradient_name_text.dart';
import 'store_models.dart';
import 'store_repository.dart';

class VmStorePage extends StatefulWidget {
  const VmStorePage({super.key});

  @override
  State<VmStorePage> createState() => _VmStorePageState();
}

class _VmStorePageState extends State<VmStorePage> {
  VmStoreTab _tab = VmStoreTab.store;
  VmStoreSection _section = VmStoreSection.frames;
  VmStoreUserState? _userState;
  List<VmStoreItem> _catalog = <VmStoreItem>[];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadStore();
  }

  Future<void> _loadStore() async {
    final userState = await VmStoreRepository.loadUserState();
    final catalog = await VmStoreRepository.loadCatalog(hasLoveRelationship: userState.hasLoveRelationship);
    if (!mounted) return;
    setState(() {
      _userState = userState;
      _catalog = catalog;
      _loading = false;
    });
  }

  List<VmStoreItem> get _visibleItems {
    final state = _userState;
    if (state == null) return <VmStoreItem>[];
    return _catalog.where((item) {
      if (item.section != _section) return false;
      if (_tab == VmStoreTab.mine) return state.owns(item.id);
      return true;
    }).toList();
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

  Future<void> _buyItem(VmStoreItem item) async {
    final state = _userState;
    if (state == null || _busy) return;
    setState(() => _busy = true);
    try {
      final next = await VmStoreRepository.buyItem(state, item);
      final catalog = await VmStoreRepository.loadCatalog(hasLoveRelationship: next.hasLoveRelationship);
      if (!mounted) return;
      setState(() {
        _userState = next;
        _catalog = catalog;
      });
      _toast('${item.title} purchased.');
    } on StateError catch (error) {
      _toast(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _equipItem(VmStoreItem item) async {
    final state = _userState;
    if (state == null || _busy) return;
    setState(() => _busy = true);
    try {
      final next = await VmStoreRepository.equipItem(state, item);
      if (!mounted) return;
      setState(() => _userState = next);
      _toast('${item.title} equipped.');
    } on StateError catch (error) {
      _toast(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unequipItem(VmStoreItem item) async {
    final state = _userState;
    if (state == null || _busy) return;
    setState(() => _busy = true);
    try {
      final next = await VmStoreRepository.unequipItem(state, item);
      if (!mounted) return;
      setState(() => _userState = next);
      _toast('${item.title} unequipped.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleLoveRelationshipForDebug() async {
    final state = _userState;
    if (state == null || _busy) return;
    final next = await VmStoreRepository.toggleLoveRelationshipForDebug(state);
    final catalog = await VmStoreRepository.loadCatalog(hasLoveRelationship: next.hasLoveRelationship);
    if (!mounted) return;
    setState(() {
      _userState = next;
      _catalog = catalog;
    });
    _toast(next.hasLoveRelationship ? 'Love card hidden because Lover bond exists.' : 'Love card available because no Lover bond exists.');
  }

  @override
  Widget build(BuildContext context) {
    final state = _userState;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: Column(
          children: [
            _StoreHeader(onBack: () => Navigator.pop(context)),
            if (_loading || state == null)
              const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFF251538))))
            else
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    _StoreHeroCard(
                      coinBalance: state.coinBalance,
                      hasLoveRelationship: state.hasLoveRelationship,
                      ownedCount: state.ownedItemIds.length,
                      onLoveDebugTap: _toggleLoveRelationshipForDebug,
                    ),
                    const SizedBox(height: 12),
                    _StoreTabs(selected: _tab, onSelected: (tab) => setState(() => _tab = tab)),
                    const SizedBox(height: 12),
                    _StoreSectionChips(selected: _section, onSelected: (section) => setState(() => _section = section)),
                    const SizedBox(height: 14),
                    _RemoteConfigNotice(section: _section),
                    const SizedBox(height: 14),
                    if (_visibleItems.isEmpty)
                      _StoreEmptyState(tab: _tab, section: _section)
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _visibleItems.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.68,
                        ),
                        itemBuilder: (context, index) {
                          final item = _visibleItems[index];
                          final owned = state.owns(item.id);
                          final equipped = state.inventory.any((entry) => entry.itemId == item.id && entry.isEquipped && !entry.isExpired);
                          return _StoreItemCard(
                            item: item,
                            owned: owned,
                            equipped: equipped,
                            busy: _busy,
                            onBuy: () => _buyItem(item),
                            onEquip: () => _equipItem(item),
                            onUnequip: () => _unequipItem(item),
                          );
                        },
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

class _StoreHeader extends StatelessWidget {
  const _StoreHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(10, 10, 16, 12),
      child: Row(
        children: [
          IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF251538), size: 28)),
          const Expanded(child: Text('Store', style: TextStyle(color: Color(0xFF251538), fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.4))),
        ],
      ),
    );
  }
}

class _StoreHeroCard extends StatelessWidget {
  const _StoreHeroCard({required this.coinBalance, required this.hasLoveRelationship, required this.ownedCount, required this.onLoveDebugTap});

  final int coinBalance;
  final bool hasLoveRelationship;
  final int ownedCount;
  final VoidCallback onLoveDebugTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _storePanelDecoration(radius: 30),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 52, height: 52, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFFC99A3B), Color(0xFFE84C72)])), child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 28)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Dynamic Store', style: TextStyle(color: Color(0xFF251538), fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
            const SizedBox(height: 3),
            Text('Coins: ${_formatCoins(coinBalance)} - Mine: $ownedCount items', style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 12, fontWeight: FontWeight.w800)),
          ])),
        ]),
        const SizedBox(height: 12),
        const Text('Items use remote asset/config keys so frames, effects, bubbles, backgrounds and gradient names can be updated later without an app update.', style: TextStyle(color: Color(0xFF7B6A86), fontSize: 12, height: 1.35, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        InkWell(
          onTap: onLoveDebugTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(color: hasLoveRelationship ? const Color(0xFFFFEAF2) : const Color(0xFFE9FBF8), borderRadius: BorderRadius.circular(18)),
            child: Row(children: [
              Icon(hasLoveRelationship ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: hasLoveRelationship ? const Color(0xFFE84C72) : const Color(0xFF12C7B7), size: 20),
              const SizedBox(width: 9),
              Expanded(child: Text(hasLoveRelationship ? 'Love Card availability: 0 because Lover bond already exists.' : 'Love Card availability: 1 because no Lover bond exists.', style: const TextStyle(color: Color(0xFF251538), fontSize: 11.5, fontWeight: FontWeight.w900))),
            ]),
          ),
        ),
      ]),
    );
  }

  static String _formatCoins(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toString();
  }
}

class _StoreTabs extends StatelessWidget {
  const _StoreTabs({required this.selected, required this.onSelected});

  final VmStoreTab selected;
  final ValueChanged<VmStoreTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFECE2D8))),
      child: Row(children: [
        Expanded(child: _TabButton(label: 'Store', active: selected == VmStoreTab.store, onTap: () => onSelected(VmStoreTab.store))),
        Expanded(child: _TabButton(label: 'Mine', active: selected == VmStoreTab.mine, onTap: () => onSelected(VmStoreTab.mine))),
      ]),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: active ? const Color(0xFF251538) : Colors.transparent, borderRadius: BorderRadius.circular(18)),
        child: Text(label, style: TextStyle(color: active ? Colors.white : const Color(0xFF6B5C72), fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _StoreSectionChips extends StatelessWidget {
  const _StoreSectionChips({required this.selected, required this.onSelected});

  final VmStoreSection selected;
  final ValueChanged<VmStoreSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: VmStoreSection.values.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final section = VmStoreSection.values[index];
          final active = section == selected;
          return InkWell(
            onTap: () => onSelected(section),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(color: active ? const Color(0xFF251538) : Colors.white, borderRadius: BorderRadius.circular(999), border: Border.all(color: active ? const Color(0xFF251538) : const Color(0xFFECE2D8))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(section.icon, size: 16, color: active ? Colors.white : const Color(0xFF6D5DF6)),
                const SizedBox(width: 6),
                Text(section.label, style: TextStyle(color: active ? Colors.white : const Color(0xFF4A2A63), fontSize: 12, fontWeight: FontWeight.w900)),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _RemoteConfigNotice extends StatelessWidget {
  const _RemoteConfigNotice({required this.section});

  final VmStoreSection section;

  @override
  Widget build(BuildContext context) {
    final specialText = section == VmStoreSection.specialItems ? ' Gradient names are 100,000 coins each for 30 days.' : '';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFE9FBF8), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0x3312C7B7))),
      child: Row(children: [
        const Icon(Icons.cloud_sync_rounded, color: Color(0xFF12C7B7), size: 22),
        const SizedBox(width: 10),
        Expanded(child: Text('${section.label} uses remote item keys. Backend/CDN can change active items, prices, previews and durations without app update.$specialText', style: const TextStyle(color: Color(0xFF064D46), fontSize: 11.5, height: 1.25, fontWeight: FontWeight.w800))),
      ]),
    );
  }
}

class _StoreItemCard extends StatelessWidget {
  const _StoreItemCard({required this.item, required this.owned, required this.equipped, required this.busy, required this.onBuy, required this.onEquip, required this.onUnequip});

  final VmStoreItem item;
  final bool owned;
  final bool equipped;
  final bool busy;
  final VoidCallback onBuy;
  final VoidCallback onEquip;
  final VoidCallback onUnequip;

  @override
  Widget build(BuildContext context) {
    final gradientStyleId = item.type == VmStoreItemType.gradientName ? item.previewAssetKey.split('/').last : null;
    return Container(
      decoration: _storePanelDecoration(radius: 24),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Stack(fit: StackFit.expand, children: [
            DecoratedBox(
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: item.colors)),
              child: Center(
                child: item.type == VmStoreItemType.gradientName
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: GradientNameText(
                          'Vibe Name',
                          textAlign: TextAlign.center,
                          style: GradientNameStyle.byId(gradientStyleId),
                          textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                        ),
                      )
                    : Icon(item.section.icon, color: Colors.white.withValues(alpha: 0.86), size: 46),
              ),
            ),
            Positioned(top: 8, left: 8, child: _TinyBadge(label: item.rarity.label)),
            if (item.isDynamicRemoteItem) const Positioned(top: 8, right: 8, child: _TinyBadge(label: 'Remote')),
            Positioned(left: 10, right: 10, bottom: 10, child: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, height: 1.05))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 10.5, height: 1.22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 7),
            Wrap(spacing: 5, runSpacing: 5, children: [
              if (item.durationDays != null) _SmallMeta(label: '${item.durationDays}d'),
              if (item.requiredVipLevel > 0) _SmallMeta(label: 'VIP ${item.requiredVipLevel}'),
              if (item.requiredSvipLevel > 0) _SmallMeta(label: 'SVIP ${item.requiredSvipLevel}'),
              if (item.isLimited) const _SmallMeta(label: 'Limited'),
            ]),
            const SizedBox(height: 9),
            _StoreActionButton(
              label: equipped ? 'Equipped' : owned ? 'Equip' : item.isFree ? 'Free' : '${_formatCoins(item.priceCoins)} coins',
              enabled: !busy,
              filled: !equipped,
              onTap: equipped ? onUnequip : owned ? onEquip : onBuy,
            ),
          ]),
        ),
      ]),
    );
  }

  static String _formatCoins(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
    return value.toString();
  }
}

class _StoreActionButton extends StatelessWidget {
  const _StoreActionButton({required this.label, required this.enabled, required this.filled, required this.onTap});

  final String label;
  final bool enabled;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 39,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: filled ? const Color(0xFF251538) : const Color(0xFFE9FBF8), borderRadius: BorderRadius.circular(16), border: Border.all(color: filled ? const Color(0xFF251538) : const Color(0xFF12C7B7))),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: filled ? Colors.white : const Color(0xFF064D46), fontSize: 12, fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _TinyBadge extends StatelessWidget {
  const _TinyBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.34), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
    );
  }
}

class _SmallMeta extends StatelessWidget {
  const _SmallMeta({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFFAF7F1), borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFFECE2D8))),
      child: Text(label, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 9, fontWeight: FontWeight.w900)),
    );
  }
}

class _StoreEmptyState extends StatelessWidget {
  const _StoreEmptyState({required this.tab, required this.section});

  final VmStoreTab tab;
  final VmStoreSection section;

  @override
  Widget build(BuildContext context) {
    final isMine = tab == VmStoreTab.mine;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _storePanelDecoration(radius: 24),
      child: Column(children: [
        Icon(section.icon, color: const Color(0xFF7B6A86), size: 34),
        const SizedBox(height: 10),
        Text(isMine ? 'No owned ${section.label}' : 'No active ${section.label}', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF251538), fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text(isMine ? 'Items you buy in this section will appear here.' : 'Backend can activate new items in this section without app update.', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 12, height: 1.3, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

BoxDecoration _storePanelDecoration({required double radius}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: const Color(0xFFECE2D8)),
    boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 8))],
  );
}
