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
    
    // VPN Configuration (credentials remain the same)
    private let defaultUsername = "dima"
    private let defaultPassword = "rabbit"
    private let defaultSharedSecret = "ipsec-vpn-key"
    
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
        
        // Notify Flutter about status change
        NotificationCenter.default.post(
            name: .vpnStatusChanged,
            object: nil,
            userInfo: ["status": statusString, "isConnected": status == .connected]
        )
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
    
    // Connect to VPN with server object (matching Flutter implementation)
    func connectVPN(serverAddress: String, countryCode: String, countryName: String, completion: @escaping (Bool, String?) -> Void) {
        guard let manager = vpnManager else {
            completion(false, "VPN Manager not initialized")
            return
        }
        
        print("📡 Connecting to VPN server: \(serverAddress) (\(countryName))")
        
        manager.loadFromPreferences { [weak self] error in
            if let error = error {
                completion(false, "Failed to load preferences: \(error.localizedDescription)")
                return
            }
            
            self?.configureVPN(manager: manager, serverAddress: serverAddress, countryCode: countryCode, countryName: countryName) { success, error in
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
    
    private func configureVPN(manager: NEVPNManager, serverAddress: String, countryCode: String, countryName: String, completion: @escaping (Bool, String?) -> Void) {
        // Use exact configuration from working backup iOS app
        let ipSecConfig = NEVPNProtocolIPSec()
        ipSecConfig.serverAddress = serverAddress
        ipSecConfig.username = defaultUsername // Always use hardcoded credentials like Kotlin
        
        // Convert password to data and save as password reference (like backup)
        if let passwordRef = createPasswordReference(username: defaultUsername, password: defaultPassword) {
            ipSecConfig.passwordReference = passwordRef
        } else {
            completion(false, "Error creating password reference")
            return
        }
        
        ipSecConfig.authenticationMethod = .sharedSecret
        if let sharedSecretRef = createSharedSecretReference(secret: defaultSharedSecret) {
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
    
    private func saveCredentialsToKeychain() {
        saveToKeychain(key: kKeychainVPNUsernameKey, value: defaultUsername)
        saveToKeychain(key: kKeychainVPNPasswordKey, value: defaultPassword)
        saveToKeychain(key: kKeychainVPNSharedSecretKey, value: defaultSharedSecret)
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
