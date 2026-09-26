import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/banner_manager_repository.dart';
import '../models/banner_manager_models.dart';

const Object _bannerUnset = Object();

class BannerManagerState {
  BannerManagerState({
    this.selectedSection = ManagedBannerSection.eventBanner,
    this.selectedTarget = ManagedBannerTarget.event,
    DateTime? startDate,
    DateTime? endDate,
    this.isActive = true,
    this.sortOrder = 1,
    this.imageLabel = 'No image selected',
    this.uploadedImageUrl,
    this.isLoading = false,
    this.isSaving = false,
    this.isUploadingImage = false,
    this.errorMessage,
    this.savedBanners = const <ManagedBanner>[],
  })  : startDate = startDate ?? DateTime.now(),
        endDate = endDate ?? DateTime.now().add(const Duration(days: 7));

  final ManagedBannerSection selectedSection;
  final ManagedBannerTarget selectedTarget;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final int sortOrder;
  final String imageLabel;
  final String? uploadedImageUrl;
  final bool isLoading;
  final bool isSaving;
  final bool isUploadingImage;
  final String? errorMessage;
  final List<ManagedBanner> savedBanners;

  BannerManagerState copyWith({
    ManagedBannerSection? selectedSection,
    ManagedBannerTarget? selectedTarget,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    int? sortOrder,
    String? imageLabel,
    Object? uploadedImageUrl = _bannerUnset,
    bool? isLoading,
    bool? isSaving,
    bool? isUploadingImage,
    Object? errorMessage = _bannerUnset,
    List<ManagedBanner>? savedBanners,
  }) {
    return BannerManagerState(
      selectedSection: selectedSection ?? this.selectedSection,
      selectedTarget: selectedTarget ?? this.selectedTarget,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      imageLabel: imageLabel ?? this.imageLabel,
      uploadedImageUrl: identical(uploadedImageUrl, _bannerUnset)
          ? this.uploadedImageUrl
          : uploadedImageUrl as String?,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isUploadingImage: isUploadingImage ?? this.isUploadingImage,
      errorMessage: identical(errorMessage, _bannerUnset)
          ? this.errorMessage
          : errorMessage as String?,
      savedBanners: List<ManagedBanner>.unmodifiable(
        savedBanners ?? this.savedBanners,
      ),
    );
  }
}

class BannerManagerController
    extends AutoDisposeNotifier<BannerManagerState> {
  late final BannerManagerRepository _repository;

  @override
  BannerManagerState build() {
    _repository = BannerManagerRepository();
    ref.onDispose(_repository.close);
    return BannerManagerState();
  }

  ManagedBannerSection get selectedSection => state.selectedSection;
  ManagedBannerTarget get selectedTarget => state.selectedTarget;
  DateTime get startDate => state.startDate;
  DateTime get endDate => state.endDate;
  bool get isActive => state.isActive;
  int get sortOrder => state.sortOrder;
  String get imageLabel => state.imageLabel;
  String? get uploadedImageUrl => state.uploadedImageUrl;
  bool get isLoading => state.isLoading;
  bool get isSaving => state.isSaving;
  bool get isUploadingImage => state.isUploadingImage;
  String? get errorMessage => state.errorMessage;
  List<ManagedBanner> get savedBanners => state.savedBanners;

  Future<void> loadBanners() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final banners = await _repository.fetchBanners(
        section: state.selectedSection,
      );
      final sorted = [...banners]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      state = state.copyWith(
        savedBanners: sorted,
        errorMessage: null,
      );
    } catch (error) {
      state = state.copyWith(
        savedBanners: const <ManagedBanner>[],
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  void selectSection(ManagedBannerSection section) {
    if (state.selectedSection == section) return;
    state = state.copyWith(
      selectedSection: section,
      selectedTarget: section == ManagedBannerSection.policyBanner
          ? ManagedBannerTarget.policy
          : ManagedBannerTarget.event,
      uploadedImageUrl: null,
      imageLabel: 'No image selected',
      sortOrder: 1,
    );
    loadBanners();
  }

  void selectTarget(ManagedBannerTarget target) {
    state = state.copyWith(selectedTarget: target);
  }

  void setStartDate(DateTime value) {
    final endDate = state.endDate.isBefore(value)
        ? value.add(const Duration(days: 1))
        : state.endDate;
    state = state.copyWith(startDate: value, endDate: endDate);
  }

  void setEndDate(DateTime value) {
    state = state.copyWith(endDate: value);
  }

  void setActive(bool value) {
    state = state.copyWith(isActive: value);
  }

  void setSortOrder(int value) {
    state = state.copyWith(sortOrder: value < 1 ? 1 : value);
  }

  void setUploadedImage({required String url}) {
    state = state.copyWith(
      uploadedImageUrl: url,
      imageLabel: 'Image uploaded',
    );
  }

  void setUploadingImage(bool value) {
    state = state.copyWith(isUploadingImage: value);
  }

  Future<void> saveBanner({required String title}) async {
    final cleanTitle = title.trim();
    final imageUrl = state.uploadedImageUrl?.trim() ?? '';
    if (cleanTitle.isEmpty) throw Exception('Enter banner title');
    if (imageUrl.isEmpty) throw Exception('Upload banner image first');
    if (state.endDate.isBefore(state.startDate)) {
      throw Exception('End date cannot be before start date');
    }
    if (state.isSaving) return;

    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      await _repository.createBanner(
        section: state.selectedSection,
        title: cleanTitle,
        target: state.selectedTarget,
        imageUrl: imageUrl,
        startDate: state.startDate,
        endDate: state.endDate,
        isActive: state.isActive,
        sortOrder: state.sortOrder,
      );
      state = state.copyWith(
        sortOrder: state.sortOrder + 1,
        uploadedImageUrl: null,
        imageLabel: 'No image selected',
      );
      await loadBanners();
    } catch (error) {
      state = state.copyWith(
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
      rethrow;
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  Future<void> toggleBannerActive(ManagedBanner banner) async {
    try {
      await _repository.setActive(
        bannerId: banner.id,
        isActive: !banner.isActive,
      );
      await loadBanners();
    } catch (error) {
      state = state.copyWith(
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}

final bannerManagerControllerProvider =
    NotifierProvider.autoDispose<
      BannerManagerController,
      BannerManagerState
    >(BannerManagerController.new);
