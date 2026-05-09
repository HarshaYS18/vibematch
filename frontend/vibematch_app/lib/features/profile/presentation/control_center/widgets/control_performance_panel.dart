import 'package:flutter/material.dart';

import 'control_deck_widgets.dart';
import 'super_power_design.dart';

enum PerformanceEntityType {
  official('Officials', Icons.admin_panel_settings_rounded),
  seller('Sellers', Icons.sell_rounded),
  merchant('Merchants', Icons.storefront_rounded),
  agency('Agencies', Icons.groups_rounded),
  user('Users', Icons.person_rounded);

  const PerformanceEntityType(this.label, this.icon);
  final String label;
  final IconData icon;
}

enum PerformanceRange {
  daily('Daily'),
  weekly('Weekly'),
  monthly('Monthly'),
  yearly('Yearly');

  const PerformanceRange(this.label);
  final String label;
}

class PerformanceEntity {
  const PerformanceEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.roleLabel,
    required this.score,
    required this.primaryMetric,
    required this.secondaryMetric,
    required this.trendPercent,
    required this.points,
  });

  final String id;
  final String name;
  final PerformanceEntityType type;
  final String roleLabel;
  final int score;
  final int primaryMetric;
  final int secondaryMetric;
  final double trendPercent;
  final List<int> points;
}

class ControlPerformancePanel extends StatefulWidget {
  const ControlPerformancePanel({super.key});

  @override
  State<ControlPerformancePanel> createState() => _ControlPerformancePanelState();
}

class _ControlPerformancePanelState extends State<ControlPerformancePanel> {
  PerformanceEntityType _type = PerformanceEntityType.official;
  PerformanceRange _range = PerformanceRange.daily;
  final Set<String> _compareIds = <String>{'official_1', 'official_2'};

  List<PerformanceEntity> get _filtered {
    return _mockPerformance.where((entity) => entity.type == _type).toList()
      ..sort((a, b) => b.score.compareTo(a.score));
  }

  List<PerformanceEntity> get _compared {
    final all = _mockPerformance.where((entity) => _compareIds.contains(entity.id)).toList();
    return all.isEmpty ? _filtered.take(2).toList() : all;
  }

