import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../auth/models/current_user.dart';
import 'models/edit_profile_models.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, required this.user});

  final CurrentUser user;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.user.displayName ?? widget.user.username ?? 'Founder',
  );
  final TextEditingController _bioController = TextEditingController(
    text: 'Building premium live rooms, Vibes, gifts and a trusted social-audio community.',
  );
  final TextEditingController _ageController = TextEditingController(text: '27');

  ProfileGender _gender = ProfileGender.male;
  FriendGenderPreference _friendGenderPreference = FriendGenderPreference.both;
  FriendMaritalPreference _friendMaritalPreference = FriendMaritalPreference.any;
  MaritalStatus _maritalStatus = MaritalStatus.single;
  String _profession = 'Software Engineer';
  DateTime _dob = DateTime(1998, 6, 18);
  final Set<String> _interests = {'Music Rooms', 'Gaming', 'Tech', 'Fitness', 'Live Audio'};

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF251538),
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      );
  }

  void _saveProfile() {
    if (_nameController.text.trim().isEmpty) {
      _toast('Name is required.');
      return;
    }
    _toast('Profile saved locally. Backend profile update API will connect later.');
    Navigator.pop(context);
  }

  Future<void> _openDobPicker() async {
    var selected = _dob;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SheetShell(
        child: SizedBox(
          height: 320,
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(child: Text('Select D.O.B', style: TextStyle(color: Color(0xFF251538), fontSize: 20, fontWeight: FontWeight.w900))),
                  TextButton(
                    onPressed: () {
                      setState(() => _dob = selected);
                      Navigator.pop(context);
                    },
                    child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: _dob,
                  minimumDate: DateTime(1950),
                  maximumDate: DateTime.now(),
                  onDateTimeChanged: (value) => selected = value,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: Column(
          children: [
            _Header(onBack: () => Navigator.pop(context), onSave: _saveProfile),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                children: [
                  _AvatarCard(
                    name: _nameController.text.trim().isEmpty ? 'V' : _nameController.text.trim(),
                    onAvatarTap: () => _toast('Avatar picker will connect to image picker/backend upload later.'),
                  ),
                  const SizedBox(height: 12),
                  _EditSection(
                    title: 'Basic',
                    children: [
                      _CompactTextField(label: 'Name', controller: _nameController, maxLength: 30, onChanged: (_) => setState(() {})),
                      _CompactTextField(label: 'Bio', controller: _bioController, maxLines: 3, maxLength: 120),
                      Row(
                        children: [
                          Expanded(child: _CompactTextField(label: 'Age', controller: _ageController, keyboardType: TextInputType.number, maxLength: 2)),
                          const SizedBox(width: 10),
                          Expanded(child: _PickerTile(label: 'D.O.B', value: _formatDob(_dob), onTap: _openDobPicker)),
                        ],
                      ),
                      _OptionWrap<ProfileGender>(
                        label: 'Gender',
                        values: ProfileGender.values,
                        selected: _gender,
                        textFor: (item) => item.label,
                        onSelected: (item) => setState(() => _gender = item),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _EditSection(
                    title: 'Identity',
                    children: [
                      _DropdownTile(
                        label: 'Profession',
                        value: _profession,
                        values: profileProfessionOptions.map((item) => item.label).toList(),
                        onChanged: (value) => setState(() => _profession = value),
                      ),
                      _OptionWrap<MaritalStatus>(
                        label: 'Marital status',
                        values: MaritalStatus.values,
                        selected: _maritalStatus,
                        textFor: (item) => item.label,
                        onSelected: (item) => setState(() => _maritalStatus = item),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _EditSection(
                    title: 'Interests',
                    subtitle: 'Pick interests from different categories. Match score uses common interests.',
                    children: [
                      for (final category in profileInterestCategories)
                        _InterestCategoryBlock(
                          category: category,
                          selected: _interests,
                          onToggle: (interest) {
                            setState(() {
                              if (_interests.contains(interest)) {
                                _interests.remove(interest);
                              } else {
                                _interests.add(interest);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _EditSection(
                    title: 'Friend preference',
                    subtitle: 'Used to calculate viewer-specific match percentage on public profiles.',
                    children: [
                      _OptionWrap<FriendGenderPreference>(
                        label: 'Prefer to make friends with',
                        values: FriendGenderPreference.values,
                        selected: _friendGenderPreference,
                        textFor: (item) => item.label,
                        onSelected: (item) => setState(() => _friendGenderPreference = item),
                      ),
                      _OptionWrap<FriendMaritalPreference>(
                        label: 'Prefer based on marital status',
                        values: FriendMaritalPreference.values,
                        selected: _friendMaritalPreference,
                        textFor: (item) => item.label,
                        onSelected: (item) => setState(() => _friendMaritalPreference = item),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDob(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack, required this.onSave});
  final VoidCallback onBack;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 16, 12),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF251538), size: 28)),
          const Expanded(child: Text('Edit Profile', style: TextStyle(color: Color(0xFF251538), fontSize: 22, fontWeight: FontWeight.w900))),
          InkWell(
            onTap: onSave,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFF251538), borderRadius: BorderRadius.circular(999)),
              child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarCard extends StatelessWidget {
  const _AvatarCard({required this.name, required this.onAvatarTap});
  final String name;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? 'V' : name.trim()[0].toUpperCase();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          InkWell(
            onTap: onAvatarTap,
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 37,
                  backgroundColor: const Color(0xFF6D5DF6),
                  child: Text(letter, style: const TextStyle(color: Colors.white, fontSize: 29, fontWeight: FontWeight.w900)),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(width: 25, height: 25, decoration: const BoxDecoration(color: Color(0xFF12C7B7), shape: BoxShape.circle), child: const Icon(Icons.edit_rounded, color: Colors.white, size: 15)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Text('Compact public profile data. Match score updates per viewer using preferences and common interests.', style: TextStyle(color: Color(0xFF7B6A86), height: 1.28, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _EditSection extends StatelessWidget {
  const _EditSection({required this.title, required this.children, this.subtitle});
  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF251538), fontSize: 17, fontWeight: FontWeight.w900)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, height: 1.25, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _CompactTextField extends StatelessWidget {
  const _CompactTextField({required this.label, required this.controller, this.maxLines = 1, this.maxLength, this.keyboardType, this.onChanged});
  final String label;
  final TextEditingController controller;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          counterText: '',
          filled: true,
          fillColor: const Color(0xFFFAF7F1),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFECE2D8))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFECE2D8))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFF12C7B7))),
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(color: const Color(0xFFFAF7F1), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFECE2D8))),
          child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(label, style: const TextStyle(color: Color(0xFF8C8198), fontSize: 11, fontWeight: FontWeight.w800)), Text(value, style: const TextStyle(color: Color(0xFF251538), fontWeight: FontWeight.w900))])), const Icon(Icons.expand_more_rounded)]),
        ),
      ),
    );
  }
}

class _DropdownTile extends StatelessWidget {
  const _DropdownTile({required this.label, required this.value, required this.values, required this.onChanged});
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        value: value,
        items: values.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        onChanged: (value) { if (value != null) onChanged(value); },
        decoration: InputDecoration(labelText: label, filled: true, fillColor: const Color(0xFFFAF7F1), border: OutlineInputBorder(borderRadius: BorderRadius.circular(18))),
      ),
    );
  }
}

