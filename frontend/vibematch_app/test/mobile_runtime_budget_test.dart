import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/foundation/runtime/mobile_runtime_budget.dart';

class _FakePowerStateSource implements MobilePowerStateSource {
  const _FakePowerStateSource(this.state);
  final MobilePowerState state;

  @override
  Future<MobilePowerState> read() async => state;
}

void main() {
  test('background tier disables speculative prefetch', () async {
    final controller = MobileRuntimeBudgetController(
      powerStateSource: const _FakePowerStateSource(
        MobilePowerState(batteryLevel: 90, lowPowerMode: false),
      ),
    );
    await controller.setForeground(false);
    expect(controller.current.tier, MobileRuntimeTier.background);
    expect(controller.current.allowSpeculativePrefetch, isFalse);
    expect(controller.current.maxConcurrentPrefetch, 0);
  });

  test('low battery constrains speculative work', () async {
    final controller = MobileRuntimeBudgetController(
      powerStateSource: const _FakePowerStateSource(
        MobilePowerState(batteryLevel: 15, lowPowerMode: false),
      ),
    );
    await controller.refresh();
    expect(controller.current.tier, MobileRuntimeTier.constrained);
    expect(controller.current.allowSpeculativePrefetch, isFalse);
  });
}
