import Flutter
import UIKit
import WatchConnectivity

@main
@objc class AppDelegate: FlutterAppDelegate, WCSessionDelegate {

    private var wcSession: WCSession?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // Activate WatchConnectivity session
        if WCSession.isSupported() {
            wcSession = WCSession.default
            wcSession?.delegate = self
            wcSession?.activate()
        }

        // Set up Flutter MethodChannel — same channel name as the Dart WatchCompanionService
        let controller = window?.rootViewController as! FlutterViewController
        let channel = FlutterMethodChannel(
            name: "com.example.heatshield/watch_companion",
            binaryMessenger: controller.binaryMessenger
        )

        channel.setMethodCallHandler { [weak self] (call, result) in
            switch call.method {
            case "isWatchReachable":
                result(self?.wcSession?.isReachable ?? false)

            case "sendMessageToWatch":
                guard let args = call.arguments as? [String: Any],
                      let payload = args["payload"] as? String else {
                    result(false)
                    return
                }
                if let session = self?.wcSession, session.isReachable {
                    let data: [String: Any] = ["payload": payload]
                    session.sendMessage(data, replyHandler: nil) { error in
                        print("WC sendMessage error: \(error)")
                    }
                    result(true)
                } else {
                    result(false)
                }

            case "sendHeatStatusToWatch":
                guard let args = call.arguments as? [String: Any] else {
                    result(false)
                    return
                }
                let context: [String: Any] = [
                    "temp": args["temp"] as? Int ?? 0,
                    "exposure": args["exposure"] as? Int ?? 0,
                    "risk": args["risk"] as? Double ?? 0.0,
                    "shaded": args["shaded"] as? Bool ?? false,
                    "timestamp": Date().timeIntervalSince1970 * 1000
                ]

                // Use sendMessage for real-time delivery when reachable,
                // fall back to updateApplicationContext for background delivery.
                if let session = self?.wcSession {
                    if session.isReachable {
                        session.sendMessage(context, replyHandler: nil) { error in
                            print("WC sendMessage error: \(error)")
                        }
                    }
                    // Always update application context so the watch has
                    // the latest data even if it was backgrounded.
                    do {
                        try session.updateApplicationContext(context)
                    } catch {
                        print("WC updateApplicationContext error: \(error)")
                    }
                    result(true)
                } else {
                    result(false)
                }

            default:
                result(FlutterMethodNotImplemented)
            }
        }

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // MARK: - WCSessionDelegate (required on iOS)

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        print("WCSession activation: \(activationState.rawValue)")
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate for switching between multiple Apple Watches
        session.activate()
    }
}
