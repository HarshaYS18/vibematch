import 'package:flutter/material.dart';

import 'love_bond_detail_page.dart';
import 'love_bonds_slots_store.dart';
import 'models/love_bond_models.dart';
import 'widgets/love_bond_card.dart';
import 'widgets/love_bonds_background.dart';

class LoveBondsPage extends StatefulWidget {
  const LoveBondsPage({super.key});

  @override
  State<LoveBondsPage> createState() => _LoveBondsPageState();
}

class _LoveBondsPageState extends State<LoveBondsPage> {
  LoveBondsSlotsState? _slotState;
  bool _busy = false;

  List<LoveBondCardData> get _bonds => mockLoveBondCards;

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  Future<void> _loadSlots() async {
    final state = await LoveBondsSlotsStore.load();
    if (!mounted) return;
    setState(() => _slotState = state);
  }

  void _showAction(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF8B3C75),
        ),
      );
  }

  void _openBond(BuildContext context, LoveBondCardData bond) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => LoveBondDetailPage(bond: bond)));
  }

  Future<void> _purchaseExtraSlot() async {
    final state = _slotState;
    if (state == null || _busy) return;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PurchaseSlotSheet(
        priceCoins: state.nextSlotPriceCoins,
        onCancel: () => Navigator.pop(context, false),
        onConfirm: () => Navigator.pop(context, true),
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    final next = await LoveBondsSlotsStore.purchaseExtraSlot(state);
    if (!mounted) return;
    setState(() {
      _slotState = next;
      _busy = false;
    });
    _showAction(context, 'Extra bond slot unlocked.');
  }

  void _openCreateBond() {
    _showAction(context, 'Create bond flow will open from Love/Brother/Sister/Bestie card purchase and acceptance flow.');
  }

  @override
  Widget build(BuildContext context) {
    final slots = _slotState;

    return Scaffold(
      body: LoveBondsBackground(
        child: SafeArea(
          child: slots == null
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
                  children: [
                    Row(
                      children: [
                        _CircleIconButton(icon: Icons.chevron_left_rounded, onTap: () => Navigator.pop(context)),
                        const Spacer(),
                        _GuideButton(onTap: () => _showAction(context, 'Love & Bonds guide will open.')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Love & Bonds',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                        shadows: [
                          Shadow(color: Color(0xFFFF5AAA), blurRadius: 14),
                          Shadow(color: Color(0xFF8B3C75), blurRadius: 3),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Collect and cherish every special bond',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        shadows: [Shadow(color: Color(0xFF8B3C75), blurRadius: 6)],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SlotSummaryPanel(
                      usedSlots: _bonds.length,
                      totalSlots: slots.totalSlotCount,
                      freeSlots: slots.freeSlotCount,
                      paidSlots: slots.paidSlotCount,
                      nextSlotPriceCoins: slots.nextSlotPriceCoins,
                    ),
                    const SizedBox(height: 18),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: slots.totalSlotCount + 1,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 14,
                        mainAxisExtent: 188,
                      ),
                      itemBuilder: (context, index) {
                        if (index == slots.totalSlotCount) {
                          return _ExtraSlotCard(priceCoins: slots.nextSlotPriceCoins, busy: _busy, onTap: _purchaseExtraSlot);
                        }

                        final bond = index < _bonds.length ? _bonds[index] : null;
                        if (bond == null) {
                          return _EmptyBondSlotCard(slotNumber: index + 1, onTap: _openCreateBond);
                        }

                        return _BondSlotWrapper(
                          slotNumber: index + 1,
                          bond: bond,
                          onTap: () => _openBond(context, bond),
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    LoveBondsGlassPanel(
                      radius: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 24,
                            backgroundColor: Color(0xFFFFCBE6),
                            child: Icon(Icons.favorite_rounded, color: Color(0xFFFF5AAA)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(child: _BondSummary(title: 'Used Slots', value: '${_bonds.length}')),
                          const SizedBox(width: 8),
                          Expanded(child: _BondSummary(title: 'Total Slots', value: '${slots.totalSlotCount}')),
                          const SizedBox(width: 8),
                          Expanded(child: _BondSummary(title: 'Paid Slots', value: '${slots.paidSlotCount}')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    LoveBondsGlassPanel(
                      radius: 24,
                      padding: const EdgeInsets.all(16),
                      child: const Text(
                        'Rules: every user gets 4 base bond slots. Extra slots are paid slots. Backend should decide slot price, max paid slots, eligibility and coin deduction. One Lover bond only; Brother, Sister and Bestie bonds use available slots.',
                        style: TextStyle(color: Color(0xFF5C2B60), fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SlotSummaryPanel extends StatelessWidget {
  const _SlotSummaryPanel({required this.usedSlots, required this.totalSlots, required this.freeSlots, required this.paidSlots, required this.nextSlotPriceCoins});

  final int usedSlots;
  final int totalSlots;
  final int freeSlots;
  final int paidSlots;
  final int nextSlotPriceCoins;

  @override
  Widget build(BuildContext context) {
    return LoveBondsGlassPanel(
      radius: 28,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 48, height: 48, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFFFF5AAA), Color(0xFFFFD36A)])), child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 26)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Bond Slots', style: TextStyle(color: Color(0xFF5C2B60), fontSize: 20, fontWeight: FontWeight.w900)),
            Text('$usedSlots / $totalSlots slots used', style: const TextStyle(color: Color(0xFF8B6C91), fontSize: 12, fontWeight: FontWeight.w800)),
          ])),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _MetaPill(label: '$freeSlots free slots'),
          _MetaPill(label: '$paidSlots paid slots'),
          _MetaPill(label: 'Next ${_formatCoins(nextSlotPriceCoins)} coins'),
        ]),
      ]),
    );
  }
}

class _BondSlotWrapper extends StatelessWidget {
  const _BondSlotWrapper({required this.slotNumber, required this.bond, required this.onTap});

  final int slotNumber;
  final LoveBondCardData bond;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(child: LoveBondCard(bond: bond, onTap: onTap)),
      Positioned(top: 8, left: 8, child: _SlotBadge(label: 'Slot $slotNumber')),
    ]);
  }
}