class _OptionWrap<T> extends StatelessWidget {
  const _OptionWrap({required this.label, required this.values, required this.selected, required this.textFor, required this.onSelected});
  final String label;
  final List<T> values;
  final T selected;
  final String Function(T) textFor;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Color(0xFF251538), fontSize: 12.5, fontWeight: FontWeight.w900)),
        const SizedBox(height: 7),
        Wrap(spacing: 7, runSpacing: 7, children: values.map((item) {
          final active = item == selected;
          return InkWell(
            onTap: () => onSelected(item),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(color: active ? const Color(0xFF251538) : const Color(0xFFFAF7F1), borderRadius: BorderRadius.circular(999), border: Border.all(color: active ? const Color(0xFF251538) : const Color(0xFFECE2D8))),
              child: Text(textFor(item), style: TextStyle(color: active ? Colors.white : const Color(0xFF4A2A63), fontSize: 12, fontWeight: FontWeight.w900)),
            ),
          );
        }).toList()),
      ]),
    );
  }
}

class _InterestCategoryBlock extends StatelessWidget {
  const _InterestCategoryBlock({required this.category, required this.selected, required this.onToggle});
  final InterestCategory category;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(category.icon, color: const Color(0xFF6D5DF6), size: 17), const SizedBox(width: 6), Text(category.name, style: const TextStyle(color: Color(0xFF251538), fontWeight: FontWeight.w900))]),
        const SizedBox(height: 8),
        Wrap(spacing: 7, runSpacing: 7, children: category.interests.map((interest) {
          final active = selected.contains(interest);
          return InkWell(
            onTap: () => onToggle(interest),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(color: active ? const Color(0xFF12C7B7) : const Color(0xFFFAF7F1), borderRadius: BorderRadius.circular(999), border: Border.all(color: active ? const Color(0xFF12C7B7) : const Color(0xFFECE2D8))),
              child: Text(interest, style: TextStyle(color: active ? Colors.white : const Color(0xFF5F526B), fontSize: 11.5, fontWeight: FontWeight.w900)),
            ),
          );
        }).toList()),
      ]),
    );
  }
}

class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(14),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
      child: child,
    );
  }
}

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: const Color(0xFFECE2D8)),
    boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.035), blurRadius: 14, offset: const Offset(0, 7))],
  );
}
