import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum MobileRuntimeTier { normal, constrained, background }

class MobilePowerState {
  const MobilePowerState({
    required this.batteryLevel,
    required this.lowPowerMode,
  });

  final int? batteryLevel;
  final bool lowPowerMode;
}

abstract interface class MobilePowerStateSource {
  Future<MobilePowerState> read();
}

/// Uses a tiny first-party MethodChannel instead of adding another plugin.
///
/// Android and iOS implement the channel. Unsupported platforms fail open to an
/// unknown battery percentage while lifecycle still applies the background tier.
class PlatformMobilePowerStateSource implements MobilePowerStateSource {
  const PlatformMobilePowerStateSource();

  static const MethodChannel _channel = MethodChannel('funkey/power_state');

  @override
  Future<MobilePowerState> read() async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('getPowerState');
      final level = raw?['batteryLevel'];
      final lowPower = raw?['lowPowerMode'];
      return MobilePowerState(
        batteryLevel: level is int ? level.clamp(0, 100) : null,
        lowPowerMode: lowPower == true,
      );
    } on PlatformException {
      return const MobilePowerState(batteryLevel: null, lowPowerMode: false);
    } on MissingPluginException {
      return const MobilePowerState(batteryLevel: null, lowPowerMode: false);
    }
  }
}

class MobileRuntimeBudget {
  const MobileRuntimeBudget({
    required this.tier,
    required this.allowSpeculativePrefetch,
    required this.maxConcurrentPrefetch,
    required this.backgroundNetworkInterval,
  });

  final MobileRuntimeTier tier;
  final bool allowSpeculativePrefetch;
  final int maxConcurrentPrefetch;
  final Duration backgroundNetworkInterval;
}

/// Battery/lifecycle signal only. It never becomes domain authority.
class MobileRuntimeBudgetController {
  MobileRuntimeBudgetController({
    MobilePowerStateSource powerStateSource =
        const PlatformMobilePowerStateSource(),
  }) : _powerStateSource = powerStateSource;

  final MobilePowerStateSource _powerStateSource;
  bool _foreground = true;
  bool _lowPowerMode = false;
  int? _batteryLevel;

  MobileRuntimeBudget get current {
    if (!_foreground) {
      return const MobileRuntimeBudget(
        tier: MobileRuntimeTier.background,
        allowSpeculativePrefetch: false,
        maxConcurrentPrefetch: 0,
        backgroundNetworkInterval: Duration(minutes: 15),
      );
    }
    if (_lowPowerMode || (_batteryLevel != null && _batteryLevel! <= 20)) {
      return const MobileRuntimeBudget(
        tier: MobileRuntimeTier.constrained,
        allowSpeculativePrefetch: false,
        maxConcurrentPrefetch: 1,
        backgroundNetworkInterval: Duration(minutes: 5),
      );
    }
    return const MobileRuntimeBudget(
      tier: MobileRuntimeTier.normal,
      allowSpeculativePrefetch: true,
      maxConcurrentPrefetch: 2,
      backgroundNetworkInterval: Duration(minutes: 1),
    );
  }

  Future<void> refresh() async {
    final state = await _powerStateSource.read();
    _batteryLevel = state.batteryLevel;
    _lowPowerMode = state.lowPowerMode;
  }

  Future<void> setForeground(bool foreground) async {
    _foreground = foreground;
    if (foreground) await refresh();
  }
}

final mobileRuntimeBudgetProvider = Provider<MobileRuntimeBudgetController>(
  (ref) => MobileRuntimeBudgetController(),
);
