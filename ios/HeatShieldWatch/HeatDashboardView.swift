import SwiftUI

struct HeatDashboardView: View {
    @ObservedObject var connectivity = PhoneConnectivityManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                HeatStatusHeader(status: connectivity.heatStatus)
                TemperatureCard(status: connectivity.heatStatus)
                ExposureCard(status: connectivity.heatStatus)
                RiskMeterCard(status: connectivity.heatStatus)
            }
            .padding(.horizontal, 8)
        }
    }
}

// MARK: - Shaded/Exposed Banner

struct HeatStatusHeader: View {
    let status: HeatStatus

    var body: some View {
        HStack {
            Image(systemName: status.isInShadedArea
                  ? "checkmark.circle.fill"
                  : "exclamationmark.triangle.fill")
                .font(.system(size: 16))
            Text(status.isInShadedArea ? "SHADED" : "EXPOSED")
                .font(.system(size: 14, weight: .bold))
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(status.isInShadedArea
                      ? Color.green.opacity(0.8)
                      : Color.red.opacity(0.8))
        )
    }
}

// MARK: - Temperature Card

struct TemperatureCard: View {
    let status: HeatStatus

    var body: some View {
        InfoCard(
            title: "Temperature",
            value: "\(status.currentTemp)°C",
            systemImage: "thermometer.medium"
        )
    }
}

// MARK: - Exposure Card

struct ExposureCard: View {
    let status: HeatStatus

    var body: some View {
        InfoCard(
            title: "Sun Exposure",
            value: status.formattedExposure,
            systemImage: "sun.max.fill"
        )
    }
}

// MARK: - Risk Meter Card

struct RiskMeterCard: View {
    let status: HeatStatus

    private var riskColor: Color {
        switch status.riskRatio {
        case ..<0.33: return .green
        case ..<0.66: return .orange
        default:      return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Risk Level")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                Spacer()
                Text(status.riskLevelText)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(riskColor)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(riskColor)
                        .frame(
                            width: geo.size.width * CGFloat(min(max(status.riskRatio, 0), 1)),
                            height: 8
                        )
                }
            }
            .frame(height: 8)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(white: 0.13))
        )
    }
}

// MARK: - Reusable Info Card

struct InfoCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .foregroundColor(.green)
                .font(.system(size: 16))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(white: 0.13))
        )
    }
}

#Preview {
    HeatDashboardView()
}

