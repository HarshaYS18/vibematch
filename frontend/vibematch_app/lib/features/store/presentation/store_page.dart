import 'package:flutter/material.dart';

import '../controllers/store_controller.dart';
import '../models/store_models.dart';
import 'inventory_page.dart';
import 'widgets/store_category_tabs.dart';
import 'widgets/store_item_grid_section.dart';

class StorePage extends StatefulWidget {
  const StorePage({super.key});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  late final StoreController _controller;

  @override
  void initState() {
    super.initState();
    _controller = StoreController()..addListener(_onControllerChanged);
    _controller.load();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF251538),
        content: Text(message),
      ),
    );
  }

  Future<void> _purchase(StoreItem item) async {
    try {
      final message = await _controller.purchase(item);
      if (!mounted) return;
      _showToast(message);
    } catch (error) {
      if (!mounted) return;
      _showToast(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF251538),
        title: const Text('Store', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: 'Inventory',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const InventoryPage())),
            icon: const Icon(Icons.inventory_2_rounded),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _controller.load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _controller.load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(child: _StoreHero(isLoading: _controller.isLoading || _controller.isPurchasing)),
            SliverToBoxAdapter(
              child: StoreCategoryTabs(
                categories: _controller.categories,
                selectedCategory: _controller.selectedCategory,
                onSelected: _controller.selectCategory,
              ),
            ),
            if (_controller.isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_controller.errorMessage != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _StoreError(message: _controller.errorMessage!, onRetry: _controller.load),
              )
            else
              StoreItemGridSection(items: _controller.currentItems, onPurchase: _purchase),
          ],
        ),
      ),
    );
  }
}

class _StoreHero extends StatelessWidget {
  const _StoreHero({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF251538), Color(0xFF6D5DF6)]),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 22, offset: const Offset(0, 10))],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Real Store', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text('Backend catalog, wallet purchase, and inventory ownership are connected.', style: TextStyle(color: Color(0xFFEDE8FF), fontSize: 12, height: 1.25, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          if (isLoading)
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
        ],
      ),
    );
  }
}

class _StoreError extends StatelessWidget {
  const _StoreError({required this.message, required this.onRetry});

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
            const Icon(Icons.wifi_off_rounded, color: Color(0xFFE84C72), size: 42),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF251538), fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
