import Foundation

struct BotCategorizer {
    // List of known bot names (without [bot] suffix)
    private static let knownBots = ["renovate", "dependabot", "snyk", "snyk-io", "buildagencygitapitoken"]

    static func categorizeReviewer(_ reviewer: String?) -> String {
        guard let reviewer = reviewer else {
            return "unknown"
        }

        let reviewerLower = reviewer.lowercased()

        // Check if it's a known bot name (case-insensitive)
        for botName in knownBots {
            if reviewerLower == botName || reviewerLower == "\(botName)[bot]" {
                return botName
            }
        }

        // Check if it ends with [bot] suffix
        if reviewer.hasSuffix("[bot]") {
            // Handle special case for "reviews:" prefix
            if reviewer.hasPrefix("reviews:") {
                let botName = reviewer
                    .replacingOccurrences(of: "reviews:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "[bot]", with: "")
                    .lowercased()
                return botName.isEmpty ? "unknown" : botName
            }

            // Extract bot name from "[bot]" suffix
            let botName = reviewer.replacingOccurrences(of: "[bot]", with: "").lowercased()
            return botName.isEmpty ? "unknown" : botName
        }

        // If it doesn't match any bot pattern, it's a human
        return "human"
    }
}

