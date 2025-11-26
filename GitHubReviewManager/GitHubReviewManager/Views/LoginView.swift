import SwiftUI
import AppKit

struct LoginView: View {
    @State private var token: String = ""
    @State private var isValidating = false
    @State private var errorMessage: String?

    let onSuccess: () -> Void
    let onCancel: () -> Void

    private let tokenURL = URL(string: "https://github.com/settings/tokens/new?scopes=repo&description=GitHub%20Review%20Manager")!

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)

                Text("GitHub Authentication Required")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("To use GitHub Review Manager, you need to provide a Personal Access Token.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 10)

            Divider()

            // Instructions
            VStack(alignment: .leading, spacing: 12) {
                Text("Steps to create a token:")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Text("1.")
                            .fontWeight(.medium)
                        Text("Click the button below to open GitHub token settings")
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Text("2.")
                            .fontWeight(.medium)
                        Text("Generate a new token (classic) with 'repo' scope")
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Text("3.")
                            .fontWeight(.medium)
                        Text("Copy the token and paste it below")
                    }
                }
                .font(.callout)
                .foregroundColor(.secondary)

                Button(action: {
                    NSWorkspace.shared.open(tokenURL)
                }) {
                    HStack {
                        Image(systemName: "arrow.up.right.square")
                        Text("Create Token on GitHub")
                    }
                }
                .buttonStyle(.borderedProminent)
                .hoverCursor(.pointingHand)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // Token input
            VStack(alignment: .leading, spacing: 8) {
                Text("Personal Access Token")
                    .font(.headline)

                SecureField("ghp_xxxxxxxxxxxxxxxxxxxx", text: $token)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Spacer()

            // Actions
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                .hoverCursor(.pointingHand)

                Spacer()

                Button(action: validateAndSave) {
                    if isValidating {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                    } else {
                        Text("Save Token")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(token.isEmpty || isValidating)
                .keyboardShortcut(.defaultAction)
                .hoverCursor(.pointingHand)
            }
        }
        .padding(24)
        .frame(width: 450, height: 450)
    }

    private func validateAndSave() {
        errorMessage = nil
        isValidating = true

        Task {
            let isValid = await validateToken(token)

            await MainActor.run {
                isValidating = false

                if isValid {
                    AuthService.shared.saveToken(token)
                    onSuccess()
                } else {
                    errorMessage = "Invalid token. Please check that it has the 'repo' scope and try again."
                }
            }
        }
    }

    private func validateToken(_ token: String) async -> Bool {
        guard let url = URL(string: "https://api.github.com/user") else {
            return false
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            return httpResponse.statusCode == 200
        } catch {
            print("Token validation error: \(error)")
            return false
        }
    }
}


