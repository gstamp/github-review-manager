import Foundation

struct DateCalculator {
    static func daysSince(_ dateString: String) -> Double? {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return nil
        }

        let interval = Date().timeIntervalSince(date)
        return interval / (60 * 60 * 24) // Convert to days
    }

    static func daysWaiting(_ dateString: String?) -> Double? {
        guard let dateString = dateString else {
            return nil
        }
        return daysSince(dateString)
    }
}

