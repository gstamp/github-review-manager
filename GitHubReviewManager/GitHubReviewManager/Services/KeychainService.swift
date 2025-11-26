import Foundation
import Security

class KeychainService {
    static let shared = KeychainService()

    private let serviceName = "com.github-review-manager.token"
    private let accountName = "github-token"

    private init() {}

    /// Save a token to the Keychain
    /// - Parameter token: The token to save
    /// - Returns: True if successful, false otherwise
    @discardableResult
    func saveToken(_ token: String) -> Bool {
        guard let tokenData = token.data(using: .utf8) else {
            return false
        }

        // Delete any existing token first
        deleteToken()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecValueData as String: tokenData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Keychain save failed with status: \(status)")
        }
        return status == errSecSuccess
    }

    /// Retrieve the token from the Keychain
    /// - Returns: The stored token, or nil if not found
    func getToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }

        return token
    }

    /// Delete the token from the Keychain
    /// - Returns: True if successful or item didn't exist, false on error
    @discardableResult
    func deleteToken() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Check if a token exists in the Keychain
    /// - Returns: True if a token is stored
    func hasToken() -> Bool {
        return getToken() != nil
    }
}


