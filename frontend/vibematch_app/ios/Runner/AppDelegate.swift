import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "FunKeyPowerState"
    )
    let channel = FlutterMethodChannel(
      name: "funkey/power_state",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "getPowerState" else {
        result(FlutterMethodNotImplemented)
        return
      }

      UIDevice.current.isBatteryMonitoringEnabled = true
      let rawLevel = UIDevice.current.batteryLevel
      let level: Any = rawLevel < 0
        ? NSNull()
        : Int((rawLevel * 100).rounded())

      result([
        "batteryLevel": level,
        "lowPowerMode": ProcessInfo.processInfo.isLowPowerModeEnabled,
      ])
    }
  }
}