  void _toggleCompare(PerformanceEntity entity) {
    setState(() {
      if (_compareIds.contains(entity.id)) {
        _compareIds.remove(entity.id);
      } else {
        _compareIds.add(entity.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final top = filtered.isEmpty ? null : filtered.first;

    return Column(
      children: [
        _PerformanceHero(top: top, range: _range, comparedCount: _compared.length),
        const SizedBox(height: 12),
        _RangeAndTypeRail(
          type: _type,
          range: _range,
          onTypeChanged: (value) => setState(() => _type = value),
          onRangeChanged: (value) => setState(() => _range = value),
        ),
        const SizedBox(height: 12),
        _CompareGraph(entities: _compared, range: _range),
        const SizedBox(height: 12),
        ControlDeckShell(
          title: '${_type.label} Leaderboard',
          subtitle: 'Tap Compare to add/remove entities from the graph. Backend later should feed real daily/weekly/monthly/yearly snapshots.',
          children: filtered.map((entity) {
            return _PerformanceRow(
              entity: entity,
              selected: _compareIds.contains(entity.id),
              onCompare: () => _toggleCompare(entity),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _PerformanceHero extends StatelessWidget {
  const _PerformanceHero({required this.top, required this.range, required this.comparedCount});

  final PerformanceEntity? top;
  final PerformanceRange range;
  final int comparedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: SuperPowerDesign.glowShell(radius: 28),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SuperPowerDesign.goldGradient,
              boxShadow: [BoxShadow(color: SuperPowerDesign.gold.withValues(alpha: 0.25), blurRadius: 18)],
            ),
            child: const Icon(Icons.insights_rounded, color: SuperPowerDesign.obsidian, size: 27),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Performance Command', style: TextStyle(color: SuperPowerDesign.text, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
              const SizedBox(height: 2),
              Text('Compare officials, sellers, merchants, agencies and users', style: TextStyle(color: SuperPowerDesign.muted.withValues(alpha: 0.92), fontSize: 10.8, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Row(children: [
                _HeroPill('${range.label} view', SuperPowerDesign.aqua),
                const SizedBox(width: 6),
                _HeroPill('$comparedCount comparing', SuperPowerDesign.gold),
              ]),
            ]),
          ),
          if (top != null)
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('TOP', style: TextStyle(color: SuperPowerDesign.muted, fontSize: 9, fontWeight: FontWeight.w900)),
              Text(top!.score.toString(), style: const TextStyle(color: SuperPowerDesign.gold, fontSize: 25, fontWeight: FontWeight.w900, height: 1)),
              Text(top!.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SuperPowerDesign.text, fontSize: 10, fontWeight: FontWeight.w800)),
            ]),
        ],
      ),
    );
  }
}

class _RangeAndTypeRail extends StatelessWidget {
  const _RangeAndTypeRail({required this.type, required this.range, required this.onTypeChanged, required this.onRangeChanged});

  final PerformanceEntityType type;
  final PerformanceRange range;
  final ValueChanged<PerformanceEntityType> onTypeChanged;
  final ValueChanged<PerformanceRange> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: PerformanceEntityType.values.length,
          separatorBuilder: (context, index) => const SizedBox(width: 7),
          itemBuilder: (context, index) {
            final item = PerformanceEntityType.values[index];
            final active = item == type;
            return _RailChip(label: item.label, icon: item.icon, active: active, onTap: () => onTypeChanged(item));
          },
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 34,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: PerformanceRange.values.length,
          separatorBuilder: (context, index) => const SizedBox(width: 7),
          itemBuilder: (context, index) {
            final item = PerformanceRange.values[index];
            final active = item == range;
            return InkWell(
              onTap: () => onRangeChanged(item),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? SuperPowerDesign.gold : SuperPowerDesign.panel,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: active ? SuperPowerDesign.gold : SuperPowerDesign.stroke),
                ),
                child: Text(item.label, style: TextStyle(color: active ? SuperPowerDesign.obsidian : SuperPowerDesign.text, fontSize: 11, fontWeight: FontWeight.w900)),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

class _CompareGraph extends StatelessWidget {
  const _CompareGraph({required this.entities, required this.range});

  final List<PerformanceEntity> entities;
  final PerformanceRange range;

  @override
  Widget build(BuildContext context) {
    return ControlDeckShell(
      title: 'Comparison Graph',
      subtitle: '${range.label} performance comparison. This is local graph-ready UI until backend metrics are connected.',
      children: [
        SizedBox(
          height: 172,
          child: CustomPaint(
            painter: _PerformanceGraphPainter(entities: entities),
            child: Padding(
              padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: entities.map((entity) => _Legend(entity: entity)).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PerformanceGraphPainter extends CustomPainter {
  const _PerformanceGraphPainter({required this.entities});
  final List<PerformanceEntity> entities;

  static const List<Color> colors = [SuperPowerDesign.gold, SuperPowerDesign.aqua, SuperPowerDesign.rose, SuperPowerDesign.violet, SuperPowerDesign.mint];

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = SuperPowerDesign.stroke.withValues(alpha: 0.55)
      ..strokeWidth = 1;

    for (var i = 1; i <= 4; i++) {
      final y = (size.height - 34) * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (var e = 0; e < entities.length; e++) {
      final entity = entities[e];
      if (entity.points.isEmpty) continue;
      final color = colors[e % colors.length];
      final maxPoint = entity.points.reduce((a, b) => a > b ? a : b).clamp(1, 999999);
      final usableHeight = size.height - 44;
      final dx = size.width / (entity.points.length - 1).clamp(1, 999);
      final path = Path();

      for (var i = 0; i < entity.points.length; i++) {
        final x = dx * i;
        final y = usableHeight - (entity.points[i] / maxPoint) * usableHeight;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.18)
        ..strokeWidth = 7
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, glowPaint);

      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PerformanceGraphPainter oldDelegate) => oldDelegate.entities != entities;
}

class _PerformanceRow extends StatelessWidget {
  const _PerformanceRow({required this.entity, required this.selected, required this.onCompare});

  final PerformanceEntity entity;
  final bool selected;
  final VoidCallback onCompare;

  @override
  Widget build(BuildContext context) {
    final trendColor = entity.trendPercent >= 0 ? SuperPowerDesign.mint : SuperPowerDesign.rose;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [SuperPowerDesign.panelSoft, SuperPowerDesign.obsidian]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: selected ? SuperPowerDesign.gold.withValues(alpha: 0.56) : SuperPowerDesign.stroke),
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: selected ? SuperPowerDesign.goldGradient : null,
            color: selected ? null : SuperPowerDesign.obsidian,
            border: Border.all(color: selected ? Colors.transparent : SuperPowerDesign.stroke),
          ),
          child: Text(entity.score.toString(), style: TextStyle(color: selected ? SuperPowerDesign.obsidian : SuperPowerDesign.gold, fontSize: 13, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(entity.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SuperPowerDesign.text, fontSize: 12.8, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text('${entity.roleLabel} â€¢ ${entity.id}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SuperPowerDesign.muted, fontSize: 10.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Row(children: [
            _MetricTiny(label: 'Primary', value: entity.primaryMetric.toString()),
            const SizedBox(width: 6),
            _MetricTiny(label: 'Secondary', value: entity.secondaryMetric.toString()),
          ]),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${entity.trendPercent >= 0 ? '+' : ''}${entity.trendPercent.toStringAsFixed(1)}%', style: TextStyle(color: trendColor, fontSize: 11, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          InkWell(
            onTap: onCompare,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? SuperPowerDesign.gold : SuperPowerDesign.obsidian,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: selected ? SuperPowerDesign.gold : SuperPowerDesign.stroke),
              ),
              child: Text(selected ? 'Added' : 'Compare', style: TextStyle(color: selected ? SuperPowerDesign.obsidian : SuperPowerDesign.text, fontSize: 10, fontWeight: FontWeight.w900)),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _RailChip extends StatelessWidget {
  const _RailChip({required this.label, required this.icon, required this.active, required this.onTap});
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: active ? SuperPowerDesign.gold : SuperPowerDesign.panel,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? SuperPowerDesign.gold : SuperPowerDesign.stroke),
        ),
        child: Row(children: [
          Icon(icon, size: 15, color: active ? SuperPowerDesign.obsidian : SuperPowerDesign.text),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: active ? SuperPowerDesign.obsidian : SuperPowerDesign.text, fontSize: 11, fontWeight: FontWeight.w900)),
        ]),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.entity});
  final PerformanceEntity entity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: SuperPowerDesign.obsidian, borderRadius: BorderRadius.circular(999), border: Border.all(color: SuperPowerDesign.stroke)),
      child: Text(entity.name, style: const TextStyle(color: SuperPowerDesign.text, fontSize: 9.5, fontWeight: FontWeight.w800)),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withValues(alpha: 0.36))),
      child: Text(label, style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w900)),
    );
  }
}

