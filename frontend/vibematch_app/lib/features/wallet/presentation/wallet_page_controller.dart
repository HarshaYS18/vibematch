part of 'wallet_page_modular.dart';

extension _WalletPageController on _WalletPageModularState {
  void _handleRealtimeUser(CurrentUser user) {
    final wallet = _wallet;
    if (!mounted || wallet == null || wallet.userId != user.id) return;
    _setWalletState(() {
      _wallet = wallet.copyWith(
        coinBalance: user.wallet.coinBalance,
        rubyBalance: user.wallet.rubyBalance,
        lifetimeCoinsSpent: user.wallet.lifetimeCoinsSpent,
        lifetimeCoinsReceivedAsGifts: user.wallet.lifetimeCoinsReceivedAsGifts,
        lifetimeRubiesEarned: user.wallet.lifetimeRubiesEarned,
        monthlyGiftCoinsSent: user.wallet.monthlyGiftCoinsSent,
        monthlyGiftCoinsReceived: user.wallet.monthlyGiftCoinsReceived,
        lifetimeSendExp: user.wallet.lifetimeSendExp,
        lifetimeReceiveExp: user.wallet.lifetimeReceiveExp,
        sentLevel: user.wallet.sendLevel,
        receiveLevel: user.wallet.receiveLevel,
        vipLevel: user.vip.vipLevel,
        svipLevel: user.vip.svipLevel,
      );
    });
  }

  Future<void> _loadWallet() async {
    _setWalletState(() {
      _loading = true;
      _error = null;
    });
    try {
      final wallet = await _walletApi.getWallet();
      final ledger = await _walletApi.getLedger(limit: 40);
      if (!mounted) return;
      _setWalletState(() {
        _wallet = wallet;
        _ledger = ledger;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      _setWalletState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _recharge(int amountInr) async {
    if (_working) return;
    _setWalletState(() => _working = true);
    try {
      final wallet = await _walletApi.recharge(amountInr: amountInr);
      final ledger = await _walletApi.getLedger(limit: 40);
      if (!mounted) return;
      _setWalletState(() {
        _wallet = wallet;
        _ledger = ledger;
      });
      _showToast(
        'Recharge added ₹$amountInr = ${formatWalletNumber(amountInr * 1000)} coins',
      );
    } catch (error) {
      _showToast(error.toString());
    } finally {
      if (mounted) _setWalletState(() => _working = false);
    }
  }

  Future<void> _convertRuby() async {
    final amount = int.tryParse(_rubyConvertController.text.trim()) ?? 0;
    if (amount <= 0) {
      _showToast('Enter valid Ruby amount');
      return;
    }
    if (_working) return;
    _setWalletState(() => _working = true);
    try {
      final wallet = await _walletApi.convertRuby(rubyAmount: amount);
      final ledger = await _walletApi.getLedger(limit: 40);
      if (!mounted) return;
      _setWalletState(() {
        _wallet = wallet;
        _ledger = ledger;
        _rubyConvertController.clear();
      });
      _showToast('$amount Ruby converted to $amount coins');
    } catch (error) {
      _showToast(error.toString());
    } finally {
      if (mounted) _setWalletState(() => _working = false);
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: WalletColors.deep,
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      );
  }

  Widget _content() {
    if (_loading)
      return const Center(
        child: CircularProgressIndicator(color: WalletColors.aqua),
      );
    final error = _error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: WalletColors.coral,
                size: 42,
              ),
              const SizedBox(height: 10),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: WalletColors.deep,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              WalletPrimarySmallButton(text: 'Retry', onTap: _loadWallet),
            ],
          ),
        ),
      );
    }
    final wallet = _wallet;
    if (wallet == null) return const SizedBox.shrink();
    return RefreshIndicator(
      onRefresh: _loadWallet,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _WalletOverview(wallet: wallet, selectedSection: _selectedSection),
          const SizedBox(height: 14),
          _WalletSectionTabs(
            selectedSection: _selectedSection,
            onChanged: (section) =>
                _setWalletState(() => _selectedSection = section),
          ),
          const SizedBox(height: 14),
          _selectedSection == WalletSection.coins
              ? _CoinsSection(
                  wallet: wallet,
                  rechargeAmountsInr:
                      _WalletPageModularState._rechargeAmountsInr,
                  working: _working,
                  onRecharge: _recharge,
                )
              : _RubySection(
                  wallet: wallet,
                  controller: _rubyConvertController,
                  working: _working,
                  onConvert: _convertRuby,
                ),
          const SizedBox(height: 14),
          _LedgerCard(entries: _ledger),
        ],
      ),
    );
  }
}
