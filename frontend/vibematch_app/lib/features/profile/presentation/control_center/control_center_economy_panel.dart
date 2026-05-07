import 'package:flutter/material.dart';

import 'control_center_models.dart';

class ControlCenterEconomyPanel extends StatelessWidget {
  const ControlCenterEconomyPanel({
    super.key,
    required this.state,
    required this.onAddPoolCoins,
    required this.onRemovePoolCoins,
    required this.onSendCoins,
  });

  final ControlCenterState state;
  final VoidCallback onAddPoolCoins;
  final VoidCallback onRemovePoolCoins;
  final VoidCallback onSendCoins;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: _premiumPanelDecoration(),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Color(0xFFFFD36A), Color(0xFFC99A3B)]),
                ),
                child: const Icon(Icons.all_inclusive_rounded, color: Color(0xFF170D20), size: 27),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Authority Pool', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text('${_formatCoins(state.coinAuthorityBalance)} coins available', style: const TextStyle(color: Color(0xFFAFA3B8), fontSize: 12, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.75,
          children: [
            _PoolActionButton(label: 'Add Pool', icon: Icons.add_circle_rounded, onTap: onAddPoolCoins),
            _PoolActionButton(label: 'Remove Pool', icon: Icons.remove_circle_rounded, onTap: onRemovePoolCoins),
            _PoolActionButton(label: 'Send User', icon: Icons.send_rounded, onTap: onSendCoins),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: _premiumPanelDecoration(),
          child: const Text(
            'Super Owner authority pool can be topped up or reduced from this panel. Backend should audit source pool, actor, amount and reason.',
            style: TextStyle(color: Color(0xFFAFA3B8), fontSize: 11.5, height: 1.3, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _PoolActionButton extends StatelessWidget {
  const _PoolActionButton({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFFD36A), Color(0xFFC99A3B)]),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF170D20), size: 17),
            const SizedBox(width: 6),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF170D20), fontSize: 11.5, fontWeight: FontWeight.w900))),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _premiumPanelDecoration() {
  return BoxDecoration(
    color: Colors.white.withValues(alpha: 0.075),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Colors.white.withValues(alpha: 0.085)),
    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 14, offset: const Offset(0, 7))],
  );
}

String _formatCoins(int value) {
  if (value >= 1000000000) return '${(value / 1000000000).toStringAsFixed(1)}B';
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return value.toString();
}