class _EmptyBondSlotCard extends StatelessWidget {
  const _EmptyBondSlotCard({required this.slotNumber, required this.onTap});

  final int slotNumber;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: LoveBondsGlassPanel(
        radius: 24,
        padding: const EdgeInsets.all(14),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          _SlotBadge(label: 'Slot $slotNumber'),
          const SizedBox(height: 14),
          Container(width: 56, height: 56, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFECF6)), child: const Icon(Icons.add_rounded, color: Color(0xFFFF5AAA), size: 34)),
          const SizedBox(height: 12),
          const Text('Empty Slot', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF5C2B60), fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('Use a bond card to create a new bond.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF8B6C91), fontSize: 11.5, height: 1.25, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

class _ExtraSlotCard extends StatelessWidget {
  const _ExtraSlotCard({required this.priceCoins, required this.busy, required this.onTap});

  final int priceCoins;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(24),
      child: LoveBondsGlassPanel(
        radius: 24,
        padding: const EdgeInsets.all(14),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 62, height: 62, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF9C5CFF), Color(0xFFFF5AAA)])), child: busy ? const Padding(padding: EdgeInsets.all(18), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2)) : const Icon(Icons.add_rounded, color: Colors.white, size: 36)),
          const SizedBox(height: 12),
          const Text('Extra Slot', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF5C2B60), fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('Unlock for ${_formatCoins(priceCoins)} coins', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF8B6C91), fontSize: 11.5, height: 1.25, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

class _PurchaseSlotSheet extends StatelessWidget {
  const _PurchaseSlotSheet({required this.priceCoins, required this.onCancel, required this.onConfirm});

  final int priceCoins;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(14),
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
      child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Unlock extra bond slot?', style: TextStyle(color: Color(0xFF5C2B60), fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text('This slot costs ${_formatCoins(priceCoins)} coins. Final price should be controlled by backend config later.', style: const TextStyle(color: Color(0xFF8B6C91), fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: onCancel, child: const Text('Cancel'))),
          const SizedBox(width: 10),
          Expanded(child: FilledButton(onPressed: onConfirm, child: const Text('Unlock'))),
        ]),
      ])),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.72), shape: BoxShape.circle),
        child: Icon(icon, color: const Color(0xFFE7479C), size: 34),
      ),
    );
  }
}

class _GuideButton extends StatelessWidget {
  const _GuideButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.72), borderRadius: BorderRadius.circular(99)),
        child: const Row(
          children: [
            Icon(Icons.favorite_rounded, color: Color(0xFFFF5AAA), size: 20),
            SizedBox(width: 5),
            Text('Guide', style: TextStyle(color: Color(0xFFE7479C), fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _BondSummary extends StatelessWidget {
  const _BondSummary({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: Color(0xFF8B6C91), fontSize: 11, fontWeight: FontWeight.w800)),
      const SizedBox(height: 3),
      Text(value, style: const TextStyle(color: Color(0xFF5C2B60), fontSize: 18, fontWeight: FontWeight.w900)),
    ]);
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(999)), child: Text(label, style: const TextStyle(color: Color(0xFF5C2B60), fontSize: 11, fontWeight: FontWeight.w900)));
  }
}

class _SlotBadge extends StatelessWidget {
  const _SlotBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.30), borderRadius: BorderRadius.circular(999)), child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)));
  }
}

String _formatCoins(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return value.toString();
}
