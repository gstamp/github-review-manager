import SwiftUI

struct StatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}

struct StatusStatePill: View {
    let state: StatusState

    var body: some View {
        let (text, color) = {
            switch state {
            case .success:
                return ("success", Color.green)
            case .failure:
                return ("failure", Color.red)
            case .pending:
                return ("pending", Color.orange)
            case .error:
                return ("error", Color.red)
            }
        }()

        StatusPill(text: text, color: color)
    }
}

struct ReviewStatusPill: View {
    let status: ReviewStatus

    var body: some View {
        let (text, color) = {
            switch status {
            case .waiting:
                return ("waiting", Color.orange)
            case .approved:
                return ("approved", Color.green)
            case .changesRequested:
                return ("changes_requested", Color.red)
            case .commented:
                return ("commented", Color.blue)
            }
        }()

        StatusPill(text: text, color: color)
    }
}

struct PRStatePill: View {
    let state: PRState

    var body: some View {
        let (text, color) = {
            switch state {
            case .open:
                return ("open", Color.green)
            case .closed:
                return ("closed", Color.gray)
            case .merged:
                return ("merged", Color.purple)
            }
        }()

        StatusPill(text: text, color: color)
    }
}

struct ConflictPill: View {
    var body: some View {
        StatusPill(text: "conflicts", color: Color.red)
    }
}

struct DraftPill: View {
    var body: some View {
        StatusPill(text: "draft", color: Color.purple)
    }
}

struct SnoozedPill: View {
    var body: some View {
        StatusPill(text: "snoozed", color: Color.orange)
    }
}

struct DismissedPill: View {
    var body: some View {
        StatusPill(text: "dismissed", color: Color.gray)
    }
}

