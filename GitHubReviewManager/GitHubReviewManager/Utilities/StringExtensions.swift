import Foundation

extension String {
    /// Creates a stable integer hash from a string
    /// Unlike hashValue (which can vary between runs), this produces a consistent hash
    func stableHash() -> Int {
        var hash = 0
        for char in self.utf8 {
            hash = ((hash << 5) &- hash) &+ Int(char)
        }
        return abs(hash)
    }
}

