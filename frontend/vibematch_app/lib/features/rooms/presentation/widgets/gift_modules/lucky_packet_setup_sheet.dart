import 'package:flutter/material.dart';

import '../economy/gold_coin_icon.dart';
import '../room_theme.dart';

class LuckyPacketSetupSheet extends StatefulWidget {
  const LuckyPacketSetupSheet({
    super.key,
    required this.coinBalance,
    required this.onSend,
  });

  final int coinBalance;
  final void Function(int coinAmount, int peopleCount, String message) onSend;

  @override
  State<LuckyPacketSetupSheet> createState() => _LuckyPacketSetupSheetState();
}

class _LuckyPacketSetupSheetState extends State<LuckyPacketSetupSheet> {
  static const List<int> _amounts = [500, 1000, 5000, 10000];
  static const List<int> _peopleCounts = [5, 10, 20, 50, 100];

  final TextEditingController _messageController = TextEditingController();
  int _selectedAmount = 500;
  int _selectedPeopleCount = 5;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.paddingOf(context).bottom + 16),
      decoration: const BoxDecoration(
        color: Color(0xFF12101D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(width: 44),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [Color(0xFFFFD166), Color(0xFFE84C72)]),
                  boxShadow: [BoxShadow(color: RoomColors.coral.withValues(alpha: 0.26), blurRadius: 18, offset: const Offset(0, 8))],
                ),
                child: const Text('🧧', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lucky Packet', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                    SizedBox(height: 2),
                    Text('Choose amount, people and message', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              Row(
                children: [
                  const GoldCoinIcon(size: 15),
                  const SizedBox(width: 5),
                  Text('${widget.coinBalance}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Coins', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _amounts.map((amount) {
              final selected = amount == _selectedAmount;
              return _LuckyPacketChip(
                selected: selected,
                onTap: () => setState(() => _selectedAmount = amount),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const GoldCoinIcon(size: 13),
                    const SizedBox(width: 5),
                    Text('$amount', style: TextStyle(color: selected ? RoomColors.deep : Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          const Text('No. of people', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _peopleCounts.map((count) {
              final selected = count == _selectedPeopleCount;
              return _LuckyPacketChip(
                selected: selected,
                onTap: () => setState(() => _selectedPeopleCount = count),
                child: Text('$count', style: TextStyle(color: selected ? RoomColors.deep : Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _messageController,
            maxLength: 60,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              counterStyle: TextStyle(color: Colors.white.withValues(alpha: 0.40), fontSize: 10),
              hintText: 'Type packet message...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.36), fontSize: 12, fontWeight: FontWeight.w700),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: RoomColors.gold)),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => widget.onSend(_selectedAmount, _selectedPeopleCount, _messageController.text),
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(colors: [RoomColors.gold, RoomColors.coral]),
                boxShadow: [BoxShadow(color: RoomColors.coral.withValues(alpha: 0.24), blurRadius: 18, offset: const Offset(0, 8))],
              ),
              child: const Text('Send Lucky Packet', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

class _LuckyPacketChip extends StatelessWidget {
  const _LuckyPacketChip({required this.selected, required this.onTap, required this.child});

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? RoomColors.gold : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? Colors.white24 : Colors.white12),
        ),
        child: child,
      ),
    );
  }
}
