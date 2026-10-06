"""Chunk 46 mobile runtime/offline/battery guard."""
from __future__ import annotations
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def main():
    policy=json.loads((ROOT/"contracts/mobile/runtime-policy-v1.json").read_text())
    if "wallet." not in policy["forbidden_offline_command_prefixes"]:
        raise SystemExit("wallet mutations must be forbidden offline")
    store=(ROOT/"frontend/vibematch_app/lib/foundation/offline/offline_projection_store.dart").read_text()
    for marker in ("AppKeyValueStore", "maxRows = 64", "OfflineMutationPolicy"):
        if marker not in store: raise SystemExit(f"offline store missing {marker}")
    runtime=(ROOT/"frontend/vibematch_app/lib/foundation/runtime/mobile_runtime_budget.dart").read_text()
    for marker in ("MethodChannel('funkey/power_state')", "MobileRuntimeTier.background", "batteryLevel"):
        if marker not in runtime: raise SystemExit(f"mobile budget missing {marker}")
    android=(ROOT/"frontend/vibematch_app/android/app/src/main/kotlin/com/funkey/app/MainActivity.kt").read_text()
    ios=(ROOT/"frontend/vibematch_app/ios/Runner/AppDelegate.swift").read_text()
    if "funkey/power_state" not in android or "BatteryManager" not in android:
        raise SystemExit("Android power-state channel missing")
    if "funkey/power_state" not in ios or "isLowPowerModeEnabled" not in ios:
        raise SystemExit("iOS power-state channel missing")
    if not (ROOT/"docs/platform/chunk46-mobile-runtime-offline.md").is_file():
        raise SystemExit("Chunk 46 docs missing")
    print("Mobile runtime/offline guard: OK")
if __name__=="__main__": main()
