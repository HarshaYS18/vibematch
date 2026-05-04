import 'package:flutter/foundation.dart';

import '../models/banner_manager_models.dart';

class BannerManagerController extends ChangeNotifier {
  ManagedBannerSection selectedSection = ManagedBannerSection.eventBanner;
  ManagedBannerTarget selectedTarget = ManagedBannerTarget.event;
  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now().add(const Duration(days: 7));
  bool isActive = true;
  int sortOrder = 1;
  String imageLabel = 'No image selected';

  final List<ManagedBannerDraft> _savedBanners = [];

  List<ManagedBannerDraft> get savedBanners {
    return _savedBanners
        .where((banner) => banner.section == selectedSection)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  void selectSection(ManagedBannerSection section) {
    selectedSection = section;
    notifyListeners();
  }

  void selectTarget(ManagedBannerTarget target) {
    selectedTarget = target;
    notifyListeners();
  }

  void setStartDate(DateTime value) {
    startDate = value;
    if (endDate.isBefore(startDate)) {
      endDate = startDate.add(const Duration(days: 1));
    }
    notifyListeners();
  }

  void setEndDate(DateTime value) {
    endDate = value;
    notifyListeners();
  }

  void setActive(bool value) {
    isActive = value;
    notifyListeners();
  }

  void setSortOrder(int value) {
    sortOrder = value < 1 ? 1 : value;
    notifyListeners();
  }

  void mockPickImage() {
    imageLabel = 'promo_banner_${DateTime.now().millisecondsSinceEpoch}.png';
    notifyListeners();
  }

  void saveBanner({required String title}) {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) return;

    _savedBanners.insert(
      0,
      ManagedBannerDraft(
        id: 'banner_${DateTime.now().millisecondsSinceEpoch}',
        section: selectedSection,
        title: cleanTitle,
        target: selectedTarget,
        imageLabel: imageLabel,
        startDate: startDate,
        endDate: endDate,
        isActive: isActive,
        sortOrder: sortOrder,
      ),
    );

    sortOrder += 1;
    imageLabel = 'No image selected';
    notifyListeners();
  }
}
