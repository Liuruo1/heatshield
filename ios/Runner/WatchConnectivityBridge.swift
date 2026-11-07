import Foundation
import WatchConnectivity

final class WatchConnectivityBridge: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityBridge()

    private let session = WCSession.default

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else {
            return
        }
        session.delegate = self
        session.activate()
    }

    func updateStatus(
        temperature: Int?,
        exposure: Int,
        risk: Double,
        shaded: Bool,
        safeExposureSeconds: Int?,
        timestampMilliseconds: Int64
    ) throws -> Bool {
        guard WCSession.isSupported(), session.isPaired, session.isWatchAppInstalled else {
            return false
        }
        guard session.activationState == .activated else {
            return false
        }

        var applicationContext: [String: Any] = [
            "exposure": exposure,
            "risk": risk,
            "shaded": shaded,
            "timestampMs": timestampMilliseconds,
        ]
        if let temperature = temperature {
            applicationContext["temp"] = temperature
        }
        if let safeExposureSeconds = safeExposureSeconds {
            applicationContext["safeExposureSeconds"] = safeExposureSeconds
        }

        try session.updateApplicationContext(applicationContext)
        return true
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            NSLog("WatchConnectivity activation failed: %@", error.localizedDescription)
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
