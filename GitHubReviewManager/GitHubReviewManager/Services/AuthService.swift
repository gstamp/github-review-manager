import Foundation

class AuthService {
    static let shared = AuthService()

    private init() {}

    /// Attempts to get a GitHub token from `gh auth token` command, falling back to GITHUB_TOKEN env var.
    /// - Returns: The GitHub token, or nil if neither source is available
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

        print("No token available from either source")
        // Neither source available
        return nil
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

