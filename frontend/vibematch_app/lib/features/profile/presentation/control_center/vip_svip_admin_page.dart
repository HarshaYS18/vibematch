import 'package:flutter/material.dart';

import '../../data/vip_admin_api_service.dart';
import '../../models/vip_wallet_models.dart';
import '../widgets/svip_gradient_name.dart';

class VipSvipAdminPage extends StatefulWidget {
  const VipSvipAdminPage({super.key});

  @override
  State<VipSvipAdminPage> createState() => _VipSvipAdminPageState();
}

class _VipSvipAdminPageState extends State<VipSvipAdminPage> {
  final VipAdminApiService _api = const VipAdminApiService();
  final TextEditingController _publicIdController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController(text: 'Owner VIP/SVIP adjustment');

  int _vipLevel = 0;
  int _svipLevel = 0;
  int _svipDays = 30;
  bool _vipActive = true;
  bool _svipActive = false;
  bool _busy = false;
  UserVipSummary? _loadedStatus;

  @override
  void dispose() {
    _publicIdController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)), behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF251538)));
  }

  int? _readPublicUserId() {
    final id = int.tryParse(_publicIdController.text.trim());
    if (id == null || id <= 0) {
      _toast('Enter a valid public user ID.');
      return null;
    }
    return id;
  }

  Future<void> _loadStatus() async {
    final id = _readPublicUserId();
    if (id == null || _busy) return;
    setState(() => _busy = true);
    try {
      final status = await _api.getUserVipStatus(id);
      if (!mounted) return;
      setState(() {
        _loadedStatus = status;
        _vipLevel = status.vipLevel.clamp(0, 50);
        _svipLevel = status.svipLevel.clamp(0, 10);
        _vipActive = status.vipIsActive;
        _svipActive = status.svipIsActive;
      });
      _toast('VIP/SVIP status loaded.');
    } catch (error) {
      if (!mounted) return;
      _toast(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveStatus() async {
    final id = _readPublicUserId();
    if (id == null || _busy) return;
    final reason = _reasonController.text.trim();
    if (reason.length < 3) {
      _toast('Enter reason for audit log.');
      return;
    }
    setState(() => _busy = true);
    try {
      final status = await _api.updateUserVipStatus(
        publicUserId: id,
        vipLevel: _vipLevel,
        svipLevel: _svipLevel,
        vipIsActive: _vipActive,
        svipIsActive: _svipActive,
        svipDays: _svipDays,
        reason: reason,
      );
      if (!mounted) return;
      setState(() => _loadedStatus = status);
      _toast('VIP/SVIP updated successfully.');
    } catch (error) {
      if (!mounted) return;
      _toast(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _loadedStatus;
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFFAF7F1),
        foregroundColor: const Color(0xFF251538),
        title: const Text('VIP / SVIP Control', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF251538)))),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
        children: [
          _Header(status: status),
          const SizedBox(height: 14),
          _Card(
            child: Column(
              children: [
                _Input(controller: _publicIdController, label: 'Target public user ID', icon: Icons.badge_rounded, keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _SecondaryButton(text: 'Load', icon: Icons.search_rounded, onTap: _loadStatus)),
                    const SizedBox(width: 10),
                    Expanded(child: _PrimaryButton(text: 'Save', icon: Icons.save_rounded, onTap: _saveStatus, disabled: _busy)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle(title: 'VIP Level', subtitle: 'Lifetime recharge rank, 0 to 50'),
                const SizedBox(height: 10),
                _Dropdown<int>(
                  label: 'VIP level',
                  value: _vipLevel,
                  values: List<int>.generate(51, (index) => index),
                  text: (value) => value == 0 ? 'No VIP' : 'VIP $value',
                  onChanged: (value) => setState(() => _vipLevel = value),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _vipActive,
                  activeColor: const Color(0xFF12C7B7),
                  onChanged: (value) => setState(() => _vipActive = value),
                  title: const Text('VIP active', style: TextStyle(color: Color(0xFF251538), fontWeight: FontWeight.w900)),
                  subtitle: const Text('Disable only for frozen/review cases.', style: TextStyle(color: Color(0xFF7B6A86), fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle(title: 'SVIP Level', subtitle: 'Monthly/seasonal premium rank, 0 to 10'),
                const SizedBox(height: 10),
                _Dropdown<int>(
                  label: 'SVIP level',
                  value: _svipLevel,
                  values: List<int>.generate(11, (index) => index),
                  text: (value) => value == 0 ? 'No SVIP' : 'SVIP $value',
                  onChanged: (value) => setState(() => _svipLevel = value),
                ),
                const SizedBox(height: 10),
                _Dropdown<int>(
                  label: 'SVIP validity days',
                  value: _svipDays,
                  values: const [7, 15, 30, 60, 90, 180, 365],
                  text: (value) => '$value days',
                  onChanged: (value) => setState(() => _svipDays = value),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _svipActive,
                  activeColor: const Color(0xFF8C5CF6),
                  onChanged: (value) => setState(() => _svipActive = value),
                  title: const Text('SVIP active', style: TextStyle(color: Color(0xFF251538), fontWeight: FontWeight.w900)),
                  subtitle: const Text('Active SVIP unlocks gradient floating name effect.', style: TextStyle(color: Color(0xFF7B6A86), fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle(title: 'Audit Reason', subtitle: 'Required for owner/admin review trail'),
                const SizedBox(height: 10),
                _Input(controller: _reasonController, label: 'Reason', icon: Icons.note_alt_rounded),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _RuleCard(),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.status});

  final UserVipSummary? status;

  @override
  Widget build(BuildContext context) {
    final vip = status ?? const UserVipSummary.empty();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF251538), Color(0xFF4A2A63)]),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.16), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD36A))),
          const SizedBox(width: 13),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SvipGradientName(name: status == null ? 'Load user status' : 'VIP ${vip.vipLevel} • SVIP ${vip.svipLevel}', vip: vip, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(status == null ? 'Search by public user ID, then adjust levels.' : 'Gradient key: ${vip.nameGradientKey}', style: TextStyle(color: Colors.white.withValues(alpha: 0.76), fontSize: 12.5, fontWeight: FontWeight.w800)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), border: Border.all(color: const Color(0xFFECE2D8))),
        child: child,
      );
}

class _Input extends StatelessWidget {
  const _Input({required this.controller, required this.label, required this.icon, this.keyboardType});

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Color(0xFF251538), fontSize: 13.5, fontWeight: FontWeight.w800),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF8C7B8F), fontSize: 12, fontWeight: FontWeight.w700),
          prefixIcon: Icon(icon, color: const Color(0xFF6D5DF6), size: 19),
          filled: true,
          fillColor: const Color(0xFFFAF7F1),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: const BorderSide(color: Color(0xFFECE2D8))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: const BorderSide(color: Color(0xFFECE2D8))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: const BorderSide(color: Color(0xFF12C7B7), width: 1.4)),
        ),
      );
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({required this.label, required this.value, required this.values, required this.text, required this.onChanged});

  final String label;
  final T value;
  final List<T> values;
  final String Function(T value) text;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
        value: value,
        items: values.map((item) => DropdownMenuItem<T>(value: item, child: Text(text(item), style: const TextStyle(fontWeight: FontWeight.w800)))).toList(),
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFFFAF7F1),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: const BorderSide(color: Color(0xFFECE2D8))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: const BorderSide(color: Color(0xFFECE2D8))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: const BorderSide(color: Color(0xFF12C7B7), width: 1.4)),
        ),
      );
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.text, required this.icon, required this.onTap, this.disabled = false});

  final String text;
  final IconData icon;
  final VoidCallback onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 48,
        child: ElevatedButton.icon(
          onPressed: disabled ? null : onTap,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF251538), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))),
          icon: Icon(icon),
          label: Text(text, style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
      );
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.text, required this.icon, required this.onTap});

  final String text;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 48,
        child: OutlinedButton.icon(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF251538), side: const BorderSide(color: Color(0xFFECE2D8)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))),
          icon: Icon(icon),
          label: Text(text, style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Color(0xFF251538), fontSize: 19, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: Color(0xFF8C7B8F), fontSize: 12, fontWeight: FontWeight.w700))]);
}

class _RuleCard extends StatelessWidget {
  const _RuleCard();

  @override
  Widget build(BuildContext context) {
    const rules = ['Owner/Super Owner only endpoint.', 'VIP range is 0–50.', 'SVIP range is 0–10.', 'Active SVIP controls colorful floating gradient names.', 'Reason is required and stored server-side.'];
    return _Card(
      child: Column(children: [for (final rule in rules) Padding(padding: const EdgeInsets.only(bottom: 9), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.check_circle_rounded, color: Color(0xFF12C7B7), size: 18), const SizedBox(width: 8), Expanded(child: Text(rule, style: const TextStyle(color: Color(0xFF251538), fontSize: 12.5, fontWeight: FontWeight.w800, height: 1.25)))]))]),
    );
  }
}
