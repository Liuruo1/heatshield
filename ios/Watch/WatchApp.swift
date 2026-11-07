import SwiftUI

@main
struct HeatShieldWatchApp: App {
    @StateObject private var statusStore = WatchStatusStore()

    var body: some Scene {
        WindowGroup {
            HeatShieldWatchView()
                .environmentObject(statusStore)
        }
    }
}

private struct HeatShieldWatchView: View {
    @EnvironmentObject private var statusStore: WatchStatusStore

    var body: some View {
        Group {
            if let status = statusStore.status {
                TimelineView(.periodic(from: .now, by: 15)) { timeline in
                    statusContent(status, now: timeline.date)
                }
            } else {
                ContentUnavailableView(
                    "Waiting for iPhone",
                    systemImage: "iphone",
                    description: Text("Open HeatShield on your iPhone to sync the latest heat status.")
                )
            }
        }
    }

    private func statusContent(_ status: HeatStatus, now: Date) -> some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("HEATSHIELD")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)

                Text(status.isShaded ? "SHADED" : "EXPOSED")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(status.isShaded ? .green : .red)

                VStack(spacing: 2) {
                    Text(status.temperatureCelsius.map { "\($0)°" } ?? "—")
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text("TEMPERATURE")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                statusRow("Exposure", value: status.formattedExposure)
                statusRow("Risk", value: status.riskDescription)

                if let limit = status.safeExposureSeconds {
                    statusRow("Safe limit", value: HeatStatus.formatDuration(limit))
                }

                if status.isStale(at: now) {
                    Text("STALE · Updated \(status.updatedAt, style: .relative)")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Updated \(status.updatedAt, style: .relative)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
        }
    }

    private func statusRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
        .font(.caption)
    }
}
