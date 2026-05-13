import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/data/auth_api_service.dart';
import '../../auth/models/current_user.dart';
import '../../control_center/presentation/control_center_page.dart';
import '../../family/models/family_ui_models.dart';
import '../../family/presentation/family_modular_page.dart';
import '../../presence/data/presence_api_service.dart';
import '../../vip/presentation/vip_program_page.dart';
import '../../wallet/data/wallet_api_service.dart';
import '../../wallet/presentation/wallet_page_modular.dart';
import '../data/profile_api_service.dart';
import 'edit_profile_page.dart';
import 'profile_qr/profile_qr_pages.dart';
import 'public_profile_view_page.dart';
import 'settings/account_settings_page.dart';
import 'store/store_page.dart';

class MePage extends StatefulWidget {
  const MePage({
    super.key,
    required this.user,
    required this.onLogoutPressed,
    required this.onRefreshPressed,
  });

  final CurrentUser user;
  final Future<void> Function() onLogoutPressed;
  final Future<void> Function() onRefreshPressed;

  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> {
  final ProfileApiService _profileApi = const ProfileApiService();
  final WalletApiService _walletApi = const WalletApiService();
  final PresenceApiService _presenceApi = const PresenceApiService();

  CurrentUser? _user;
  VmWallet? _wallet;
  FamilySummaryDto? _family;
  PresenceDto? _presence;
  bool _loading = true;
  String? _error;

  CurrentUser get _visibleUser => _user ?? widget.user;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    unawaited(_loadRealData());
  }

