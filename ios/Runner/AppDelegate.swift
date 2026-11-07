import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var watchStatusChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let didFinishLaunching = super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )

    WatchConnectivityBridge.shared.activate()
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "com.example.heatshield/watch_companion",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { call, result in
        guard call.method == "updateWatchStatus" else {
          result(FlutterMethodNotImplemented)
          return
        }

        guard
          let arguments = call.arguments as? [String: Any],
          let exposure = (arguments["exposure"] as? NSNumber)?.intValue,
          let risk = (arguments["risk"] as? NSNumber)?.doubleValue,
          let shaded = (arguments["shaded"] as? NSNumber)?.boolValue,
          let timestamp = (arguments["timestampMs"] as? NSNumber)?.int64Value,
          risk.isFinite
        else {
          result(FlutterError(
            code: "INVALID_WATCH_STATUS",
            message: "A complete, finite watch status payload is required.",
            details: nil
          ))
          return
        }

        let temperature = (arguments["temp"] as? NSNumber)?.intValue
        let safeExposureSeconds = (arguments["safeExposureSeconds"] as? NSNumber)?.intValue
        do {
          result(try WatchConnectivityBridge.shared.updateStatus(
            temperature: temperature,
            exposure: exposure,
            risk: risk,
            shaded: shaded,
            safeExposureSeconds: safeExposureSeconds,
            timestampMilliseconds: timestamp
          ))
        } catch {
          result(FlutterError(
            code: "WATCH_STATUS_UPDATE_FAILED",
            message: error.localizedDescription,
            details: nil
          ))
        }
      }
      watchStatusChannel = channel
    } else {
      NSLog("Unable to initialize the HeatShield watch status channel.")
    }

    return didFinishLaunching
  }
}
