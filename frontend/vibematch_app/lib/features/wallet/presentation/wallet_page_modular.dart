import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/data/auth_api_service.dart';
import '../../auth/models/current_user.dart';
import '../../economy/data/economy_master_api_service.dart';
import '../data/wallet_api_service.dart';
import 'models/wallet_models.dart';
import 'widgets/wallet_shared_widgets.dart';

part 'wallet_page_controller.dart';
part 'wallet_page_sections.dart';

class WalletPageModular extends StatefulWidget {
  const WalletPageModular({
    super.key,
    this.initialSection = WalletSection.coins,
  });

  final WalletSection initialSection;

  @override
  State<WalletPageModular> createState() => _WalletPageModularState();
}

class _WalletPageModularState extends State<WalletPageModular> {
  final WalletApiService _walletApi = const WalletApiService();
  final EconomyMasterApiService _economyMasterApi = const EconomyMasterApiService();
  final TextEditingController _rubyConvertController = TextEditingController();

  late WalletSection _selectedSection = widget.initialSection;
  VmWallet? _wallet;
  List<VmWalletLedgerEntry> _ledger = const [];
  StreamSubscription<CurrentUser>? _userRealtimeSub;
  bool _loading = true;
  bool _working = false;
  String? _error;

  static const List<int> _rechargeAmountsInr = [
    100,
    500,
    1000,
    5000,
    10000,
    50000,
    100000,
    500000,
  ];

  @override
  void initState() {
    super.initState();
    _userRealtimeSub = AuthUserRealtimeService.instance.users.listen(
      _handleRealtimeUser,
    );
    _loadWallet();
  }

  @override
  void dispose() {
    _userRealtimeSub?.cancel();
    _rubyConvertController.dispose();
    super.dispose();
  }

  void _setWalletState(VoidCallback update) => setState(update);

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: WalletColors.bg,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(16, topPadding + 12, 16, 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              border: const Border(
                bottom: BorderSide(color: WalletColors.border),
              ),
              boxShadow: [
                BoxShadow(
                  color: WalletColors.deep.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: WalletColors.deep,
                  ),
                  tooltip: 'Back',
                ),
                const SizedBox(width: 4),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Wallet',
                        style: TextStyle(
                          color: WalletColors.deep,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.7,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Real coins, Ruby, VIP and SVIP',
                        style: TextStyle(
                          color: WalletColors.plum,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                WalletHeaderIconButton(
                  icon: Icons.refresh_rounded,
                  onTap: _loadWallet,
                ),
              ],
            ),
          ),
          Expanded(child: _content()),
        ],
      ),
    );
  }
}
