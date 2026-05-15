import 'package:flutter/foundation.dart';

import '../data/banner_manager_repository.dart';
import '../models/banner_manager_models.dart';

class BannerManagerController extends ChangeNotifier {
  BannerManagerController({BannerManagerRepository? repository})
      : _repository = repository ?? BannerManagerRepository();

  final BannerManagerRepository _repository;

  ManagedBannerSection selectedSection = ManagedBannerSection.eventBanner;
  ManagedBannerTarget selectedTarget = ManagedBannerTarget.event;
  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now().add(const Duration(days: 7));
  bool isActive = true;
  int sortOrder = 1;
  String imageLabel = 'No image selected';
  String? uploadedImageUrl;
  bool isLoading = false;
  bool isSaving = false;
  bool isUploadingImage = false;
  String? errorMessage;

  List<ManagedBanner> _savedBanners = const [];

  List<ManagedBanner> get savedBanners => _savedBanners;

  Future<void> loadBanners() async {
    if (isLoading) return;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      _savedBanners = await _repository.fetchBanners(section: selectedSection);
      _savedBanners = [..._savedBanners]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    } catch (error) {
      _savedBanners = const [];
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void selectSection(ManagedBannerSection section) {
    if (selectedSection == section) return;
    selectedSection = section;
    selectedTarget = section == ManagedBannerSection.policyBanner ? ManagedBannerTarget.policy : ManagedBannerTarget.event;
    uploadedImageUrl = null;
    imageLabel = 'No image selected';
    sortOrder = 1;
    notifyListeners();
    loadBanners();
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

  void setUploadedImage({required String url}) {
    uploadedImageUrl = url;
    imageLabel = 'Image uploaded';
    notifyListeners();
  }

  void setUploadingImage(bool value) {
    isUploadingImage = value;
    notifyListeners();
  }

  Future<void> saveBanner({required String title}) async {
    final cleanTitle = title.trim();
    final imageUrl = uploadedImageUrl?.trim() ?? '';
    if (cleanTitle.isEmpty) throw Exception('Enter banner title');
    if (imageUrl.isEmpty) throw Exception('Upload banner image first');
    if (endDate.isBefore(startDate)) throw Exception('End date cannot be before start date');
    if (isSaving) return;

    isSaving = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _repository.createBanner(
        section: selectedSection,
        title: cleanTitle,
        target: selectedTarget,
        imageUrl: imageUrl,
        startDate: startDate,
        endDate: endDate,
        isActive: isActive,
        sortOrder: sortOrder,
      );
      sortOrder += 1;
      uploadedImageUrl = null;
      imageLabel = 'No image selected';
      await loadBanners();
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> toggleBannerActive(ManagedBanner banner) async {
    try {
      await _repository.setActive(bannerId: banner.id, isActive: !banner.isActive);
      await loadBanners();
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _repository.close();
    super.dispose();
  }
}
