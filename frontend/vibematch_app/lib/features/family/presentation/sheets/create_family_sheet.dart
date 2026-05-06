import 'package:flutter/material.dart';

import '../widgets/family_redesign_shared.dart';

class CreateFamilySheet extends StatefulWidget {
  const CreateFamilySheet({super.key, required this.onCreate});

  final void Function(String name, String minimumVipLabel) onCreate;

  @override
  State<CreateFamilySheet> createState() => _CreateFamilySheetState();
}

class _CreateFamilySheetState extends State<CreateFamilySheet> {
  static const List<int> _vipLevels = [
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
    22,
    23,
    24,
    25,
    26,
    27,
    28,
    29,
    30,
    31,
    32,
    33,
    34,
    35,
    36,
    37,
    38,
    39,
    40,
    41,
    42,
    43,
    44,
    45,
    46,
    47,
    48,
    49,
    50,
  ];

  final TextEditingController _nameController = TextEditingController(text: 'Aurora Circle');
  int _selectedVipLevel = 5;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    widget.onCreate(name, 'VIP $_selectedVipLevel');
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
          _VipLevelPicker(
            selectedLevel: _selectedVipLevel,
            levels: _vipLevels,
            onChanged: (level) => setState(() => _selectedVipLevel = level),
          ),
          const SizedBox(height: 14),
          FamilyPrimaryButton(label: 'Create Family', onTap: _submit),
        ],
      ),
    );
  }
}

class _VipLevelPicker extends StatelessWidget {
  const _VipLevelPicker({required this.selectedLevel, required this.levels, required this.onChanged});

  final int selectedLevel;
  final List<int> levels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Minimum VIP required', style: TextStyle(color: FamilyRedesignColors.ink, fontWeight: FontWeight.w900)),
        const SizedBox(height: 7),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: FamilyRedesignColors.page, borderRadius: BorderRadius.circular(18)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: selectedLevel,
              isExpanded: true,
              borderRadius: BorderRadius.circular(18),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: FamilyRedesignColors.ink),
              dropdownColor: Colors.white,
              items: levels.map((level) {
                return DropdownMenuItem<int>(
                  value: level,
                  child: Row(
                    children: [
                      const Icon(Icons.workspace_premium_rounded, color: FamilyRedesignColors.gold, size: 18),
                      const SizedBox(width: 8),
                      Text('VIP $level', style: const TextStyle(color: FamilyRedesignColors.ink, fontWeight: FontWeight.w800)),
                    ],
                  ),
                );
              }).toList(),
              selectedItemBuilder: (context) {
                return levels.map((level) {
                  return Row(
                    children: [
                      const Icon(Icons.workspace_premium_rounded, color: FamilyRedesignColors.gold, size: 18),
                      const SizedBox(width: 8),
                      Text('VIP $level', style: const TextStyle(color: FamilyRedesignColors.ink, fontWeight: FontWeight.w900)),
                    ],
                  );
                }).toList();
              },
              onChanged: (level) {
                if (level == null) return;
                onChanged(level);
              },
            ),
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Choose from the app VIP levels. Users below this VIP cannot join unless the requirement is changed later.',
          style: TextStyle(color: FamilyRedesignColors.soft, fontSize: 11, height: 1.25, fontWeight: FontWeight.w700),
        ),
      ],
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
