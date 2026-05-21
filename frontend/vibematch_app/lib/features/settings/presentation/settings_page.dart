import 'package:flutter/material.dart';

import '../../inbox/presentation/inbox_page.dart';
import '../../profile/presentation/help_center/help_center_page.dart';
import '../../profile/presentation/settings/account_settings_page.dart';
import '../../profile/presentation/settings/account_settings_store.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  AccountSettingsState? _state;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final state = await AccountSettingsStore.load();
      if (!mounted) return;
      setState(() {
        _state = state;
        _loadError = null;
      });
    } catch (error) {
      if (mounted) setState(() => _loadError = error.toString());
    }
  }

  Future<void> _save(AccountSettingsState state, String message) async {
    final previous = _state;
    setState(() => _state = state);
    try {
      await AccountSettingsStore.save(state);
      if (mounted) _toast(message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _state = previous);
      _toast(error.toString());
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF111114),
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      );
  }

  void _open(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  Future<void> _chooseLanguage() async {
    final state = _state;
    if (state == null) return;
    final language = await _choiceSheet(
      title: 'Language',
      selected: state.language,
      choices: const <String>[
        'English',
        'Hindi',
        'Telugu',
        'Tamil',
        'Kannada',
        'Malayalam',
      ],
    );
    if (language != null)
      await _save(state.copyWith(language: language), 'Language saved.');
  }

  Future<void> _chooseAppearance() async {
    final state = _state;
    if (state == null) return;
    final appearance = await _choiceSheet(
      title: 'Appearance',
      selected: state.appearance,
      choices: const <String>['System', 'Light', 'Dark'],
    );
    if (appearance != null)
      await _save(state.copyWith(appearance: appearance), 'Appearance saved.');
  }

  Future<void> _chooseWallpaper() async {
    final state = _state;
    if (state == null) return;
    final wallpaper = await _choiceSheet(
      title: 'Chat wallpaper',
      selected: state.chatWallpaper,
      choices: const <String>['Pearl', 'Clean white', 'Soft grey', 'Midnight'],
    );
    if (wallpaper != null)
      await _save(
        state.copyWith(chatWallpaper: wallpaper),
        'Default chat wallpaper saved.',
      );
  }

  Future<String?> _choiceSheet({
    required String title,
    required String selected,
    required List<String> choices,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _ChoiceSheet(title: title, selected: selected, choices: choices),
    );
  }

  void _openBlockedUsers() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _BlockedUsersSheet(onToast: _toast),
    );
  }

  Future<void> _toggleDeviceTrust(bool value) async {
    final state = _state;
    if (state == null) return;
    await _save(
      state.copyWith(deviceTrustEnabled: value),
      value
          ? 'Trusted device prompts enabled.'
          : 'Trusted device prompts paused.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: _loadError != null
            ? _SettingsUnavailable(message: _loadError!, onRetry: _load)
            : state == null
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF3797F0),
                  strokeWidth: 2.4,
                ),
              )
            : ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                children: [
                  _Header(onBack: () => Navigator.maybePop(context)),
                  const SizedBox(height: 12),
                  _Section(
                    title: 'Account',
                    children: [
                      _SettingsRow(
                        icon: Icons.person_outline_rounded,
                        title: 'Profile and account settings',
                        subtitle:
                            'Privacy, notifications, tones and profile visibility.',
                        onTap: () =>
                            _open(const AccountSettingsPage(svipLevel: 0)),
                      ),
                      _SettingsRow(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacy settings',
                        subtitle: 'Shared backend settings source.',
                        onTap: () =>
                            _open(const AccountSettingsPage(svipLevel: 0)),
                      ),
                      _SettingsRow(
                        icon: Icons.notifications_none_rounded,
                        title: 'Notification settings',
                        subtitle: 'Alerts, rooms, gifts, mentions and sounds.',
                        onTap: () =>
                            _open(const AccountSettingsPage(svipLevel: 0)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _Section(
                    title: 'Inbox and Chat',
                    children: [
                      _SettingsRow(
                        icon: Icons.lock_outline_rounded,
                        title: 'Inbox lock settings',
                        subtitle:
                            'Open Inbox settings to manage lock and recovery.',
                        onTap: () {
                          _open(const InboxPage());
                          _toast(
                            'Open the settings icon in Inbox for lock controls.',
                          );
                        },
                      ),
                      _SettingsRow(
                        icon: Icons.wallpaper_rounded,
                        title: 'Chat wallpaper',
                        subtitle: state.chatWallpaper,
                        onTap: _chooseWallpaper,
                      ),
                      _SettingsRow(
                        icon: Icons.block_rounded,
                        title: 'Blocked users',
                        subtitle: 'Synced from backend block list.',
                        onTap: _openBlockedUsers,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _Section(
                    title: 'App',
                    children: [
                      _SettingsRow(
                        icon: Icons.language_rounded,
                        title: 'Language',
                        subtitle: state.language,
                        onTap: _chooseLanguage,
                      ),
                      _SettingsRow(
                        icon: Icons.contrast_rounded,
                        title: 'Appearance',
                        subtitle: state.appearance,
                        onTap: _chooseAppearance,
                      ),
                      _SwitchSettingsRow(
                        icon: Icons.devices_rounded,
                        title: 'Trusted device prompts',
                        subtitle: 'Saved in backend user settings.',
                        value: state.deviceTrustEnabled,
                        onChanged: _toggleDeviceTrust,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _Section(
                    title: 'Support',
                    children: [
                      _SettingsRow(
                        icon: Icons.support_agent_rounded,
                        title: 'Help & Support',
                        subtitle: 'Vibe Match Team · AI Assistant and tickets.',
                        onTap: () => _open(const HelpCenterPage()),
                      ),
                      _SettingsRow(
                        icon: Icons.bug_report_outlined,
                        title: 'Report a problem',
                        subtitle:
                            'Create a support ticket for account, room or payment issues.',
                        onTap: () => _open(const HelpCenterPage()),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _SettingsUnavailable extends StatelessWidget {
  const _SettingsUnavailable({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: Color(0xFF71717A),
              size: 38,
            ),
            const SizedBox(height: 10),
            const Text(
              'Settings unavailable',
              style: TextStyle(
                color: Color(0xFF111114),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF71717A),
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(
            Icons.arrow_back_rounded,
            size: 23,
            color: Color(0xFF111114),
          ),
        ),
        const Expanded(
          child: Text(
            'Settings',
            style: TextStyle(
              color: Color(0xFF111114),
              fontSize: 25,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF71717A),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEDEDEF)),
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
                  const Divider(
                    height: 1,
                    indent: 56,
                    color: Color(0xFFEDEDEF),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 54),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF111114), size: 20),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF111114),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF71717A),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFB8B8C0),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchSettingsRow extends StatelessWidget {
  const _SwitchSettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 54),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF111114), size: 20),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF111114),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF71717A),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              activeThumbColor: const Color(0xFF3797F0),
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceSheet extends StatelessWidget {
  const _ChoiceSheet({
    required this.title,
    required this.selected,
    required this.choices,
  });

  final String title;
  final String selected;
  final List<String> choices;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFEDEDEF)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF111114),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            ...choices.map(
              (choice) => ListTile(
                onTap: () => Navigator.pop(context, choice),
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  choice,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                trailing: choice == selected
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF3797F0),
                        size: 20,
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockedUsersSheet extends StatefulWidget {
  const _BlockedUsersSheet({required this.onToast});

  final ValueChanged<String> onToast;

  @override
  State<_BlockedUsersSheet> createState() => _BlockedUsersSheetState();
}

class _BlockedUsersSheetState extends State<_BlockedUsersSheet> {
  late Future<List<BlockedUserSetting>> _future =
      AccountSettingsStore.loadBlockedUsers();

  Future<void> _unblock(BlockedUserSetting user) async {
    try {
      final users = await AccountSettingsStore.unblockUser(user.publicUserId);
      if (!mounted) return;
      setState(() => _future = Future<List<BlockedUserSetting>>.value(users));
      widget.onToast('${user.displayName} unblocked.');
    } catch (error) {
      widget.onToast(error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFEDEDEF)),
      ),
      child: SafeArea(
        top: false,
        child: FutureBuilder<List<BlockedUserSetting>>(
          future: _future,
          builder: (context, snapshot) {
            final users = snapshot.data ?? const <BlockedUserSetting>[];
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Blocked users',
                        style: TextStyle(
                          color: Color(0xFF111114),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF3797F0),
                        strokeWidth: 2.2,
                      ),
                    ),
                  )
                else if (snapshot.hasError)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      snapshot.error.toString(),
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else if (users.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'No blocked users.',
                      style: TextStyle(
                        color: Color(0xFF71717A),
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  ...users.map(
                    (user) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFF4F4F5),
                        child: Text(_initial(user.displayName)),
                      ),
                      title: Text(
                        user.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: user.username == null
                          ? null
                          : Text('@${user.username}'),
                      trailing: TextButton(
                        onPressed: () => _unblock(user),
                        child: const Text('Unblock'),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _initial(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }
}