  @override
  void didUpdateWidget(covariant MePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.publicUserId != widget.user.publicUserId) {
      _user = widget.user;
      unawaited(_loadRealData());
    }
  }

  Future<void> _loadRealData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await _profileApi.getMe(forceRefresh: true);
      final results = await Future.wait<Object?>([
        _walletApi.getWallet(),
        _profileApi.getMyFamily(),
        _presenceApi.getPublicPresence(user.publicUserId),
      ]);
      if (!mounted) return;
      setState(() {
        _user = user;
        _wallet = results[0] as VmWallet;
        _family = results[1] as FamilySummaryDto;
        _presence = results[2] as PresenceDto;
        _loading = false;
      });
      AuthUserRealtimeService.instance.publish(user);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
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

  String _name(CurrentUser user) {
    final display = user.displayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final username = user.username?.trim();
    if (username != null && username.isNotEmpty) return username;
    return 'User ${user.publicUserId}';
  }

  String _format(int value) {
    if (value >= 10000000) return '${(value / 10000000).toStringAsFixed(value >= 100000000 ? 0 : 1)}Cr';
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(value >= 1000000 ? 0 : 1)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
    return value.toString();
  }

  void _openWallet() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WalletPageModular()));
  }

  void _openPublicProfile() {
    final user = _visibleUser;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PublicProfileViewPage(
          user: user,
          publicUserId: user.publicUserId,
          vipLevel: _wallet?.vipLevel ?? user.vip.vipLevel,
          svipLevel: _wallet?.svipLevel ?? user.vip.svipLevel,
          presenceLabel: _presence?.onlineLabel ?? 'Offline',
          currentRoomName: _presence?.roomName,
          relationshipLabel: '',
          familyName: _family?.shouldShow == true ? _family!.safeName : '',
          familyLevel: _family?.level ?? 0,
        ),
      ),
    );
  }

  void _openFamily() {
    final family = _family;
    if (family == null || !family.shouldShow) {
      _toast('You are not in a family yet.');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FamilyModularPage(
          openCurrentFamily: true,
          initialFamilyProfile: FamilyProfileUiModel(
            id: family.safeId,
            name: family.safeName,
            minimumVipLabel: 'VIP 0',
            memberCount: family.memberCount,
            maxMembers: family.memberCount > 0 ? family.memberCount : 1,
            rankLabel: 'Family Lv. ${family.level}',
            ownerUserId: family.ownerPublicUserId?.toString() ?? '',
            quarterCarryExp: family.totalExp,
            giftCoinsThisQuarter: family.totalExp,
            timeMinutesToday: 0,
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await widget.onLogoutPressed();
  }

  @override
  Widget build(BuildContext context) {
    final user = _visibleUser;
    final wallet = _wallet;
    final family = _family;
    final presence = _presence;
    final vipLevel = wallet?.vipLevel ?? user.vip.vipLevel;
    final svipLevel = wallet?.svipLevel ?? user.vip.svipLevel;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF12C7B7),
          onRefresh: _loadRealData,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 116),
            children: [
              if (_loading) const LinearProgressIndicator(minHeight: 3, color: Color(0xFF12C7B7), backgroundColor: Color(0xFFECE2D8)),
              if (_error != null) _BackendErrorCard(message: _error!, onRetry: _loadRealData),
              _RealProfileHero(
                displayName: _name(user),
                publicId: user.visibleId,
                roleLabel: user.roleDisplayLabel,
                showOfficialTick: user.shouldShowOfficialYellowTick,
                avatarUrl: user.avatarUrl,
                coverPhotoUrls: user.coverPhotoUrls,
                vipLevel: vipLevel,
                svipLevel: svipLevel,
                coinBalance: wallet?.coinBalance ?? user.wallet.coinBalance,
                rubyBalance: wallet?.rubyBalance ?? user.wallet.rubyBalance,
                lifetimeRecharge: wallet?.lifetimeRechargeCoins ?? user.wallet.lifetimeCoinsSpent,
                presenceLabel: presence?.onlineLabel ?? _presenceLabelFromUser(user),
                roomName: presence?.hasVisibleRoom == true ? presence!.roomName : null,
                familyName: family?.shouldShow == true ? family!.safeName : '',
                familyLevel: family?.level ?? 0,
                onAvatarTap: _openPublicProfile,
                onQrTap: () => ProfileQrActionsSheet.show(context, user: user),
                onWalletTap: _openWallet,
                onFamilyTap: _openFamily,
                onVipTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => VipProgramPage(vipLevel: vipLevel, svipLevel: svipLevel, lifetimeRechargeCoins: wallet?.lifetimeRechargeCoins ?? 0, monthlyRechargeCoins: wallet?.monthlyRechargeCoins ?? 0))),
              ),
              const SizedBox(height: 14),
              _WalletSnapshotCard(wallet: wallet, format: _format, onTap: _openWallet),
              const SizedBox(height: 18),
              const Text('Account', style: TextStyle(color: Color(0xFF251538), fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
              const SizedBox(height: 12),
              _RealActionCard(icon: Icons.edit_rounded, title: 'Edit Profile', subtitle: 'Update real profile data', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditProfilePage(user: user))).then((_) => _loadRealData())),
              _RealActionCard(icon: Icons.account_balance_wallet_rounded, title: 'Wallet', subtitle: 'Real coins, Ruby, VIP and SVIP', onTap: _openWallet),
              _RealActionCard(icon: Icons.workspace_premium_rounded, title: 'VIP / SVIP Center', subtitle: 'Recharge-based levels', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => VipProgramPage(vipLevel: vipLevel, svipLevel: svipLevel, lifetimeRechargeCoins: wallet?.lifetimeRechargeCoins ?? 0, monthlyRechargeCoins: wallet?.monthlyRechargeCoins ?? 0)))),
              _RealActionCard(icon: Icons.groups_rounded, title: 'Family', subtitle: family?.shouldShow == true ? family!.safeName : 'No family joined', onTap: _openFamily),
              _RealActionCard(icon: Icons.storefront_rounded, title: 'Store & Inventory', subtitle: 'Open store', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VmStorePage()))),
              if (user.canSeeOwnerControls) _RealActionCard(icon: Icons.admin_panel_settings_rounded, title: 'Control Center', subtitle: 'Official backend control panel', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ControlCenterPage()))),
              _RealActionCard(icon: Icons.settings_rounded, title: 'Settings', subtitle: 'Account settings', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AccountSettingsPage(svipLevel: svipLevel)))),
              _RealActionCard(icon: Icons.refresh_rounded, title: 'Refresh', subtitle: 'Reload from backend', onTap: _loadRealData),
              _RealActionCard(icon: Icons.logout_rounded, title: 'Logout', subtitle: 'End current session', danger: true, onTap: _logout),
            ],
          ),
        ),
      ),
    );
  }

  String _presenceLabelFromUser(CurrentUser user) {
    final seen = user.lastSeenAt;
    if (seen == null) return 'Offline';
    final diff = DateTime.now().difference(seen.toLocal());
    if (diff.inMinutes < 1) return 'last seen just now';
    if (diff.inMinutes < 60) return 'last seen ${diff.inMinutes} min ago';
    if (diff.inHours < 24) return 'last seen ${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    if (diff.inDays < 30) return 'last seen ${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    return 'last seen a month ago';
  }
}

