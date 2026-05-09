import 'package:flutter/material.dart';

import '../control_center_models.dart';
import 'control_deck_widgets.dart';
import 'super_power_design.dart';

class ControlRolePanel extends StatelessWidget {
  const ControlRolePanel({
    super.key,
    required this.roles,
    required this.onAssignRole,
    required this.onRemoveRole,
  });

  final List<RoleAssignmentEntry> roles;
  final VoidCallback onAssignRole;
  final ValueChanged<RoleAssignmentEntry> onRemoveRole;

  @override
  Widget build(BuildContext context) {
    final activeRoles = roles.where((role) => role.isActive).toList();
    final removedRoles = roles.where((role) => !role.isActive).toList();

    return ControlDeckShell(
      title: 'Official Roles',
      subtitle: 'Founder-only role assignment/removal. Mirrors backend role hierarchy and audit requirement.',
      trailing: ControlDeckPill(label: '${activeRoles.length} active'),
      children: [
        ControlDeckRow(
          icon: Icons.verified_user_rounded,
          title: 'Assign official role',
          subtitle: 'Owner, SuperAdmin, Admin, Monitor, CS, agency/business roles',
          accent: SuperPowerDesign.gold,
          onTap: onAssignRole,
        ),
        if (activeRoles.isEmpty)
          const _RoleEmptyRow(label: 'No active role assignments in local panel yet.'),
        ...activeRoles.map((role) => _RoleAssignmentRow(role: role, onRemove: () => onRemoveRole(role))),
        if (removedRoles.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Removed roles', style: TextStyle(color: SuperPowerDesign.muted, fontSize: 11, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          ...removedRoles.take(5).map((role) => _RoleAssignmentRow(role: role, onRemove: null)),
        ],
      ],
    );
  }
}

class _RoleAssignmentRow extends StatelessWidget {
  const _RoleAssignmentRow({required this.role, required this.onRemove});

  final RoleAssignmentEntry role;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final power = controlCenterRolePower[role.role] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SuperPowerDesign.obsidian,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SuperPowerDesign.stroke),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: SuperPowerDesign.violet.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SuperPowerDesign.violet.withValues(alpha: 0.34)),
            ),
            child: Text('$power', style: const TextStyle(color: SuperPowerDesign.violet, fontSize: 11, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${role.userId} • ${role.role}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SuperPowerDesign.text, fontSize: 12.5, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(role.reason, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SuperPowerDesign.muted, fontSize: 10.5, fontWeight: FontWeight.w700)),
            ]),
          ),
          if (role.isActive && onRemove != null)
            TextButton(onPressed: onRemove, child: const Text('Remove'))
          else
            const ControlDeckPill(label: 'REMOVED', color: SuperPowerDesign.rose),
        ],
      ),
    );
  }
}

class _RoleEmptyRow extends StatelessWidget {
  const _RoleEmptyRow({required this.label});
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

class RoleDraft {
  const RoleDraft({required this.userId, required this.role, required this.reason});
  final String userId;
  final String role;
  final String reason;
}

class RoleAssignSheet extends StatefulWidget {
  const RoleAssignSheet({super.key});

  static Future<RoleDraft?> show(BuildContext context) {
    return showModalBottomSheet<RoleDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const RoleAssignSheet(),
    );
  }

  @override
  State<RoleAssignSheet> createState() => _RoleAssignSheetState();
}

class _RoleAssignSheetState extends State<RoleAssignSheet> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  String _role = 'monitor';

  @override
  void dispose() {
    _userController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    final userId = _userController.text.trim();
    final reason = _reasonController.text.trim();
    if (userId.isEmpty || reason.isEmpty) return;
    Navigator.pop(context, RoleDraft(userId: userId, role: _role, reason: reason));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.fromLTRB(14, 14, 14, 14 + bottom),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            const Text('Assign official role', style: TextStyle(color: Color(0xFF170D20), fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            TextField(controller: _userController, decoration: _input('Target user ID')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _role,
              items: controlCenterRoles.map((role) => DropdownMenuItem(value: role, child: Text('$role  • power ${controlCenterRolePower[role] ?? 0}'))).toList(),
              onChanged: (value) => setState(() => _role = value ?? _role),
              decoration: _input('Official role'),
            ),
            const SizedBox(height: 8),
            TextField(controller: _reasonController, minLines: 2, maxLines: 3, decoration: _input('Reason')),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, height: 46, child: FilledButton(onPressed: _submit, child: const Text('Assign role'))),
          ]),
        ),
      ),
    );
  }

  InputDecoration _input(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFFAF7F1),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFECE2D8))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFECE2D8))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFC99A3B))),
    );
  }
}
