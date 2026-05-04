import 'package:flutter/material.dart';

import '../../models/inbox_models.dart';

class InboxSettingsPage extends StatelessWidget {
  const InboxSettingsPage({
    super.key,
    required this.backupEnabled,
    required this.frequency,
    required this.onBackupEnabledChanged,
    required this.onFrequencyChanged,
    required this.onBackupNow,
    required this.onRestoreTap,
    required this.onBackTap,
  });

  final bool backupEnabled;
  final ChatBackupFrequency frequency;
  final ValueChanged<bool> onBackupEnabledChanged;
  final ValueChanged<ChatBackupFrequency> onFrequencyChanged;
  final VoidCallback onBackupNow;
  final VoidCallback onRestoreTap;
  final VoidCallback onBackTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
          children: [
            Row(
              children: [
                IconButton(onPressed: onBackTap, icon: const Icon(Icons.arrow_back_rounded)),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Inbox Settings',
                    style: TextStyle(
                      color: Color(0xFF251538),
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Icon(Icons.settings_rounded, color: Color(0xFF4A2A63)),
              ],
            ),
            const SizedBox(height: 10),
            _SettingsCard(
              child: Column(
                children: [
                  SwitchListTile(
                    value: backupEnabled,
                    onChanged: onBackupEnabledChanged,
                    activeThumbColor: const Color(0xFF12C7B7),
                    title: const Text(
                      'Chat backup',
                      style: TextStyle(color: Color(0xFF251538), fontWeight: FontWeight.w900),
                    ),
                    subtitle: const Text(
                      'Back up chats securely like WhatsApp-style backup flow. Backend/Drive encryption connects later.',
                      style: TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Divider(color: Color(0xFFECE2D8)),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Backup frequency',
                      style: TextStyle(color: Color(0xFF251538), fontSize: 14, fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ChatBackupFrequency.values.map((item) {
                      final selected = item == frequency;
                      return InkWell(
                        onTap: () => onFrequencyChanged(item),
                        borderRadius: BorderRadius.circular(999),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            color: selected ? const Color(0xFF251538) : const Color(0xFFFAF7F1),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: selected ? const Color(0xFF251538) : const Color(0xFFECE2D8)),
                          ),
                          child: Text(
                            item.label,
                            style: TextStyle(
                              color: selected ? Colors.white : const Color(0xFF4A2A63),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SettingsCard(
              child: Column(
                children: [
                  _ActionRow(
                    icon: Icons.cloud_upload_rounded,
                    title: 'Back up now',
                    subtitle: 'Create a fresh encrypted backup later.',
                    onTap: onBackupNow,
                  ),
                  const Divider(color: Color(0xFFECE2D8)),
                  _ActionRow(
                    icon: Icons.restore_rounded,
                    title: 'Restore from backup',
                    subtitle: 'Restore from Google Drive / cloud backup later.',
                    onTap: onRestoreTap,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SettingsCard(
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_rounded, color: Color(0xFF4A2A63), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Locked chats are backend account-level locks. They stay hidden and protected on every device after login.',
                      style: TextStyle(color: Color(0xFF7B6A86), fontSize: 12, height: 1.35, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFECE2D8)),
      ),
      child: child,
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF8C5CF6).withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: const Color(0xFF8C5CF6), size: 21),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Color(0xFF251538), fontSize: 13.5, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF9B8CA5)),
          ],
        ),
      ),
    );
  }
}