class _RealProfileHero extends StatelessWidget {
  const _RealProfileHero({required this.displayName, required this.publicId, required this.roleLabel, required this.showOfficialTick, required this.avatarUrl, required this.coverPhotoUrls, required this.vipLevel, required this.svipLevel, required this.coinBalance, required this.rubyBalance, required this.lifetimeRecharge, required this.presenceLabel, required this.roomName, required this.familyName, required this.familyLevel, required this.onAvatarTap, required this.onQrTap, required this.onWalletTap, required this.onFamilyTap, required this.onVipTap});

  final String displayName;
  final String publicId;
  final String roleLabel;
  final bool showOfficialTick;
  final String? avatarUrl;
  final List<String> coverPhotoUrls;
  final int vipLevel;
  final int svipLevel;
  final int coinBalance;
  final int rubyBalance;
  final int lifetimeRecharge;
  final String presenceLabel;
  final String? roomName;
  final String familyName;
  final int familyLevel;
  final VoidCallback onAvatarTap;
  final VoidCallback onQrTap;
  final VoidCallback onWalletTap;
  final VoidCallback onFamilyTap;
  final VoidCallback onVipTap;

  @override
  Widget build(BuildContext context) {
    final cover = coverPhotoUrls.isNotEmpty ? coverPhotoUrls.first : null;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), color: Colors.white, border: Border.all(color: const Color(0xFFECE2D8)), boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.06), blurRadius: 24, offset: const Offset(0, 10))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          height: 132,
          width: double.infinity,
          child: Stack(fit: StackFit.expand, children: [
            if (cover != null) Image.network(cover, fit: BoxFit.cover) else Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF251538), Color(0xFF6D5DF6), Color(0xFFE84C72)]))),
            DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withValues(alpha: 0.05), Colors.black.withValues(alpha: 0.45)]))),
            Positioned(right: 12, top: 12, child: IconButton.filledTonal(onPressed: onQrTap, icon: const Icon(Icons.qr_code_2_rounded))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Transform.translate(
              offset: const Offset(0, -30),
              child: GestureDetector(
                onTap: onAvatarTap,
                child: CircleAvatar(radius: 36, backgroundColor: Colors.white, child: CircleAvatar(radius: 32, backgroundImage: avatarUrl == null ? null : NetworkImage(avatarUrl!), child: avatarUrl == null ? Text(displayName.isEmpty ? 'U' : displayName[0].toUpperCase(), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)) : null)),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Expanded(child: Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF251538), fontSize: 24, fontWeight: FontWeight.w900))), if (showOfficialTick) const Icon(Icons.verified_rounded, color: Color(0xFFFFC857), size: 22)]),
                const SizedBox(height: 5),
                Text('ID $publicId • $roleLabel', style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 12, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _HeroPill(label: 'VIP $vipLevel', icon: Icons.workspace_premium_rounded, onTap: onVipTap),
                  _HeroPill(label: 'SVIP $svipLevel', icon: Icons.diamond_rounded, onTap: onVipTap),
                  _HeroPill(label: '${_compact(coinBalance)} coins', icon: Icons.monetization_on_rounded, onTap: onWalletTap),
                  _HeroPill(label: '${_compact(rubyBalance)} Ruby', icon: Icons.diamond_outlined, onTap: onWalletTap),
                ]),
                const SizedBox(height: 10),
                Text(presenceLabel, style: const TextStyle(color: Color(0xFF12A99E), fontSize: 12, fontWeight: FontWeight.w900)),
                if (roomName != null) Text('In chatroom: $roomName', style: const TextStyle(color: Color(0xFF4A2A63), fontSize: 12, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                InkWell(onTap: onFamilyTap, borderRadius: BorderRadius.circular(18), child: Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFAF7F1), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFECE2D8))), child: Row(children: [const Icon(Icons.groups_rounded, color: Color(0xFF6D5DF6)), const SizedBox(width: 9), Expanded(child: Text(familyName.isEmpty ? 'No family joined' : '$familyName • Lv. $familyLevel', style: const TextStyle(color: Color(0xFF251538), fontWeight: FontWeight.w900))), const Icon(Icons.chevron_right_rounded)]))),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  static String _compact(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
    return '$value';
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ActionChip(avatar: Icon(icon, size: 16), label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)), onPressed: onTap);
}

