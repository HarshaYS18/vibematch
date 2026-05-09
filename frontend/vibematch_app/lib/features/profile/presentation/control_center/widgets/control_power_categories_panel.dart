import 'package:flutter/material.dart';

import '../control_center_models.dart';
import 'control_deck_widgets.dart';
import 'super_power_design.dart';

class ControlPowerCategoriesPanel extends StatefulWidget {
  const ControlPowerCategoriesPanel({
    super.key,
    required this.grants,
    required this.onGrantPower,
    required this.onToggleGrant,
  });

  final List<PowerGrantEntry> grants;
  final VoidCallback onGrantPower;
  final ValueChanged<PowerGrantEntry> onToggleGrant;

  @override
  State<ControlPowerCategoriesPanel> createState() => _ControlPowerCategoriesPanelState();
}

class _ControlPowerCategoriesPanelState extends State<ControlPowerCategoriesPanel> {
  PowerCategory _category = PowerCategory.moderation;

  @override
  Widget build(BuildContext context) {
    final authorities = controlCenterAuthorityGroups[_category] ?? const <String>[];
    final categoryGrants = widget.grants.where((grant) => grant.authorities.any(authorities.contains)).toList();

    return ControlDeckShell(
      title: 'Power Categories',
      subtitle: 'Powers are grouped by function so official access stays clean and auditable.',
      trailing: ControlDeckPill(label: '${widget.grants.where((g) => g.isActive).length} active'),
      children: [
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: PowerCategory.values.length,
            separatorBuilder: (context, index) => const SizedBox(width: 7),
            itemBuilder: (context, index) {
              final category = PowerCategory.values[index];
              final active = category == _category;
              return InkWell(
                onTap: () => setState(() => _category = category),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  decoration: BoxDecoration(
                    color: active ? SuperPowerDesign.gold : SuperPowerDesign.obsidian,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: active ? SuperPowerDesign.gold : SuperPowerDesign.stroke),
                  ),
                  child: Row(children: [
                    Icon(category.icon, size: 15, color: active ? SuperPowerDesign.obsidian : SuperPowerDesign.text),
                    const SizedBox(width: 6),
                    Text(category.label, style: TextStyle(color: active ? SuperPowerDesign.obsidian : SuperPowerDesign.text, fontSize: 11, fontWeight: FontWeight.w900)),
                  ]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: authorities.map((authority) => _AuthorityChip(label: authority)).toList(),
        ),
        const SizedBox(height: 10),
        ControlDeckRow(
          icon: Icons.add_moderator_rounded,
          title: 'Grant categorized power',
          subtitle: 'Choose user, role, powers and reason',
          accent: SuperPowerDesign.gold,
          onTap: widget.onGrantPower,
        ),
        if (categoryGrants.isEmpty)
          const _EmptyGrantRow(label: 'No grants in this category yet.')
        else
          ...categoryGrants.map((grant) => _GrantRow(grant: grant, onTap: () => widget.onToggleGrant(grant))),
      ],
    );
  }
}

class _AuthorityChip extends StatelessWidget {
  const _AuthorityChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: SuperPowerDesign.violet.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: SuperPowerDesign.violet.withValues(alpha: 0.30)),
      ),
      child: Text(label, style: const TextStyle(color: SuperPowerDesign.violet, fontSize: 9.5, fontWeight: FontWeight.w900)),
    );
  }
}

class _GrantRow extends StatelessWidget {
  const _GrantRow({required this.grant, required this.onTap});

  final PowerGrantEntry grant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: SuperPowerDesign.obsidian, borderRadius: BorderRadius.circular(16), border: Border.all(color: SuperPowerDesign.stroke)),
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: (grant.isActive ? SuperPowerDesign.mint : SuperPowerDesign.rose).withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(grant.isActive ? Icons.verified_rounded : Icons.remove_circle_rounded, color: grant.isActive ? SuperPowerDesign.mint : SuperPowerDesign.rose, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${grant.userId} • ${grant.role}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SuperPowerDesign.text, fontSize: 12.5, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(grant.authorities.join(', '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SuperPowerDesign.muted, fontSize: 10.5, fontWeight: FontWeight.w700)),
        ])),
        TextButton(onPressed: onTap, child: Text(grant.isActive ? 'Revoke' : 'Restore')),
      ]),
    );
  }
}

class _EmptyGrantRow extends StatelessWidget {
  const _EmptyGrantRow({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: SuperPowerDesign.obsidian, borderRadius: BorderRadius.circular(16), border: Border.all(color: SuperPowerDesign.stroke)),
      child: Text(label, style: const TextStyle(color: SuperPowerDesign.muted, fontSize: 11.5, fontWeight: FontWeight.w800)),
    );
  }
}
