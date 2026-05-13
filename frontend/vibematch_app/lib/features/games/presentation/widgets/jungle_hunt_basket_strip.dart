import 'package:flutter/material.dart';

class JungleHuntBasketStrip extends StatelessWidget {
  const JungleHuntBasketStrip({
    super.key,
    required this.leftHighlighted,
    required this.rightHighlighted,
    required this.assetForId,
  });

  final bool leftHighlighted;
  final bool rightHighlighted;
  final String Function(int id) assetForId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 5),
      child: Row(
        children: [
          _BasketCapsule(ids: const [4, 5, 6, 7], highlighted: leftHighlighted, assetForId: assetForId),
          const Spacer(),
          _BasketCapsule(ids: const [0, 1, 2, 3], highlighted: rightHighlighted, assetForId: assetForId),
        ],
      ),
    );
  }
}

class _BasketCapsule extends StatelessWidget {
  const _BasketCapsule({required this.ids, required this.highlighted, required this.assetForId});

  final List<int> ids;
  final bool highlighted;
  final String Function(int id) assetForId;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 132,
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: highlighted
                ? const [Color(0xFFFFF6A5), Color(0xFFFF9E2D), Color(0xFF7A350B)]
                : [Colors.black.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0.08)],
          ),
          border: Border.all(
            color: highlighted ? const Color(0xFFFFF6A5) : Colors.white.withValues(alpha: 0.14),
            width: highlighted ? 1.8 : 1,
          ),
          boxShadow: highlighted
              ? [BoxShadow(color: const Color(0xFFFFD36A).withValues(alpha: 0.44), blurRadius: 18, spreadRadius: 1)]
              : null,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Icon(
                Icons.shopping_basket_rounded,
                color: Colors.white.withValues(alpha: highlighted ? 0.36 : 0.18),
                size: 42,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: ids
                  .map((id) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _AnimalDot(assetPath: assetForId(id)),
                      ))
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimalDot extends StatelessWidget {
  const _AnimalDot({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 27,
      height: 27,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF2A1306),
        border: Border.all(color: const Color(0xFFFFD36A).withValues(alpha: 0.76)),
      ),
      child: ClipOval(child: Image.asset(assetPath, fit: BoxFit.cover)),
    );
  }
}
