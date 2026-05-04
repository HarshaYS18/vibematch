import 'package:flutter/material.dart';

import '../controllers/banner_manager_controller.dart';
import '../models/banner_manager_models.dart';

class BannerManagerPage extends StatefulWidget {
  const BannerManagerPage({super.key});

  @override
  State<BannerManagerPage> createState() => _BannerManagerPageState();
}

class _BannerManagerPageState extends State<BannerManagerPage> {
  final BannerManagerController _controller = BannerManagerController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _sortController = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    _titleController.dispose();
    _sortController.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    _sortController.text = _controller.sortOrder.toString();
    setState(() {});
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initialDate = isStart ? _controller.startDate : _controller.endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked == null) return;

    if (isStart) {
      _controller.setStartDate(picked);
    } else {
      _controller.setEndDate(picked);
    }
  }

  void _saveBanner() {
    final title = _titleController.text.trim();

    if (title.isEmpty) {
      _toast('Enter banner title');
      return;
    }

    _controller.saveBanner(title: title);
    _titleController.clear();
    _toast('Banner saved locally. Backend upload will connect later.');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _Header(onBackTap: () => Navigator.pop(context)),
            ),
            SliverToBoxAdapter(
              child: _SectionSwitcher(
                selectedSection: _controller.selectedSection,
                onChanged: _controller.selectSection,
              ),
            ),
            SliverToBoxAdapter(
              child: _BannerFormCard(
                controller: _controller,
                titleController: _titleController,
                sortController: _sortController,
                onImageTap: _controller.mockPickImage,
                onTargetChanged: _controller.selectTarget,
                onStartDateTap: () => _pickDate(isStart: true),
                onEndDateTap: () => _pickDate(isStart: false),
                onActiveChanged: _controller.setActive,
                onSortChanged: (value) {
                  _controller.setSortOrder(int.tryParse(value) ?? 1);
                },
                onSaveTap: _saveBanner,
              ),
            ),
            SliverToBoxAdapter(
              child: _SavedBannerList(banners: _controller.savedBanners),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
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
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF251538).withValues(alpha: 0.055),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onBackTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFECE2D8)),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF251538), size: 20),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Banner Manager',
                  style: TextStyle(
                    color: Color(0xFF251538),
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Event and display promotion banners',
                  style: TextStyle(
                    color: Color(0xFF7B6A86),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFECE2D8)),
      ),
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
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF251538) : Colors.transparent,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Center(
                  child: Text(
                    section.label,
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF4A2A63),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFECE2D8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF251538).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel('Upload image'),
          const SizedBox(height: 7),
          InkWell(
            onTap: onImageTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 118,
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7F1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFECE2D8)),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_upload_rounded, color: Color(0xFF8C5CF6), size: 30),
                    const SizedBox(height: 8),
                    Text(
                      controller.imageLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF4A2A63),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Mock picker now · real upload later',
                      style: TextStyle(
                        color: Color(0xFF9B8CA5),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const _FieldLabel('Set title'),
          const SizedBox(height: 7),
          _TextInput(
            controller: titleController,
            hintText: controller.selectedSection == ManagedBannerSection.eventBanner
                ? 'Weekend Event'
                : 'Recharge Promo',
            icon: Icons.title_rounded,
          ),
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
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFF251538) : const Color(0xFFFAF7F1),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected ? const Color(0xFF251538) : const Color(0xFFECE2D8),
                    ),
                  ),
                  child: Text(
                    target.label,
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
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _DateTile(
                  label: 'Start date',
                  value: _dateText(controller.startDate),
                  onTap: onStartDateTap,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateTile(
                  label: 'End date',
                  value: _dateText(controller.endDate),
                  onTap: onEndDateTap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ActiveTile(
                  isActive: controller.isActive,
                  onChanged: onActiveChanged,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 116,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Sort order'),
                    const SizedBox(height: 7),
                    _TextInput(
                      controller: sortController,
                      hintText: '1',
                      icon: Icons.sort_rounded,
                      keyboardType: TextInputType.number,
                      onChanged: onSortChanged,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onSaveTap,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF251538),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              icon: const Icon(Icons.save_rounded, size: 19),
              label: const Text(
                'Save banner',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _dateText(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.controller,
    required this.hintText,
    required this.icon,
    this.keyboardType,
    this.onChanged,
  });

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
      style: const TextStyle(
        color: Color(0xFF251538),
        fontSize: 13,
        fontWeight: FontWeight.w900,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xFF9B8CA5), fontWeight: FontWeight.w700),
        prefixIcon: Icon(icon, color: const Color(0xFF8C5CF6), size: 19),
        filled: true,
        fillColor: const Color(0xFFFAF7F1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFECE2D8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFECE2D8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF8C5CF6), width: 1.4),
        ),
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
        decoration: BoxDecoration(
          color: const Color(0xFFFAF7F1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFECE2D8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.calendar_month_rounded, color: Color(0xFF8C5CF6), size: 17),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(color: Color(0xFF251538), fontSize: 12.2, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ],
        ),
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
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFECE2D8)),
      ),
      child: Row(
        children: [
          Icon(
            isActive ? Icons.visibility_rounded : Icons.visibility_off_rounded,
            color: isActive ? const Color(0xFF12C7B7) : const Color(0xFF9B8CA5),
            size: 20,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Active',
              style: TextStyle(color: Color(0xFF251538), fontSize: 13, fontWeight: FontWeight.w900),
            ),
          ),
          Switch(
            value: isActive,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF12C7B7),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF251538),
        fontSize: 12.5,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _SavedBannerList extends StatelessWidget {
  const _SavedBannerList({required this.banners});

  final List<ManagedBannerDraft> banners;

  @override
  Widget build(BuildContext context) {
    if (banners.isEmpty) {
      return Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 0),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFECE2D8)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Color(0xFF8C5CF6), size: 21),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Saved banners for this section will appear here.',
                style: TextStyle(color: Color(0xFF7B6A86), fontSize: 12.5, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 4, 18, 10),
          child: Text(
            'Saved locally',
            style: TextStyle(color: Color(0xFF251538), fontSize: 17, fontWeight: FontWeight.w900),
          ),
        ),
        ...banners.map((banner) => _SavedBannerTile(banner: banner)),
      ],
    );
  }
}

class _SavedBannerTile extends StatelessWidget {
  const _SavedBannerTile({required this.banner});

  final ManagedBannerDraft banner;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFECE2D8)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF8C5CF6).withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.image_rounded, color: Color(0xFF8C5CF6), size: 23),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  banner.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF251538), fontSize: 13.5, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  '${banner.target.label} · Order ${banner.sortOrder} · ${banner.isActive ? 'Active' : 'Inactive'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
