import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../media/data/media_upload_service.dart';
import '../controllers/banner_manager_controller.dart';
import '../models/banner_manager_models.dart';

class BannerManagerPage extends ConsumerStatefulWidget {
  const BannerManagerPage({super.key});

  @override
  ConsumerState<BannerManagerPage> createState() => _BannerManagerPageState();
}

class _BannerManagerPageState extends ConsumerState<BannerManagerPage> {
  final MediaUploadService _mediaUploadService = const MediaUploadService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _sortController = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(bannerManagerControllerProvider.notifier).loadBanners();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _sortController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final state = ref.read(bannerManagerControllerProvider);
    final initialDate = isStart ? state.startDate : state.endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked == null) return;

    if (isStart) {
      ref.read(bannerManagerControllerProvider.notifier).setStartDate(picked);
    } else {
      ref.read(bannerManagerControllerProvider.notifier).setEndDate(picked);
    }
  }

  Future<void> _pickCropAndUploadImage() async {
    final state = ref.read(bannerManagerControllerProvider);
    final controller = ref.read(bannerManagerControllerProvider.notifier);
    if (state.isUploadingImage || state.isSaving) return;
    controller.setUploadingImage(true);
    try {
      final section = ref.read(bannerManagerControllerProvider).selectedSection;
      final upload = await _mediaUploadService.pickCropAndUploadHomeBanner(
        context,
        title: section == ManagedBannerSection.policyBanner ? 'Crop Policy Banner' : 'Crop Event Banner',
        aspectRatio: section.aspectRatio,
        outputWidth: section.outputWidth,
        outputHeight: section.outputHeight,
      );
      controller.setUploadedImage(url: upload.url);
      _toast('Banner image uploaded');
    } on MediaUploadCancelledException {
      return;
    } catch (error) {
      _toast(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      controller.setUploadingImage(false);
    }
  }

  Future<void> _saveBanner() async {
    try {
      await ref.read(bannerManagerControllerProvider.notifier).saveBanner(title: _titleController.text.trim());
      _titleController.clear();
      _toast('Banner saved to backend');
    } catch (error) {
      _toast(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _toast(String message) {
    if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    final banner = ref.watch(bannerManagerControllerProvider);
    final controller = ref.read(bannerManagerControllerProvider.notifier);
    ref.listen<BannerManagerState>(bannerManagerControllerProvider, (previous, next) {
      if (previous?.sortOrder == next.sortOrder) return;
      final value = next.sortOrder.toString();
      if (_sortController.text != value) _sortController.text = value;
    });
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.loadBanners,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(child: _Header(onBackTap: () => Navigator.pop(context))),
              SliverToBoxAdapter(child: _SectionSwitcher(selectedSection: banner.selectedSection, onChanged: controller.selectSection)),
              if (banner.errorMessage != null)
                SliverToBoxAdapter(child: _ErrorCard(message: banner.errorMessage!, onRetry: controller.loadBanners)),
              SliverToBoxAdapter(
                child: _BannerFormCard(
                  controller: controller,
                  titleController: _titleController,
                  sortController: _sortController,
                  onImageTap: _pickCropAndUploadImage,
                  onTargetChanged: controller.selectTarget,
                  onStartDateTap: () => _pickDate(isStart: true),
                  onEndDateTap: () => _pickDate(isStart: false),
                  onActiveChanged: controller.setActive,
                  onSortChanged: (value) => controller.setSortOrder(int.tryParse(value) ?? 1),
                  onSaveTap: _saveBanner,
                ),
              ),
              if (banner.isLoading)
                const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(18, 0, 18, 12), child: LinearProgressIndicator(minHeight: 3, color: Color(0xFF12C7B7), backgroundColor: Color(0xFFECE2D8))))
              else
                SliverToBoxAdapter(child: _SavedBannerList(banners: banner.savedBanners, onToggleActive: controller.toggleBannerActive)),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBackTap});

  final VoidCallback onBackTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.98),
        border: const Border(bottom: BorderSide(color: Color(0xFFECE2D8))),
        boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.055), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onBackTap,
            customBorder: const CircleBorder(),
            child: Container(width: 38, height: 38, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: const Color(0xFFECE2D8))), child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF251538), size: 20)),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Banner Manager', style: TextStyle(color: Color(0xFF251538), fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
              SizedBox(height: 2),
              Text('Backend controlled event and policy banners', style: TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w700)),
            ]),
          ),
          const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF12C7B7), size: 23),
        ],
      ),
    );
  }
}

