import 'package:flutter/material.dart';

enum ProfileGender {
  male('Male'),
  female('Female'),
  other('Other'),
  preferNotToSay('Prefer not to say');

  const ProfileGender(this.label);
  final String label;
}

enum FriendGenderPreference {
  male('Male'),
  female('Female'),
  both('Both');

  const FriendGenderPreference(this.label);
  final String label;
}

enum MaritalStatus {
  single('Single'),
  married('Married'),
  committed('Committed'),
  divorced('Divorced');

  const MaritalStatus(this.label);
  final String label;
}

enum FriendMaritalPreference {
  any('Any status'),
  single('Single'),
  married('Married'),
  committed('Committed'),
  divorced('Divorced');

  const FriendMaritalPreference(this.label);
  final String label;
}

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

int calculateProfileMatchScore({
  required List<String> viewerInterests,
  required List<String> profileInterests,
  required FriendGenderPreference viewerGenderPreference,
  required ProfileGender profileGender,
  required FriendMaritalPreference viewerMaritalPreference,
  required MaritalStatus profileMaritalStatus,
  ProfileGender? viewerGender,
  FriendGenderPreference? profileGenderPreference,
}) {
  final viewerSet = viewerInterests.map((item) => item.toLowerCase()).toSet();
  final profileSet = profileInterests.map((item) => item.toLowerCase()).toSet();
  final commonCount = viewerSet.intersection(profileSet).length;
  final interestBase = profileSet.isEmpty ? 0 : ((commonCount / profileSet.length.clamp(1, 99)) * 70).round();
  final viewerAcceptsProfile = _genderPreferenceAccepts(
    preference: viewerGenderPreference,
    gender: profileGender,
  );
  final profileAcceptsViewer = viewerGender == null || profileGenderPreference == null
      ? true
      : _genderPreferenceAccepts(
          preference: profileGenderPreference,
          gender: viewerGender,
        );
  final genderMatch = viewerAcceptsProfile && profileAcceptsViewer;
  final maritalMatch = viewerMaritalPreference == FriendMaritalPreference.any || viewerMaritalPreference.label == profileMaritalStatus.label;
  return (interestBase + (genderMatch ? 15 : 0) + (maritalMatch ? 15 : 0)).clamp(0, 100);
}

bool _genderPreferenceAccepts({
  required FriendGenderPreference preference,
  required ProfileGender gender,
}) {
  return preference == FriendGenderPreference.both ||
      (preference == FriendGenderPreference.male && gender == ProfileGender.male) ||
      (preference == FriendGenderPreference.female && gender == ProfileGender.female);
}
