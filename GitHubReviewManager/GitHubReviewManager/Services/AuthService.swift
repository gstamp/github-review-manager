import Foundation

class AuthService {
    static let shared = AuthService()

    private let keychainService = KeychainService.shared

    private init() {}

    /// Attempts to get a GitHub token from multiple sources in priority order:
    /// 1. `gh auth token` command
    /// 2. GITHUB_TOKEN environment variable
    /// 3. Keychain (manually saved token)
    /// - Returns: The GitHub token, or nil if no source is available
    func getGitHubToken() async -> String? {
        // Try gh auth token first
        if let token = try? await getTokenFromGHCLI() {
            print("Got token from gh CLI")
            return token
        } else {
            print("Failed to get token from gh CLI")
        }

        // Fall back to environment variable
        if let envToken = ProcessInfo.processInfo.environment["GITHUB_TOKEN"], !envToken.isEmpty {
            print("Got token from GITHUB_TOKEN environment variable")
            return envToken
        }

        // Fall back to Keychain
        if let keychainToken = keychainService.getToken() {
            print("Got token from Keychain")
            return keychainToken
        }

        print("No token available from any source")
        return nil
    }

    /// Save a user-provided token to the Keychain
    /// - Parameter token: The token to save
    /// - Returns: True if successful
    @discardableResult
    func saveToken(_ token: String) -> Bool {
        return keychainService.saveToken(token)
    }

    /// Clear the stored token from Keychain (sign out)
    @discardableResult
    func clearToken() -> Bool {
        return keychainService.deleteToken()
    }

    /// Check if there's a token stored in Keychain
    func hasStoredToken() -> Bool {
        return keychainService.hasToken()
    }

    private func getTokenFromGHCLI() async throws -> String? {
        // Use /usr/bin/env to find gh in PATH (works with mise, brew, etc.)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["gh", "auth", "token"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe() // Capture stderr to prevent it from polluting console

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return nil
        }

        let token = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return token.isEmpty ? nil : token
    }
}

