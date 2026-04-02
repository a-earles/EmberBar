import SwiftUI

struct WelcomeStep: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            EmberLogo(size: 64)

            Text("Welcome to EmberBar")
                .font(.system(size: 24, weight: .bold))

            Text("Never hit a Claude limit by surprise.")
                .font(.system(size: 15))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                FeatureRow(icon: "flame.fill", text: "Real-time session & weekly usage tracking")
                FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Burn rate predictions")
                FeatureRow(icon: "bolt.fill", text: "Peak hour 2x detection")
                FeatureRow(icon: "bell.fill", text: "Smart contextual notifications")
            }
            .padding(.top, 8)

            Button(action: onNext) {
                Text("Get Started")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 200, height: 36)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .padding(.top, 12)
        }
        .padding(32)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.orange)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }
}