class _SectionSwitcher extends StatelessWidget {
  const _SectionSwitcher({required this.selectedSection, required this.onChanged});

  final ManagedBannerSection selectedSection;
  final ValueChanged<ManagedBannerSection> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFECE2D8))),
      child: Row(
        children: ManagedBannerSection.values.map((section) {
          final selected = section == selectedSection;
          return Expanded(
            child: InkWell(
              onTap: () => onChanged(section),
              borderRadius: BorderRadius.circular(17),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: 42,
                decoration: BoxDecoration(color: selected ? const Color(0xFF251538) : Colors.transparent, borderRadius: BorderRadius.circular(17)),
                child: Center(child: Text(section.label, style: TextStyle(color: selected ? Colors.white : const Color(0xFF4A2A63), fontSize: 12.5, fontWeight: FontWeight.w900))),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BannerFormCard extends StatelessWidget {
  const _BannerFormCard({
    required this.controller,
    required this.titleController,
    required this.sortController,
    required this.onImageTap,
    required this.onTargetChanged,
    required this.onStartDateTap,
    required this.onEndDateTap,
    required this.onActiveChanged,
    required this.onSortChanged,
    required this.onSaveTap,
  });

  final BannerManagerController controller;
  final TextEditingController titleController;
  final TextEditingController sortController;
  final VoidCallback onImageTap;
  final ValueChanged<ManagedBannerTarget> onTargetChanged;
  final VoidCallback onStartDateTap;
  final VoidCallback onEndDateTap;
  final ValueChanged<bool> onActiveChanged;
  final ValueChanged<String> onSortChanged;
  final VoidCallback onSaveTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), border: Border.all(color: const Color(0xFFECE2D8)), boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 8))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel('Upload image · ${controller.selectedSection.outputWidth}×${controller.selectedSection.outputHeight}'),
          const SizedBox(height: 7),
          InkWell(
            onTap: controller.isUploadingImage || controller.isSaving ? null : onImageTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 118,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: const Color(0xFFFAF7F1), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFECE2D8))),
              child: controller.uploadedImageUrl == null
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(controller.isUploadingImage ? Icons.hourglass_top_rounded : Icons.crop_rounded, color: const Color(0xFF8C5CF6), size: 30),
                        const SizedBox(height: 8),
                        Text(controller.isUploadingImage ? 'Uploading...' : controller.imageLabel, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF4A2A63), fontSize: 12.5, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        const Text('Pick · move · zoom · crop · upload', style: TextStyle(color: Color(0xFF9B8CA5), fontSize: 11, fontWeight: FontWeight.w700)),
                      ]),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(controller.uploadedImageUrl!, fit: BoxFit.cover),
                        Positioned(right: 10, top: 10, child: Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.42), borderRadius: BorderRadius.circular(999)), child: const Text('Uploaded', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)))),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 14),
          const _FieldLabel('Set title'),
          const SizedBox(height: 7),
          _TextInput(controller: titleController, hintText: controller.selectedSection == ManagedBannerSection.eventBanner ? 'Weekend Event' : 'Rules & Regulations', icon: Icons.title_rounded),
          const SizedBox(height: 14),
          const _FieldLabel('Set target'),
          const SizedBox(height: 7),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ManagedBannerTarget.values.map((target) {
              final selected = target == controller.selectedTarget;
              return InkWell(
                onTap: () => onTargetChanged(target),
                borderRadius: BorderRadius.circular(999),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(color: selected ? const Color(0xFF251538) : const Color(0xFFFAF7F1), borderRadius: BorderRadius.circular(999), border: Border.all(color: selected ? const Color(0xFF251538) : const Color(0xFFECE2D8))),
                  child: Text(target.label, style: TextStyle(color: selected ? Colors.white : const Color(0xFF4A2A63), fontSize: 11.5, fontWeight: FontWeight.w900)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _DateTile(label: 'Start date', value: _dateText(controller.startDate), onTap: onStartDateTap)),
            const SizedBox(width: 10),
            Expanded(child: _DateTile(label: 'End date', value: _dateText(controller.endDate), onTap: onEndDateTap)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _ActiveTile(isActive: controller.isActive, onChanged: onActiveChanged)),
            const SizedBox(width: 10),
            SizedBox(width: 116, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _FieldLabel('Sort order'),
              const SizedBox(height: 7),
              _TextInput(controller: sortController, hintText: '1', icon: Icons.sort_rounded, keyboardType: TextInputType.number, onChanged: onSortChanged),
            ])),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: controller.isSaving || controller.isUploadingImage ? null : onSaveTap,
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF251538), foregroundColor: Colors.white, disabledBackgroundColor: const Color(0xFF9B8CA5), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
              icon: Icon(controller.isSaving ? Icons.hourglass_top_rounded : Icons.save_rounded, size: 19),
              label: Text(controller.isSaving ? 'Saving...' : 'Save banner', style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }

  static String _dateText(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _TextInput extends StatelessWidget {
  const _TextInput({required this.controller, required this.hintText, required this.icon, this.keyboardType, this.onChanged});

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: const TextStyle(color: Color(0xFF251538), fontSize: 13, fontWeight: FontWeight.w900),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xFF9B8CA5), fontWeight: FontWeight.w700),
        prefixIcon: Icon(icon, color: const Color(0xFF8C5CF6), size: 19),
        filled: true,
        fillColor: const Color(0xFFFAF7F1),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFECE2D8))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFECE2D8))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFF8C5CF6), width: 1.4)),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFFAF7F1), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFECE2D8))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Row(children: [const Icon(Icons.calendar_month_rounded, color: Color(0xFF8C5CF6), size: 17), const SizedBox(width: 6), Expanded(child: Text(value, style: const TextStyle(color: Color(0xFF251538), fontSize: 12.2, fontWeight: FontWeight.w900)))]),
        ]),
      ),
    );
  }
}

