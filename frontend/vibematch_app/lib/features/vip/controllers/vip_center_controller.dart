import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/vip_api_service.dart';
import '../models/vip_models.dart';

const Object _vipUnset = Object();

class VipCenterState {
  const VipCenterState({
    required this.payload,
    this.isLoading = false,
    this.errorMessage,
  });

  factory VipCenterState.initial() =>
      VipCenterState(payload: VipCenterPayload.empty);

  final VipCenterPayload payload;
  final bool isLoading;
  final String? errorMessage;

  VipCenterState copyWith({
    VipCenterPayload? payload,
    bool? isLoading,
    Object? errorMessage = _vipUnset,
  }) {
    return VipCenterState(
      payload: payload ?? this.payload,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: identical(errorMessage, _vipUnset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class VipCenterController extends AutoDisposeNotifier<VipCenterState> {
  final VipApiService _api = const VipApiService();

  @override
  VipCenterState build() => VipCenterState.initial();

  Future<void> load() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      state = state.copyWith(
        payload: await _api.loadMyVipCenter(),
        errorMessage: null,
      );
    } catch (error) {
      state = state.copyWith(
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
}

final vipCenterControllerProvider =
    NotifierProvider.autoDispose<VipCenterController, VipCenterState>(
      VipCenterController.new,
    );
