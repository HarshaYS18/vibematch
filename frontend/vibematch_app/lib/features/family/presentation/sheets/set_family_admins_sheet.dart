import 'package:flutter/material.dart';

import '../../models/family_ui_models.dart';
import '../widgets/family_redesign_shared.dart';

class SetFamilyAdminsSheet extends StatefulWidget {
  const SetFamilyAdminsSheet({
    super.key,
    required this.members,
    required this.adminCapacity,
    required this.onSave,
  });

  final List<FamilyMemberUiModel> members;
  final int adminCapacity;
  final ValueChanged<Set<String>> onSave;

  @override
  State<SetFamilyAdminsSheet> createState() => _SetFamilyAdminsSheetState();
}

class _SetFamilyAdminsSheetState extends State<SetFamilyAdminsSheet> {
  late final Set<String> _selectedAdminIds = widget.members
      .where((member) => member.role == FamilyRole.admin)
      .map((member) => member.userId)
      .toSet();

  List<FamilyMemberUiModel> get _eligibleMembers {
    return widget.members.where((member) => member.role != FamilyRole.owner).toList();
  }

  void _toggle(FamilyMemberUiModel member) {
    if (member.role == FamilyRole.owner) return;
    setState(() {
      if (_selectedAdminIds.contains(member.userId)) {
        _selectedAdminIds.remove(member.userId);
      } else if (_selectedAdminIds.length < widget.adminCapacity) {
        _selectedAdminIds.add(member.userId);
      }
    });
  }

  void _save() {
    widget.onSave(_selectedAdminIds);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return FamilySheetShell(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: FamilyRedesignColors.ink),
                ),
                const Expanded(
                  child: Text(
                    'Set Family Admins',
                    style: TextStyle(color: FamilyRedesignColors.ink, fontSize: 21, fontWeight: FontWeight.w900),
                  ),
                ),
                InkWell(
                  onTap: _save,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: FamilyRedesignColors.ink, borderRadius: BorderRadius.circular(16)),
                    child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: FamilyRedesignColors.page, borderRadius: BorderRadius.circular(18)),
              child: Row(
                children: [
                  const Icon(Icons.admin_panel_settings_rounded, color: FamilyRedesignColors.gold, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_selectedAdminIds.length}/${widget.adminCapacity} admins selected. Select or unselect members, then tap Save.',
                      style: const TextStyle(color: FamilyRedesignColors.soft, height: 1.25, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                itemCount: _eligibleMembers.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  final member = _eligibleMembers[index];
                  final selected = _selectedAdminIds.contains(member.userId);
                  final disabled = !selected && _selectedAdminIds.length >= widget.adminCapacity;
                  return _AdminMemberTile(
                    member: member,
                    selected: selected,
                    disabled: disabled,
                    onTap: () => _toggle(member),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminMemberTile extends StatelessWidget {
  const _AdminMemberTile({
    required this.member,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final FamilyMemberUiModel member;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? FamilyRedesignColors.neon : FamilyRedesignColors.line,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: [BoxShadow(color: FamilyRedesignColors.ink.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Row(
          children: [
            _SelectCircle(selected: selected, disabled: disabled),
            const SizedBox(width: 12),
            FamilyGradientAvatar(text: member.avatarText, colors: member.avatarGradient, size: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: FamilyRedesignColors.ink, fontSize: 15, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      FamilyRoleChip(role: member.role),
                      FamilySmallPill(icon: Icons.auto_graph_rounded, label: compactFamilyNumber(member.contributionExp)),
                    ],
                  ),
                ],
              ),
            ),
            if (selected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(color: FamilyRedesignColors.neon.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(999)),
                child: const Text('Selected', style: TextStyle(color: FamilyRedesignColors.ink, fontSize: 11, fontWeight: FontWeight.w900)),
              ),
          ],
        ),
      ),
    );
  }
}

class _SelectCircle extends StatelessWidget {
  const _SelectCircle({required this.selected, required this.disabled});

  final bool selected;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? FamilyRedesignColors.neon : Colors.transparent,
        border: Border.all(
          color: disabled ? const Color(0xFFD8D1CB) : selected ? FamilyRedesignColors.neon : FamilyRedesignColors.soft,
          width: 2,
        ),
      ),
      child: selected ? const Icon(Icons.check_rounded, color: FamilyRedesignColors.ink, size: 16) : null,
    );
  }
}
