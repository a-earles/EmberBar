import SwiftUI

struct PasteValidateStep: View {
    @ObservedObject var appState: AppState
    let onNext: () -> Void
    @State private var cookieText: String = ""
    @State private var isValidating: Bool = false
    @State private var validationError: String?
    @State private var validationSuccess: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("Paste Your Cookie")
                .font(.system(size: 20, weight: .bold))

            Text("Paste the full Cookie value you copied from the Request Headers.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            TextEditor(text: $cookieText)
                .font(.system(size: 12, design: .monospaced))
                .frame(height: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: 1)
                )
                .cornerRadius(8)
                .overlay {
                    if cookieText.isEmpty {
                        Text("Paste your cookie here...")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.5))
                            .allowsHitTesting(false)
                    }
                }

            if let error = validationError {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
            }

            if let success = validationSuccess {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(success)
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                }
            }

            HStack(spacing: 12) {
                if validationSuccess != nil {
                    Button(action: onNext) {
                        Text("Continue")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 140, height: 36)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                } else {
                    Button(action: validate) {
                        if isValidating {
                            ProgressView()
                                .controlSize(.small)
                                .frame(width: 140, height: 36)
                        } else {
                            Text("Connect")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 140, height: 36)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(cookieText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isValidating)
                }
            }
            .padding(.top, 8)
        }
        .padding(24)
    }

    private var borderColor: Color {
        if validationError != nil { return .red }
        if validationSuccess != nil { return .green }
        return .gray.opacity(0.3)
    }

    private func validate() {
        let cookie = cookieText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cookie.isEmpty else { return }

        // Input validation
        guard cookie.count <= 8192 else {
            validationError = "Cookie value is too long. Please copy only the Cookie header value."
            return
        }
        guard cookie.contains("sessionKey=") else {
            validationError = "This doesn't look like a valid Claude cookie. Make sure it contains 'sessionKey='."
            return
        }

        isValidating = true
        validationError = nil
        validationSuccess = nil

        Task { @MainActor in
            do {
                let result = await appState.validateAndSaveCookie(cookie)
                isValidating = false
                switch result {
                case .success(let orgName):
                    let resetInfo: String
                    if let reset = appState.sessionResetTime {
                        resetInfo = " Session resets in \(TimeFormatting.shortDuration(reset))."
                    } else {
                        resetInfo = ""
                    }
                    validationSuccess = "Connected! Organization: \(orgName).\(resetInfo)"
                case .failure(let error):
                    switch error {
                    case .invalidCookie:
                        validationError = "Invalid cookie. Make sure you copied the entire Cookie value, not just part of it."
                    case .networkError:
                        validationError = "Network error. Check your internet connection and try again."
                    case .decodingError:
                        validationError = "Unexpected response from Claude. The cookie may be invalid or the API may have changed."
                    default:
                        validationError = error.localizedDescription
                    }
                }
            } catch {
                isValidating = false
                validationError = "Unexpected error: \(error.localizedDescription)"
            }
        }
    }
}
