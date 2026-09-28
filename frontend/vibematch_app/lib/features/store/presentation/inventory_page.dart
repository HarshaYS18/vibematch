import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/vm_failure.dart';
import '../../../core/presentation/vm_async_state.dart';

import '../controllers/inventory_controller.dart';
import '../models/store_models.dart';
import 'widgets/inventory_section.dart';
import 'widgets/store_category_tabs.dart';

class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});

  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(inventoryControllerProvider.notifier).load();
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

  Future<void> _equip(InventoryItem item) async {
    try {
      final message = await ref.read(inventoryControllerProvider.notifier).equip(item);
      if (!mounted) return;
      _showToast(message);
    } catch (error) {
      if (!mounted) return;
      _showToast(VmFailurePresentation.messageFor(error, contentLabel: 'inventory'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventory = ref.watch(inventoryControllerProvider);
    final controller = ref.read(inventoryControllerProvider.notifier);
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF251538),
        title: const Text('Inventory', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
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
            SliverToBoxAdapter(child: _InventoryHero(isLoading: inventory.isLoading || inventory.isUpdating)),
            SliverToBoxAdapter(
              child: StoreCategoryTabs(
                categories: inventory.categories,
                selectedCategory: inventory.selectedCategory,
                onSelected: controller.selectCategory,
              ),
            ),
            if (inventory.isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: VmLoadingState(message: 'Loading inventory…'),
              )
            else if (inventory.errorMessage != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: VmFailureState(
                  message: inventory.errorMessage!,
                  contentLabel: 'inventory',
                  onRetry: controller.load,
                ),
              )
            else
              InventorySection(items: inventory.currentItems, onEquip: _equip),
          ],
        ),
      ),
    );
  }
}

class _InventoryHero extends StatelessWidget {
  const _InventoryHero({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF251538), Color(0xFF12C7B7)]),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 22, offset: const Offset(0, 10))],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('My Inventory', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text('Owned frames, chat bubbles, room backgrounds, effects, themes, and badges.', style: TextStyle(color: Color(0xFFE7FFFB), fontSize: 12, height: 1.25, fontWeight: FontWeight.w700)),
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
