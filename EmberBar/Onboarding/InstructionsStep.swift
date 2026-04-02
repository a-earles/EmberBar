import SwiftUI

struct InstructionsStep: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Get Your Session Cookie")
                .font(.system(size: 20, weight: .bold))

            Text("EmberBar needs your Claude session cookie to fetch usage data.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    InstructionRow(number: 1, title: "Open", detail: "claude.ai/settings/usage", isLink: true)
                    InstructionRow(number: 2, title: "Open Developer Tools", detail: "Press  Cmd + Option + I", isLink: false)
                    InstructionRow(number: 3, title: "Go to the", detail: "Network  tab", isLink: false)
                    InstructionRow(number: 4, title: "Refresh the page", detail: "Press  Cmd + R", isLink: false)
                    InstructionRow(number: 5, title: "Click the request named", detail: "\"usage\"", isLink: false)
                    InstructionRow(number: 6, title: "Copy the full", detail: "\"Cookie\"  value from Request Headers", isLink: false)
                }
                .padding(16)
            }
            .background(Color(.controlBackgroundColor).opacity(0.5))
            .cornerRadius(10)

            Button(action: onNext) {
                Text("I've Copied the Cookie")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 220, height: 36)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .padding(.top, 4)
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }
}

struct InstructionRow: View {
    let number: Int
    let title: String
    let detail: String
    let isLink: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.orange)
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))
                if isLink {
                    Text(detail)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.blue)
                        .onTapGesture {
                            if let url = URL(string: "https://\(detail)") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                } else {
                    Text(detail)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                }
            }
        }
    }
}
