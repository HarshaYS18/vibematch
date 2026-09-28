import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/vm_failure.dart';
import '../../../core/presentation/vm_async_state.dart';

import '../controllers/store_controller.dart';
import '../models/store_models.dart';
import 'inventory_page.dart';
import 'widgets/store_category_tabs.dart';
import 'widgets/store_item_grid_section.dart';

class StorePage extends ConsumerStatefulWidget {
  const StorePage({super.key});

  @override
  ConsumerState<StorePage> createState() => _StorePageState();
}

class _StorePageState extends ConsumerState<StorePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(storeControllerProvider.notifier).load();
    });
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
      final message = await ref.read(storeControllerProvider.notifier).purchase(item);
      if (!mounted) return;
      _showToast(message);
    } catch (error) {
      if (!mounted) return;
      _showToast(VmFailurePresentation.messageFor(error, contentLabel: 'purchase'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeControllerProvider);
    final controller = ref.read(storeControllerProvider.notifier);
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
            onPressed: controller.load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(child: _StoreHero(isLoading: store.isLoading || store.isPurchasing)),
            SliverToBoxAdapter(
              child: StoreCategoryTabs(
                categories: store.categories,
                selectedCategory: store.selectedCategory,
                onSelected: controller.selectCategory,
              ),
            ),
            if (store.isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: VmLoadingState(message: 'Loading store…'),
              )
            else if (store.errorMessage != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: VmFailureState(
                  message: store.errorMessage!,
                  contentLabel: 'store',
                  onRetry: controller.load,
                ),
              )
            else
              StoreItemGridSection(items: store.currentItems, onPurchase: _purchase),
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