class _WalletSnapshotCard extends StatelessWidget {
  const _WalletSnapshotCard({required this.wallet, required this.format, required this.onTap});
  final VmWallet? wallet;
  final String Function(int) format;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final wallet = this.wallet;
    return _WhiteCard(children: [
      Row(children: [const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFC99A3B)), const SizedBox(width: 8), const Expanded(child: Text('Real Wallet', style: TextStyle(color: Color(0xFF251538), fontSize: 17, fontWeight: FontWeight.w900))), TextButton(onPressed: onTap, child: const Text('Open'))]),
      const SizedBox(height: 10),
      if (wallet == null) const Text('Wallet data is loading from backend.', style: TextStyle(color: Color(0xFF7B6A86), fontWeight: FontWeight.w700)) else Wrap(spacing: 8, runSpacing: 8, children: [
        _Metric(label: 'Coins', value: format(wallet.coinBalance)),
        _Metric(label: 'Ruby', value: format(wallet.rubyBalance)),
        _Metric(label: 'Lifetime recharge', value: format(wallet.lifetimeRechargeCoins)),
        _Metric(label: 'Monthly recharge', value: format(wallet.monthlyRechargeCoins)),
      ]),
    ]);
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: const Color(0xFFFAF7F1), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFECE2D8))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 10.5, fontWeight: FontWeight.w800)), Text(value, style: const TextStyle(color: Color(0xFF251538), fontSize: 14, fontWeight: FontWeight.w900))]));
}

class _RealActionCard extends StatelessWidget {
  const _RealActionCard({required this.icon, required this.title, required this.subtitle, required this.onTap, this.danger = false});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 12), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(22), child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFECE2D8))), child: Row(children: [Icon(icon, color: danger ? const Color(0xFFE84C72) : const Color(0xFF6D5DF6)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: danger ? const Color(0xFFE84C72) : const Color(0xFF251538), fontSize: 15, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 12, fontWeight: FontWeight.w700))])), const Icon(Icons.chevron_right_rounded, color: Color(0xFF7B6A86))]))));
}

class _WhiteCard extends StatelessWidget {
  const _WhiteCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFECE2D8))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children));
}

class _BackendErrorCard extends StatelessWidget {
  const _BackendErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE8C77C))), child: Row(children: [const Icon(Icons.wifi_off_rounded, color: Color(0xFFC99A3B)), const SizedBox(width: 8), Expanded(child: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF7B6A86), fontWeight: FontWeight.w800))), TextButton(onPressed: onRetry, child: const Text('Retry'))]));
}
