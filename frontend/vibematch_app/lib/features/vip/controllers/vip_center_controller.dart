import 'package:flutter/foundation.dart';

import '../data/vip_api_service.dart';
import '../models/vip_models.dart';

class VipCenterController extends ChangeNotifier {
  VipCenterController({VipApiService? api}) : _api = api ?? const VipApiService();

  final VipApiService _api;

  VipCenterPayload payload = VipCenterPayload.empty;
  bool isLoading = false;
  String? errorMessage;

  Future<void> load() async {
    if (isLoading) return;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      payload = await _api.loadMyVipCenter();
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
