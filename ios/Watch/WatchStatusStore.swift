import Combine
import Foundation
import WatchConnectivity

struct HeatStatus {
    let temperatureCelsius: Int?
    let exposureSeconds: Int
    let riskRatio: Double
    let isShaded: Bool
    let safeExposureSeconds: Int?
    let updatedAt: Date

    init?(applicationContext: [String: Any]) {
        guard
            let exposure = applicationContext["exposure"] as? NSNumber,
            let risk = applicationContext["risk"] as? NSNumber,
            let shaded = applicationContext["shaded"] as? NSNumber,
            let timestamp = applicationContext["timestampMs"] as? NSNumber,
            risk.doubleValue.isFinite
        else {
            return nil
        }

        temperatureCelsius = (applicationContext["temp"] as? NSNumber)?.intValue
        exposureSeconds = max(0, exposure.intValue)
        riskRatio = min(max(risk.doubleValue, 0), 1)
        isShaded = shaded.boolValue
        safeExposureSeconds = (applicationContext["safeExposureSeconds"] as? NSNumber).map {
            max(0, $0.intValue)
        }
        updatedAt = Date(timeIntervalSince1970: timestamp.doubleValue / 1_000)
    }

    var formattedExposure: String {
        Self.formatDuration(exposureSeconds)
    }

    var riskDescription: String {
        "\(Int((riskRatio * 100).rounded()))% · \(riskLevel)"
    }

    private var riskLevel: String {
        switch riskRatio {
        case ..<0.33: return "Low"
        case ..<0.66: return "Moderate"
        default: return "Critical"
        }
    }

    func isStale(at date: Date) -> Bool {
        date.timeIntervalSince(updatedAt) > 90
    }

    static func formatDuration(_ seconds: Int) -> String {
        let safeSeconds = max(0, seconds)
        if safeSeconds < 60 {
            return "\(safeSeconds)s"
        }
        let minutes = safeSeconds / 60
        let remainder = safeSeconds % 60
        return remainder == 0 ? "\(minutes)m" : "\(minutes)m \(remainder)s"
    }
}

final class WatchStatusStore: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var status: HeatStatus?

    private let session = WCSession.default

    override init() {
        super.init()
        guard WCSession.isSupported() else {
            return
        }

        session.delegate = self
        status = HeatStatus(applicationContext: session.receivedApplicationContext)
        session.activate()
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let receivedStatus = HeatStatus(applicationContext: applicationContext) else {
            return
        }
        DispatchQueue.main.async {
            self.status = receivedStatus
        }
    }
}
