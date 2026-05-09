import 'package:flutter/material.dart';

import '../control_center_models.dart';

class NumberDraft {
  const NumberDraft({required this.amount});
  final int amount;
}

class UserNumberDraft {
  const UserNumberDraft({required this.userId, required this.amount});
  final String userId;
  final int amount;
}

class UserTextDraft {
  const UserTextDraft({required this.userId, required this.text});
  final String userId;
  final String text;
}

class PowerDraft {
  const PowerDraft({required this.userId, required this.role, required this.authorities, required this.reason});
  final String userId;
  final String role;
  final List<String> authorities;
  final String reason;
}

class ControlNumberSheet extends StatefulWidget {
  const ControlNumberSheet({super.key, required this.title});

  final String title;

  static Future<NumberDraft?> show(BuildContext context, {required String title}) {
    return showModalBottomSheet<NumberDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ControlNumberSheet(title: title),
    );
  }

  @override
  State<ControlNumberSheet> createState() => _ControlNumberSheetState();
}

class _ControlNumberSheetState extends State<ControlNumberSheet> {
  final TextEditingController _amount = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: widget.title,
      fields: [_field(_amount, 'Amount', keyboard: TextInputType.number)],
      onSubmit: () {
        final parsed = int.tryParse(_amount.text.trim());
        if (parsed == null || parsed <= 0) return;
        Navigator.pop(context, NumberDraft(amount: parsed));
      },
    );
  }
}

class ControlUserNumberSheet extends StatefulWidget {
  const ControlUserNumberSheet({super.key, required this.title});

  final String title;

  static Future<UserNumberDraft?> show(BuildContext context, {required String title}) {
    return showModalBottomSheet<UserNumberDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ControlUserNumberSheet(title: title),
    );
  }

  @override
  State<ControlUserNumberSheet> createState() => _ControlUserNumberSheetState();
}

class _ControlUserNumberSheetState extends State<ControlUserNumberSheet> {
  final TextEditingController _user = TextEditingController();
  final TextEditingController _amount = TextEditingController();

  @override
  void dispose() {
    _user.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: widget.title,
      fields: [_field(_user, 'Target user ID'), _field(_amount, 'Amount', keyboard: TextInputType.number)],
      onSubmit: () {
        final parsed = int.tryParse(_amount.text.trim());
        if (_user.text.trim().isEmpty || parsed == null || parsed <= 0) return;
        Navigator.pop(context, UserNumberDraft(userId: _user.text.trim(), amount: parsed));
      },
    );
  }
}

class ControlUserTextSheet extends StatefulWidget {
  const ControlUserTextSheet({super.key, required this.title, required this.label});

  final String title;
  final String label;

  static Future<UserTextDraft?> show(BuildContext context, {required String title, required String label}) {
    return showModalBottomSheet<UserTextDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ControlUserTextSheet(title: title, label: label),
    );
  }

  @override
  State<ControlUserTextSheet> createState() => _ControlUserTextSheetState();
}

class _ControlUserTextSheetState extends State<ControlUserTextSheet> {
  final TextEditingController _user = TextEditingController();
  final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _user.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: widget.title,
      fields: [_field(_user, 'Target user ID'), _field(_text, widget.label)],
      onSubmit: () {
        if (_user.text.trim().isEmpty || _text.text.trim().isEmpty) return;
        Navigator.pop(context, UserTextDraft(userId: _user.text.trim(), text: _text.text.trim()));
      },
    );
  }
}

class ControlPowerSheet extends StatefulWidget {
  const ControlPowerSheet({super.key});

  static Future<PowerDraft?> show(BuildContext context) {
    return showModalBottomSheet<PowerDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ControlPowerSheet(),
    );
  }

  @override
  State<ControlPowerSheet> createState() => _ControlPowerSheetState();
}

class _ControlPowerSheetState extends State<ControlPowerSheet> {
  final TextEditingController _user = TextEditingController();
  final TextEditingController _reason = TextEditingController();
  String _role = 'monitor';
  final Set<String> _selected = <String>{'TEMP_BAN_USER'};

  @override
  void dispose() {
    _user.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'Grant categorized power',
      fields: [
        _field(_user, 'Target user ID'),
        DropdownButtonFormField<String>(
          initialValue: _role,
          items: controlCenterRoles.map((role) => DropdownMenuItem(value: role, child: Text(role))).toList(),
          onChanged: (value) => setState(() => _role = value ?? _role),
          decoration: _input('Role'),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: controlCenterAuthorities.map((item) {
            return FilterChip(
              label: Text(item, style: const TextStyle(fontSize: 10)),
              selected: _selected.contains(item),
              onSelected: (value) => setState(() => value ? _selected.add(item) : _selected.remove(item)),
            );
          }).toList(),
        ),
        _field(_reason, 'Reason'),
      ],
      onSubmit: () {
        if (_user.text.trim().isEmpty || _reason.text.trim().isEmpty || _selected.isEmpty) return;
        Navigator.pop(context, PowerDraft(userId: _user.text.trim(), role: _role, authorities: _selected.toList(), reason: _reason.text.trim()));
      },
    );
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.fields, required this.onSubmit});
  final String title;
  final List<Widget> fields;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.fromLTRB(14, 14, 14, 14 + bottom),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF170D20))),
            const SizedBox(height: 10),
            ...fields,
            SizedBox(width: double.infinity, height: 44, child: FilledButton(onPressed: onSubmit, child: const Text('Submit'))),
          ]),
        ),
      ),
    );
  }
}

Widget _field(TextEditingController controller, String label, {TextInputType? keyboard}) {
  return Padding(padding: const EdgeInsets.only(bottom: 8), child: TextField(controller: controller, keyboardType: keyboard, decoration: _input(label)));
}

InputDecoration _input(String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: const Color(0xFFFAF7F1),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: Color(0xFFECE2D8))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: Color(0xFFECE2D8))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: Color(0xFFC99A3B))),
  );
}
