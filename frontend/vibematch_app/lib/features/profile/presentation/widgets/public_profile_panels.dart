import 'package:flutter/material.dart';

import 'public_profile_shared_widgets.dart';

class PublicBioPanel extends StatelessWidget {
  const PublicBioPanel({
    super.key,
    required this.bio,
    required this.age,
    required this.gender,
    required this.profession,
    required this.maritalStatus,
    required this.interests,
  });

  final String? bio;
  final int? age;
  final String? gender;
  final String? profession;
  final String? maritalStatus;
  final List<String> interests;

  bool get _hasAnyContent {
    return bio?.trim().isNotEmpty == true ||
        age != null ||
        gender?.trim().isNotEmpty == true ||
        profession?.trim().isNotEmpty == true ||
        maritalStatus?.trim().isNotEmpty == true ||
        interests.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasAnyContent) return const SizedBox.shrink();

    final statusChips = <Widget>[
      if (age != null)
        PublicTinyStatusChip(
          icon: Icons.cake_rounded,
          label: '${age!} yrs',
          color: const Color(0xFFE84C72),
        ),
      if (gender?.trim().isNotEmpty == true)
        PublicTinyStatusChip(
          icon: Icons.person_rounded,
          label: gender!.trim(),
          color: const Color(0xFF6D5DF6),
        ),
      if (profession?.trim().isNotEmpty == true)
        PublicTinyStatusChip(
          icon: Icons.work_rounded,
          label: profession!.trim(),
          color: const Color(0xFF12C7B7),
        ),
      if (maritalStatus?.trim().isNotEmpty == true)
        PublicTinyStatusChip(
          icon: Icons.favorite_rounded,
          label: maritalStatus!.trim(),
          color: const Color(0xFFE84C72),
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: publicProfileWhitePanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About',
            style: TextStyle(
              color: Color(0xFF251538),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (bio?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              bio!.trim(),
              style: const TextStyle(
                color: Color(0xFF5E5363),
                fontSize: 13.5,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (statusChips.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: statusChips,
            ),
          ],
          if (interests.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Interests',
              style: TextStyle(
                color: Color(0xFF251538),
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: interests
                  .map(
                    (interest) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF12C7B7).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: const Color(0xFF12C7B7).withValues(alpha: 0.20)),
                      ),
                      child: Text(
                        interest,
                        style: const TextStyle(
                          color: Color(0xFF251538),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class PublicFamilyPanel extends StatelessWidget {
  const PublicFamilyPanel({
    super.key,
    required this.familyName,
    required this.familyLevel,
    required this.onTap,
  });

  final String familyName;
  final int familyLevel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        decoration: publicProfileWhitePanelDecoration(),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF12C7B7).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.family_restroom_rounded,
                  color: Color(0xFF12C7B7),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      familyName,
                      style: const TextStyle(
                        color: Color(0xFF251538),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Family Lv.$familyLevel · Events, contribution and members',
                      style: const TextStyle(
                        color: Color(0xFF8C7B8F),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF8C7B8F),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
