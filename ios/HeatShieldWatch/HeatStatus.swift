import Foundation

struct HeatStatus {
    var currentTemp: Int = 0          // in Celsius
    var exposureSeconds: Int = 0
    var riskRatio: Double = 0.0       // 0.0 to 1.0
    var isInShadedArea: Bool = false
    var lastUpdated: Date = Date()

    var riskLevelText: String {
        switch riskRatio {
        case ..<0.33: return "LOW"
        case ..<0.66: return "MODERATE"
        default:      return "CRITICAL"
        }
    }

    var formattedExposure: String {
        if exposureSeconds == 0 { return "0 min" }
        if exposureSeconds < 60 { return "\(exposureSeconds)s" }
        let minutes = exposureSeconds / 60
        let seconds = exposureSeconds % 60
        return seconds > 0 ? "\(minutes)m \(seconds)s" : "\(minutes)m"
    }

    /// Initialize from a WatchConnectivity application context dictionary
    init(from context: [String: Any] = [:]) {
        self.currentTemp = context["temp"] as? Int ?? 0
        self.exposureSeconds = context["exposure"] as? Int ?? 0
        self.riskRatio = context["risk"] as? Double ?? 0.0
        self.isInShadedArea = context["shaded"] as? Bool ?? false
        if let ts = context["timestamp"] as? Double {
            self.lastUpdated = Date(timeIntervalSince1970: ts / 1000.0)
        }
    }
}

