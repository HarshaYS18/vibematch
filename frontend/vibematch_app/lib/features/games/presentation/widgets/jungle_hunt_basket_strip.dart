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
    return SizedBox(
      height: 38,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 3),
        child: Row(
          children: [
            Flexible(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _BasketCapsule(
                  ids: const [4, 5, 6, 7],
                  highlighted: leftHighlighted,
                  assetForId: assetForId,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Flexible(
              child: Align(
                alignment: Alignment.centerRight,
                child: _BasketCapsule(
                  ids: const [0, 1, 2, 3],
                  highlighted: rightHighlighted,
                  assetForId: assetForId,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BasketCapsule extends StatelessWidget {
  const _BasketCapsule({
    required this.ids,
    required this.highlighted,
    required this.assetForId,
  });

  final List<int> ids;
  final bool highlighted;
  final String Function(int id) assetForId;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        scale: highlighted ? 1.04 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 104,
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: highlighted
                  ? const [Color(0xFFFFF7C2), Color(0xFFFFB545), Color(0xFF6E2D08)]
                  : [
                      Colors.black.withValues(alpha: 0.42),
                      Colors.white.withValues(alpha: 0.08),
                      Colors.black.withValues(alpha: 0.28),
                    ],
            ),
            border: Border.all(
              color: highlighted
                  ? const Color(0xFFFFF1A3)
                  : Colors.white.withValues(alpha: 0.18),
              width: highlighted ? 1.6 : 0.9,
            ),
            boxShadow: highlighted
                ? [
                    BoxShadow(
                      color: const Color(0xFFFFD36A).withValues(alpha: 0.48),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.30),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: Colors.white.withValues(alpha: highlighted ? 0.10 : 0.05),
                  ),
                ),
              ),
              Positioned(
                left: 3,
                bottom: 0,
                child: Icon(
                  Icons.shopping_basket_rounded,
                  color: Colors.white.withValues(alpha: highlighted ? 0.34 : 0.18),
                  size: 24,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: ids
                    .map(
                      (id) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: _AnimalDot(assetPath: assetForId(id)),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ),
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
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF1B0D05),
        border: Border.all(color: const Color(0xFFFFD36A).withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipOval(child: Image.asset(assetPath, fit: BoxFit.cover)),
    );
  }
}
