import 'package:flutter/material.dart';

enum ProfileGender {
  male('Male', 'male'),
  female('Female', 'female'),
  other('Other', 'other'),
  preferNotToSay('Prefer not to say', 'prefer_not_to_say');

  const ProfileGender(this.label, this.wireValue);
  final String label;
  final String wireValue;
}

enum FriendGenderPreference {
  male('Male', 'male'),
  female('Female', 'female'),
  both('Both', 'both');

  const FriendGenderPreference(this.label, this.wireValue);
  final String label;
  final String wireValue;
}

enum MaritalStatus {
  single('Single', 'single'),
  married('Married', 'married'),
  committed('Committed', 'committed'),
  divorced('Divorced', 'divorced');

  const MaritalStatus(this.label, this.wireValue);
  final String label;
  final String wireValue;
}

enum FriendMaritalPreference {
  any('Any status', 'any'),
  single('Single', 'single'),
  married('Married', 'married'),
  committed('Committed', 'committed'),
  divorced('Divorced', 'divorced');

  const FriendMaritalPreference(this.label, this.wireValue);
  final String label;
  final String wireValue;
}

ProfileGender? profileGenderFromWire(String? value) {
  final normalized = _normalizeWire(value);
  if (normalized.isEmpty) return null;
  for (final item in ProfileGender.values) {
    if (item.wireValue == normalized) return item;
  }
  return null;
}

ProfileGender profileGenderForEdit(String? value) => profileGenderFromWire(value) ?? ProfileGender.preferNotToSay;

FriendGenderPreference? friendGenderPreferenceFromWire(String? value) {
  final normalized = _normalizeWire(value);
  if (normalized.isEmpty) return null;
  for (final item in FriendGenderPreference.values) {
    if (item.wireValue == normalized) return item;
  }
  return null;
}

FriendGenderPreference friendGenderPreferenceForEdit(String? value) => friendGenderPreferenceFromWire(value) ?? FriendGenderPreference.both;

MaritalStatus? maritalStatusFromWire(String? value) {
  final normalized = _normalizeWire(value);
  if (normalized.isEmpty) return null;
  for (final item in MaritalStatus.values) {
    if (item.wireValue == normalized) return item;
  }
  return null;
}

MaritalStatus maritalStatusForEdit(String? value) => maritalStatusFromWire(value) ?? MaritalStatus.single;

FriendMaritalPreference? friendMaritalPreferenceFromWire(String? value) {
  final normalized = _normalizeWire(value);
  if (normalized.isEmpty) return null;
  for (final item in FriendMaritalPreference.values) {
    if (item.wireValue == normalized) return item;
  }
  return null;
}

FriendMaritalPreference friendMaritalPreferenceForEdit(String? value) => friendMaritalPreferenceFromWire(value) ?? FriendMaritalPreference.any;

String? displayGenderFromWire(String? value) => profileGenderFromWire(value)?.label;
String? displayMaritalFromWire(String? value) => maritalStatusFromWire(value)?.label;
String _normalizeWire(String? value) => value?.trim().toLowerCase().replaceAll(' ', '_').replaceAll('-', '_') ?? '';

class InterestCategory {
  const InterestCategory({required this.name, required this.icon, required this.interests});
  final String name;
  final IconData icon;
  final List<String> interests;
}

class ProfessionOption {
  const ProfessionOption(this.label, this.icon);
  final String label;
  final IconData icon;
}

const List<InterestCategory> profileInterestCategories = [
  InterestCategory(name: 'Music', icon: Icons.music_note_rounded, interests: ['Singing', 'Bollywood', 'Tollywood', 'DJ Nights', 'Karaoke', 'Lo-fi']),
  InterestCategory(name: 'Gaming', icon: Icons.sports_esports_rounded, interests: ['Ludo', 'Carrom', 'BGMI', 'Free Fire', 'Chess', 'Cricket Games']),
  InterestCategory(name: 'Lifestyle', icon: Icons.local_fire_department_rounded, interests: ['Fitness', 'Travel', 'Fashion', 'Food', 'Movies', 'Photography']),
  InterestCategory(name: 'Social', icon: Icons.people_alt_rounded, interests: ['Make Friends', 'Family Rooms', 'Love Vibes', 'Deep Talks', 'Comedy', 'Events']),
  InterestCategory(name: 'Career', icon: Icons.work_rounded, interests: ['Business', 'Tech', 'Design', 'Creator', 'Student Life', 'Finance']),
];

const List<ProfessionOption> profileProfessionOptions = [
  ProfessionOption('Unemployed', Icons.hourglass_empty_rounded),
  ProfessionOption('Student', Icons.school_rounded),
  ProfessionOption('Software Engineer', Icons.code_rounded),
  ProfessionOption('Creator / Influencer', Icons.video_camera_front_rounded),
  ProfessionOption('Business Owner', Icons.storefront_rounded),
  ProfessionOption('Designer', Icons.brush_rounded),
  ProfessionOption('Doctor / Healthcare', Icons.local_hospital_rounded),
  ProfessionOption('Teacher', Icons.menu_book_rounded),
  ProfessionOption('Government Employee', Icons.account_balance_rounded),
  ProfessionOption('Other', Icons.work_outline_rounded),
];

int? calculateProfileMatchScore({
  required List<String> viewerInterests,
  required List<String> profileInterests,
  required FriendGenderPreference? viewerGenderPreference,
  required ProfileGender? profileGender,
  required FriendMaritalPreference? viewerMaritalPreference,
  required MaritalStatus? profileMaritalStatus,
  required ProfileGender? viewerGender,
  required FriendGenderPreference? profileGenderPreference,
}) {
  if (viewerGenderPreference == null || profileGender == null || viewerGender == null || profileGenderPreference == null) return null;

  final viewerAcceptsProfile = _genderPreferenceAccepts(preference: viewerGenderPreference, gender: profileGender);
  final profileAcceptsViewer = _genderPreferenceAccepts(preference: profileGenderPreference, gender: viewerGender);
  if (!viewerAcceptsProfile || !profileAcceptsViewer) return 0;

  var score = 35;
  final viewerSet = viewerInterests.map((item) => item.trim().toLowerCase()).where((item) => item.isNotEmpty).toSet();
  final profileSet = profileInterests.map((item) => item.trim().toLowerCase()).where((item) => item.isNotEmpty).toSet();
  if (viewerSet.isNotEmpty && profileSet.isNotEmpty) {
    final commonCount = viewerSet.intersection(profileSet).length;
    final maxCount = viewerSet.length > profileSet.length ? viewerSet.length : profileSet.length;
    score += ((commonCount / maxCount.clamp(1, 99)) * 45).round();
  }

  if (viewerMaritalPreference == null || viewerMaritalPreference == FriendMaritalPreference.any || profileMaritalStatus == null || viewerMaritalPreference.wireValue == profileMaritalStatus.wireValue) score += 20;
  return score.clamp(0, 100);
}

bool _genderPreferenceAccepts({required FriendGenderPreference preference, required ProfileGender gender}) {
  if (preference == FriendGenderPreference.both) return true;
  return (preference == FriendGenderPreference.male && gender == ProfileGender.male) || (preference == FriendGenderPreference.female && gender == ProfileGender.female);
}