class _ActiveTile extends StatelessWidget {
  const _ActiveTile({required this.isActive, required this.onChanged});

  final bool isActive;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: const Color(0xFFFAF7F1), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFECE2D8))),
      child: Row(children: [
        Icon(isActive ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: isActive ? const Color(0xFF12C7B7) : const Color(0xFF9B8CA5), size: 20),
        const SizedBox(width: 8),
        const Expanded(child: Text('Active', style: TextStyle(color: Color(0xFF251538), fontSize: 13, fontWeight: FontWeight.w900))),
        Switch(value: isActive, onChanged: onChanged, activeThumbColor: const Color(0xFF12C7B7)),
      ]),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(color: Color(0xFF251538), fontSize: 12.5, fontWeight: FontWeight.w900));
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFFFF7E8), borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE8C77C))),
      child: Row(children: [
        const Icon(Icons.wifi_off_rounded, color: Color(0xFFC99A3B), size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: const TextStyle(color: Color(0xFF4A2A63), fontSize: 12, fontWeight: FontWeight.w800))),
        TextButton(onPressed: onRetry, child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w900))),
      ]),
    );
  }
}

class _SavedBannerList extends StatelessWidget {
  const _SavedBannerList({required this.banners, required this.onToggleActive});

  final List<ManagedBanner> banners;
  final ValueChanged<ManagedBanner> onToggleActive;

  @override
  Widget build(BuildContext context) {
    if (banners.isEmpty) {
      return Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 0),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFECE2D8))),
        child: const Row(children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFF8C5CF6), size: 21),
          SizedBox(width: 10),
          Expanded(child: Text('Backend banners for this section will appear here.', style: TextStyle(color: Color(0xFF7B6A86), fontSize: 12.5, fontWeight: FontWeight.w800))),
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(padding: EdgeInsets.fromLTRB(18, 4, 18, 10), child: Text('Backend banners', style: TextStyle(color: Color(0xFF251538), fontSize: 17, fontWeight: FontWeight.w900))),
      ...banners.map((banner) => _SavedBannerTile(banner: banner, onToggleActive: () => onToggleActive(banner))),
    ]);
  }
}

class _SavedBannerTile extends StatelessWidget {
  const _SavedBannerTile({required this.banner, required this.onToggleActive});

  final ManagedBanner banner;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFECE2D8))),
      child: Row(children: [
        Container(
          width: 62,
          height: 48,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: const Color(0xFF8C5CF6).withValues(alpha: 0.11), borderRadius: BorderRadius.circular(16)),
          child: banner.imageUrl.trim().isEmpty ? const Icon(Icons.image_rounded, color: Color(0xFF8C5CF6), size: 23) : Image.network(banner.imageUrl, fit: BoxFit.cover),
        ),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(banner.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF251538), fontSize: 13.5, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('${banner.target.label} · Order ${banner.sortOrder} · ${banner.isActive ? 'Active' : 'Inactive'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w700)),
        ])),
        Switch(value: banner.isActive, onChanged: (_) => onToggleActive(), activeThumbColor: const Color(0xFF12C7B7)),
      ]),
    );
  }
}
