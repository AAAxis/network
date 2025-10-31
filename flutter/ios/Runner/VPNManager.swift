//
//  VPNManager.swift
//  Runner
//
//  Created for Flutter VPN App
//

import Foundation
import NetworkExtension
import Security

class VPNManager: NSObject {
    static let shared = VPNManager()
    
    private var vpnManager: NEVPNManager?
    private var statusObserver: NSObjectProtocol?
    
    // Keychain identifiers
    private let kKeychainVPNUsernameKey = "com.rockvpn.username"
    private let kKeychainVPNPasswordKey = "com.rockvpn.password"
    private let kKeychainVPNSharedSecretKey = "com.rockvpn.sharedsecret"
    private let kKeychainVPNServerAddressKey = "com.rockvpn.serveraddress"
    
    override init() {
        super.init()
        setupVPNManager()
    }
    
    deinit {
        if let observer = statusObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupVPNManager() {
        vpnManager = NEVPNManager.shared()
        
        // Observe VPN status changes
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.statusDidChange()
        }
    }
    
    private func statusDidChange() {
        guard let manager = vpnManager else { return }
        
        let status = manager.connection.status
        let statusString = vpnStatusString(status)
        let serverAddress = manager.protocolConfiguration?.serverAddress ?? "Unknown"
        
        // Get country info from server address or configuration
        var countryName: String? = nil
        var countryCode: String? = nil
        
        // Try to extract country from server address or use stored info
        if let serverAddr = manager.protocolConfiguration?.serverAddress {
            // You could parse server address or store country info separately
            countryName = serverAddr.contains("us") || serverAddr.contains("usa") ? "United States" :
                         serverAddr.contains("de") || serverAddr.contains("germany") ? "Germany" :
                         serverAddr.contains("il") || serverAddr.contains("israel") ? "Israel" :
                         serverAddr.contains("uk") || serverAddr.contains("gb") ? "United Kingdom" :
                         serverAddr.contains("ru") || serverAddr.contains("russia") ? "Russia" : nil
        }
        
        // Notify Flutter about status change with detailed info
        NotificationCenter.default.post(
            name: .vpnStatusChanged,
            object: nil,
            userInfo: [
                "status": statusString,
                "isConnected": status == .connected,
                "countryName": countryName ?? "Unknown",
                "serverAddress": serverAddress
            ]
        )
        
        // Log detailed status
        print("📡 VPN Status: \(statusString) - Server: \(serverAddress) - Country: \(countryName ?? "Unknown")")
        
        // If connected, verify connection after a delay
        if status == .connected {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.verifyVPNConnection()
            }
        }
    }
    
    // Verify VPN connection is actually routing traffic
    private func verifyVPNConnection() {
        guard let manager = vpnManager else { return }
        guard manager.connection.status == .connected else { return }
        
        print("🔍 Verifying VPN connection...")
        // The actual verification happens in Flutter by checking IP change
        // This is just a placeholder for native-side verification if needed
    }
    
    private func vpnStatusString(_ status: NEVPNStatus) -> String {
        switch status {
        case .invalid:
            return "invalid"
        case .disconnected:
            return "disconnected"
        case .connecting:
            return "connecting"
        case .connected:
            return "connected"
        case .reasserting:
            return "reasserting"
        case .disconnecting:
            return "disconnecting"
        @unknown default:
            return "unknown"
        }
    }
    
    // MARK: - Public Methods for Flutter
    
    func getCurrentStatus() -> [String: Any] {
        guard let manager = vpnManager else {
            return ["status": "invalid", "isConnected": false]
        }
        
        let status = manager.connection.status
        return [
            "status": vpnStatusString(status),
            "isConnected": status == .connected,
            "serverAddress": manager.protocolConfiguration?.serverAddress ?? ""
        ]
    }
    
    // Connect to VPN with server object and credentials from Remote Config
    func connectVPN(serverAddress: String, username: String, password: String, sharedSecret: String, countryCode: String, countryName: String, completion: @escaping (Bool, String?) -> Void) {
        guard let manager = vpnManager else {
            completion(false, "VPN Manager not initialized")
            return
        }
        
        print("📡 Connecting to VPN server: \(serverAddress) (\(countryName))")
        print("🔐 Using credentials from Remote Config")
        
        manager.loadFromPreferences { [weak self] error in
            if let error = error {
                completion(false, "Failed to load preferences: \(error.localizedDescription)")
                return
            }
            
            self?.configureVPN(manager: manager, serverAddress: serverAddress, username: username, password: password, sharedSecret: sharedSecret, countryCode: countryCode, countryName: countryName) { success, error in
                if success {
                    do {
                        try manager.connection.startVPNTunnel()
                        completion(true, nil)
                    } catch {
                        completion(false, "Failed to start VPN: \(error.localizedDescription)")
                    }
                } else {
                    completion(false, error)
                }
            }
        }
    }
    
    func disconnectVPN(completion: @escaping (Bool, String?) -> Void) {
        guard let manager = vpnManager else {
            completion(false, "VPN Manager not initialized")
            return
        }
        
        manager.connection.stopVPNTunnel()
        completion(true, nil)
    }
    
    private func configureVPN(manager: NEVPNManager, serverAddress: String, username: String, password: String, sharedSecret: String, countryCode: String, countryName: String, completion: @escaping (Bool, String?) -> Void) {
        // Use credentials from Remote Config (passed from Flutter)
        // Save credentials to keychain for secure storage
        saveCredentialsToKeychain(username: username, password: password, sharedSecret: sharedSecret)
        
        let ipSecConfig = NEVPNProtocolIPSec()
        ipSecConfig.serverAddress = serverAddress
        ipSecConfig.username = username // Use credentials from Remote Config
        
        // Convert password to data and save as password reference
        if let passwordRef = createPasswordReference(username: username, password: password) {
            ipSecConfig.passwordReference = passwordRef
        } else {
            completion(false, "Error creating password reference")
            return
        }
        
        ipSecConfig.authenticationMethod = .sharedSecret
        if let sharedSecretRef = createSharedSecretReference(secret: sharedSecret) {
            ipSecConfig.sharedSecretReference = sharedSecretRef
        } else {
            completion(false, "Error creating shared secret reference")
            return
        }
        
        // Match the config from working backup (including mobileconfig settings)
        ipSecConfig.localIdentifier = ""
        ipSecConfig.remoteIdentifier = serverAddress
        ipSecConfig.useExtendedAuthentication = true  // This is equivalent to XAuthEnabled in mobileconfig
        
        manager.protocolConfiguration = ipSecConfig
        manager.isEnabled = true
        manager.localizedDescription = "Rock VPN"
        
        // Save the configuration
        manager.saveToPreferences { error in
            if let error = error {
                completion(false, "Failed to save VPN configuration: \(error.localizedDescription)")
            } else {
                print("✅ VPN configured for \(countryName) (\(serverAddress))")
                completion(true, nil)
            }
        }
    }
    
    private func saveCredentialsToKeychain(username: String, password: String, sharedSecret: String) {
        saveToKeychain(key: kKeychainVPNUsernameKey, value: username)
        saveToKeychain(key: kKeychainVPNPasswordKey, value: password)
        saveToKeychain(key: kKeychainVPNSharedSecretKey, value: sharedSecret)
    }
    
    // MARK: - Keychain Operations
    
    private func saveToKeychain(key: String, value: String) {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Failed to save to keychain: \(status)")
        }
    }
    
    private func getKeychainValue(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        
        return nil
    }
    
    private func getKeychainPasswordReference(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnPersistentRef as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let data = result as? Data {
            return data
        }
        
        return nil
    }
    
    // Check VPN permission (iOS checks if VPN configuration can be loaded)
    func checkVPNPermission(completion: @escaping (Bool) -> Void) {
        guard let manager = vpnManager else {
            completion(false)
            return
        }
        
        manager.loadFromPreferences { error in
            if let error = error {
                print("❌ VPN permission check failed: \(error.localizedDescription)")
                completion(false)
            } else {
                print("✅ VPN permission granted")
                completion(true)
            }
        }
    }
    
    // Request VPN permission (iOS requests when saving VPN configuration)
    func requestVPNPermission(completion: @escaping (Bool) -> Void) {
        guard let manager = vpnManager else {
            completion(false)
            return
        }
        
        manager.loadFromPreferences { error in
            if let error = error {
                print("❌ VPN permission request failed: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            // Try to save a basic configuration to request permission
            manager.localizedDescription = "VPN Permission Request"
            manager.isEnabled = false // Don't enable yet, just request permission
            
            manager.saveToPreferences { error in
                if let error = error {
                    print("❌ VPN permission denied: \(error.localizedDescription)")
                    completion(false)
                } else {
                    print("✅ VPN permission granted")
                    completion(true)
                }
            }
        }
    }
    
    // Create password reference exactly like backup iOS app
    private func createPasswordReference(username: String, password: String) -> Data? {
        let passwordData = password.data(using: .utf8)!
        
        // Create a keychain query
        let keychainQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "VPNService",
            kSecAttrAccount as String: username,
            kSecValueData as String: passwordData,
            kSecReturnPersistentRef as String: true
        ]
        
        // Remove any existing keychain item
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "VPNService",
            kSecAttrAccount as String: username
        ] as CFDictionary)
        
        // Add the new keychain item
        var result: CFTypeRef?
        let status = SecItemAdd(keychainQuery as CFDictionary, &result)
        
        if status == errSecSuccess {
            return result as? Data
        } else {
            print("❌ Error creating password reference: \(status)")
            return nil
        }
    }
    
    // Create shared secret reference exactly like backup iOS app
    private func createSharedSecretReference(secret: String) -> Data? {
        let secretData = secret.data(using: .utf8)!
        
        // Create a keychain query
        let keychainQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "VPNSharedSecret",
            kSecAttrAccount as String: "SharedSecret",
            kSecValueData as String: secretData,
            kSecReturnPersistentRef as String: true
        ]
        
        // Remove any existing keychain item
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "VPNSharedSecret",
            kSecAttrAccount as String: "SharedSecret"
        ] as CFDictionary)
        
        // Add the new keychain item
        var result: CFTypeRef?
        let status = SecItemAdd(keychainQuery as CFDictionary, &result)
        
        if status == errSecSuccess {
            return result as? Data
        } else {
            print("❌ Error creating shared secret reference: \(status)")
            return nil
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let vpnStatusChanged = Notification.Name("vpnStatusChanged")
}



