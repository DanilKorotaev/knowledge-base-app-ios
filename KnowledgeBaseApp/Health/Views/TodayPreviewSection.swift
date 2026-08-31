import SwiftUI

/// Read-only summary of today’s aggregates (same source as export).
struct TodayPreviewSection: View {
    let data: DailyHealthData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            metricRow(title: "Steps", value: formatInt(data.steps))
            metricRow(title: "Distance", value: formatKm(data.distanceKm))
            metricRow(title: "Active kcal", value: formatCalories(data.activeCalories))
            if let sleep = data.sleep {
                metricRow(title: "Sleep", value: formatSleepMinutes(sleep.totalMinutes))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func metricRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }

    private func formatInt(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    private func formatKm(_ km: Double) -> String {
        String(format: "%.1f km", km)
    }

    private func formatCalories(_ kcal: Double) -> String {
        String(format: "%.0f", kcal)
    }

    private func formatSleepMinutes(_ minutes: Double) -> String {
        let h = Int(minutes / 60)
        let m = Int(minutes.truncatingRemainder(dividingBy: 60))
        return String(format: "%dh %dm", h, m)
    }
}