class _MetricTiny extends StatelessWidget {
  const _MetricTiny({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(color: SuperPowerDesign.obsidian, borderRadius: BorderRadius.circular(999), border: Border.all(color: SuperPowerDesign.stroke)),
      child: Text('$label $value', style: const TextStyle(color: SuperPowerDesign.muted, fontSize: 9.5, fontWeight: FontWeight.w800)),
    );
  }
}

final List<PerformanceEntity> _mockPerformance = <PerformanceEntity>[
  PerformanceEntity(id: 'official_1', name: 'Asha Monitor', type: PerformanceEntityType.official, roleLabel: 'Monitor', score: 94, primaryMetric: 128, secondaryMetric: 91, trendPercent: 18.4, points: [24, 42, 39, 58, 76, 83, 94]),
  PerformanceEntity(id: 'official_2', name: 'CS Kavya', type: PerformanceEntityType.official, roleLabel: 'CS', score: 88, primaryMetric: 142, secondaryMetric: 73, trendPercent: 9.2, points: [18, 28, 44, 52, 64, 71, 88]),
  PerformanceEntity(id: 'official_3', name: 'Ravi Admin', type: PerformanceEntityType.official, roleLabel: 'Admin', score: 77, primaryMetric: 84, secondaryMetric: 66, trendPercent: -3.1, points: [40, 54, 68, 70, 64, 69, 77]),
  PerformanceEntity(id: 'seller_1', name: 'Coin Seller 01', type: PerformanceEntityType.seller, roleLabel: 'Coin Seller', score: 96, primaryMetric: 830000, secondaryMetric: 68, trendPercent: 22.0, points: [200, 320, 460, 580, 710, 760, 960]),
  PerformanceEntity(id: 'seller_2', name: 'Reseller South', type: PerformanceEntityType.seller, roleLabel: 'Reseller', score: 81, primaryMetric: 510000, secondaryMetric: 41, trendPercent: 6.7, points: [180, 230, 310, 420, 460, 505, 610]),
  PerformanceEntity(id: 'merchant_1', name: 'Merchant Alpha', type: PerformanceEntityType.merchant, roleLabel: 'Merchant', score: 92, primaryMetric: 1240000, secondaryMetric: 112, trendPercent: 14.9, points: [220, 390, 480, 630, 770, 900, 1020]),
  PerformanceEntity(id: 'merchant_2', name: 'Merchant Prime', type: PerformanceEntityType.merchant, roleLabel: 'Merchant', score: 84, primaryMetric: 880000, secondaryMetric: 79, trendPercent: 5.5, points: [210, 330, 390, 510, 600, 690, 790]),
  PerformanceEntity(id: 'agency_1', name: 'Moonlight Agency', type: PerformanceEntityType.agency, roleLabel: 'Agency', score: 91, primaryMetric: 42, secondaryMetric: 360000, trendPercent: 12.3, points: [22, 30, 41, 55, 70, 84, 91]),
  PerformanceEntity(id: 'agency_2', name: 'Royal Hosts', type: PerformanceEntityType.agency, roleLabel: 'Agency', score: 86, primaryMetric: 36, secondaryMetric: 290000, trendPercent: 7.8, points: [30, 34, 48, 57, 62, 73, 86]),
  PerformanceEntity(id: 'user_1', name: 'Harsha', type: PerformanceEntityType.user, roleLabel: 'User', score: 98, primaryMetric: 240000, secondaryMetric: 125000, trendPercent: 31.2, points: [26, 42, 59, 69, 83, 92, 98]),
  PerformanceEntity(id: 'user_2', name: 'Riya', type: PerformanceEntityType.user, roleLabel: 'Host/User', score: 89, primaryMetric: 190000, secondaryMetric: 151000, trendPercent: 11.4, points: [28, 35, 47, 61, 78, 84, 89]),
];

