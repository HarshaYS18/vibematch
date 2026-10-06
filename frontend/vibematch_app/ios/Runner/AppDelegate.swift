import Flutter
import UIKit

final class FunKeyGrowthBridge {
  static let shared = FunKeyGrowthBridge()

  private var channel: FlutterMethodChannel?
  private var pendingLink: String?

  private init() {}

  func attach(to messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "funkey/growth",
      binaryMessenger: messenger
    )
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      switch call.method {
      case "getInitialLink":
        let link = self.pendingLink
        self.pendingLink = nil
        result(link)
      case "shareText":
        guard
          let arguments = call.arguments as? [String: Any],
          let text = arguments["text"] as? String,
          !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
          result(
            FlutterError(
              code: "invalid_share",
              message: "Share text is empty.",
              details: nil
            )
          )
          return
        }
        self.share(text: text, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func accept(url: URL) {
    let raw = url.absoluteString
    pendingLink = raw
    channel?.invokeMethod("link", arguments: raw)
  }

  private func share(text: String, result: @escaping FlutterResult) {
    guard
      let scene = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .first(where: { $0.activationState == .foregroundActive }),
      let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
    else {
      result(
        FlutterError(
          code: "share_unavailable",
          message: "No active window is available.",
          details: nil
        )
      )
      return
    }

    var presenter = root
    while let presented = presenter.presentedViewController {
      presenter = presented
    }

    let controller = UIActivityViewController(
      activityItems: [text],
      applicationActivities: nil
    )
    if let popover = controller.popoverPresentationController {
      popover.sourceView = presenter.view
      popover.sourceRect = CGRect(
        x: presenter.view.bounds.midX,
        y: presenter.view.bounds.midY,
        width: 1,
        height: 1
      )
      popover.permittedArrowDirections = []
    }
    presenter.present(controller, animated: true)
    result(true)
  }
}

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
    FunKeyGrowthBridge.shared.attach(to: registrar.messenger())

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
