import 'package:flutter/material.dart';

class MeFamilyDetailsSheet extends StatelessWidget {
  const MeFamilyDetailsSheet({
    super.key,
    required this.familyName,
    required this.familyLevel,
    required this.familyId,
    required this.rankLabel,
    required this.memberRole,
    required this.memberCount,
    required this.totalExp,
    required this.onOpenFamily,
  });

  final String familyName;
  final int familyLevel;
  final String familyId;
  final String rankLabel;
  final String memberRole;
  final int memberCount;
  final int totalExp;
  final VoidCallback onOpenFamily;

  String get _avatarText => familyName.trim().isEmpty ? 'F' : familyName.trim()[0].toUpperCase();

  String get _familyTier {
    if (familyLevel >= 30) return 'Platinum';
    if (familyLevel >= 20) return 'Gold';
    if (familyLevel >= 10) return 'Silver';
    return 'Bronze';
  }

  String _compact(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(14),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 42, height: 5, decoration: BoxDecoration(color: const Color(0xFFE0D5CB), borderRadius: BorderRadius.circular(999))),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF100A18),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFFFD36A).withValues(alpha: 0.18)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: const LinearGradient(colors: [Color(0xFF251538), Color(0xFFE84C72), Color(0xFFFFD36A)]),
                      boxShadow: [BoxShadow(color: const Color(0xFFFFD36A).withValues(alpha: 0.18), blurRadius: 20, offset: const Offset(0, 8))],
                    ),
                    child: Center(child: Text(_avatarText, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(familyName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            _DarkPill(icon: Icons.tag_rounded, label: familyId),
                            _DarkPill(icon: Icons.leaderboard_rounded, label: rankLabel),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _InfoTile(icon: Icons.military_tech_rounded, label: 'Family Level', value: _familyTier)),
                const SizedBox(width: 10),
                Expanded(child: _InfoTile(icon: Icons.admin_panel_settings_rounded, label: 'Your Role', value: memberRole)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _InfoTile(icon: Icons.groups_rounded, label: 'Members', value: '$memberCount')),
                const SizedBox(width: 10),
                Expanded(child: _InfoTile(icon: Icons.auto_graph_rounded, label: 'Total EXP', value: _compact(totalExp))),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFFF4E8), borderRadius: BorderRadius.circular(18)),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: Color(0xFFC99A3B), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This tag shows your current family. Open the full Family page from the Account section below to manage, invite, chat, rankings, and requests.',
                      style: TextStyle(color: Color(0xFF251538), height: 1.3, fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SecondaryButton(label: 'Close', onTap: () => Navigator.pop(context)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PrimaryButton(
                    label: 'Open Family',
                    onTap: () {
                      Navigator.pop(context);
                      onOpenFamily();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFFAF7F1), borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF6D5DF6), size: 19),
          const SizedBox(height: 8),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF251538), fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _DarkPill extends StatelessWidget {
  const _DarkPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.28), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withValues(alpha: 0.10))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: const Color(0xFFFFD36A), size: 13), const SizedBox(width: 4), Text(label, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900))]),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 50,
        decoration: BoxDecoration(color: const Color(0xFF251538), borderRadius: BorderRadius.circular(18)),
        child: Center(child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 50,
        decoration: BoxDecoration(color: const Color(0xFFFAF7F1), borderRadius: BorderRadius.circular(18)),
        child: Center(child: Text(label, style: const TextStyle(color: Color(0xFF251538), fontWeight: FontWeight.w900))),
      ),
    );
  }
}
