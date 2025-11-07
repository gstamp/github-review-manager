import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()

    private init() {}

    /// Request notification permissions from the user
    func requestPermissions() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("Error requesting notification permissions: \(error)")
            return false
        }
    }

    /// Send a notification for a new review
    func sendReviewNotification(prNumber: Int, prTitle: String, reviewState: String) {
        let content = UNMutableNotificationContent()
        content.title = "New Review on PR #\(prNumber)"
        content.body = "\(prTitle)"

        // Add review state to subtitle if available
        let stateLabel: String = {
            switch reviewState {
            case "APPROVED":
                return "Approved"
            case "CHANGES_REQUESTED":
                return "Changes Requested"
            case "COMMENTED":
                return "Commented"
            default:
                return reviewState
            }
        }()
        content.subtitle = stateLabel
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Send immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending notification: \(error)")
            }
        }
    }

    /// Send a notification for a new review request
    func sendReviewRequestNotification(prNumber: Int, prTitle: String, category: String) {
        let content = UNMutableNotificationContent()
        content.title = "New Review Request #\(prNumber)"
        content.body = "\(prTitle)"

        // Format category label (same logic as ContentView)
        let categoryLabel: String = {
            switch category {
            case "human":
                return "From Humans"
            case "buildagencygitapitoken":
                return "Promotions"
            case "snyk-io":
                return "Snyk-io"
            case "renovate":
                return "Renovate"
            default:
                return category.prefix(1).uppercased() + category.dropFirst()
            }
        }()
        content.subtitle = categoryLabel
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Send immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending notification: \(error)")
            }
        }
    }

    /// Send a notification for merge errors
    func sendMergeErrorNotification(prNumber: Int, prTitle: String, errorMessage: String) {
        let content = UNMutableNotificationContent()
        content.title = "Failed to Merge PR #\(prNumber)"
        content.body = "\(prTitle)"
        content.subtitle = errorMessage
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Send immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending merge error notification: \(error)")
            }
        }
    }
}

