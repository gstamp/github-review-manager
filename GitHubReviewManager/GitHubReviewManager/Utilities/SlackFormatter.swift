import Foundation
import AppKit

struct SlackFormatter {
    static func formatMessage(pr: any PRItem) -> String {
        // Extract JIRA issue number from PR title (pattern: uppercase letters-dash-numbers, e.g., ATM-1312)
        let jiraPattern = try! NSRegularExpression(pattern: "([A-Z]+-\\d+)", options: [])
        let titleRange = NSRange(pr.title.startIndex..., in: pr.title)

        var message = ":pr: [PR#\(pr.number)](\(pr.url)) (\(pr.repoName))"

        if let match = jiraPattern.firstMatch(in: pr.title, options: [], range: titleRange),
           let range = Range(match.range(at: 1), in: pr.title) {
            let jiraId = String(pr.title[range])
            // Construct JIRA URL (assuming myseek.atlassian.net domain)
            let jiraUrl = "https://myseek.atlassian.net/browse/\(jiraId)"
            message += " [\(jiraId)](\(jiraUrl))"
        }

        message += " \(pr.title)"

        return message
    }

    static func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

// Protocol for PR items that can be formatted for Slack
protocol PRItem {
    var number: Int { get }
    var url: String { get }
    var repoName: String { get }
    var title: String { get }
}

extension PRSummary: PRItem {}
extension ReviewRequest: PRItem {}

