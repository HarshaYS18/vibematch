import 'package:flutter/material.dart';

import '../widgets/family_redesign_shared.dart';

class CreateFamilySheet extends StatefulWidget {
  const CreateFamilySheet({super.key, required this.onCreate});

  final void Function(String name, String minimumVipLabel) onCreate;

  @override
  State<CreateFamilySheet> createState() => _CreateFamilySheetState();
}

class _CreateFamilySheetState extends State<CreateFamilySheet> {
  final TextEditingController _nameController = TextEditingController(text: 'Aurora Circle');
  final TextEditingController _vipController = TextEditingController(text: 'VIP 5');

  @override
  void dispose() {
    _nameController.dispose();
    _vipController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final vip = _vipController.text.trim();
    if (name.isEmpty || vip.isEmpty) return;
    widget.onCreate(name, vip);
  }

  @override
  Widget build(BuildContext context) {
    return FamilySheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Create Family', style: TextStyle(color: FamilyRedesignColors.ink, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('One user can join only one family. Add a cover, family name, and minimum VIP requirement.', style: TextStyle(color: FamilyRedesignColors.soft, height: 1.3, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          Center(
            child: Container(
              width: 94,
              height: 94,
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [FamilyRedesignColors.ink, FamilyRedesignColors.coral]), borderRadius: BorderRadius.circular(28)),
              child: const Icon(Icons.add_photo_alternate_rounded, color: Colors.white, size: 42),
            ),
          ),
          const SizedBox(height: 14),
          _SheetTextField(label: 'Family name', hint: 'Enter family name', controller: _nameController),
          const SizedBox(height: 10),
          _SheetTextField(label: 'Minimum VIP required', hint: 'Example: VIP 5', controller: _vipController),
          const SizedBox(height: 14),
          FamilyPrimaryButton(label: 'Create Family', onTap: _submit),
        ],
      ),
    );
  }
}

class _SheetTextField extends StatelessWidget {
  const _SheetTextField({required this.label, required this.hint, required this.controller});

  final String label;
  final String hint;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: FamilyRedesignColors.ink, fontWeight: FontWeight.w900)),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: FamilyRedesignColors.page,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}
