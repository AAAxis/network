import SwiftUI
import UniformTypeIdentifiers
import MobileCoreServices
import UIKit
import NetworkExtension
import Security

@main
struct NetworkApp: App {
    var body: some Scene {
        WindowGroup {
            NetworkView()
        }
    }
}

struct NetworkView: View {
    @State private var isLoading = false
    @State private var statusMessage = ""
    @State private var isConnected = false
    @State private var showingCredentialAlert = false
    @State private var debugInfo: String = ""
    
    // Set the default values as provided in vpn.env
    private let defaultServerAddress = "93.127.130.43"
    private let defaultUsername = "dima"
    private let defaultPassword = "rabbit"
    private let defaultSharedSecret = "ipsec-vpn-key"
    
    // Constants for Keychain identifiers
    private let kKeychainVPNUsernameKey = "com.rockvpn.username"
    private let kKeychainVPNPasswordKey = "com.rockvpn.password"
    private let kKeychainVPNSharedSecretKey = "com.rockvpn.sharedsecret"
    private let kKeychainVPNServerAddressKey = "com.rockvpn.serveraddress"
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(isConnected ? .green : .blue)
            
            Text("Welcome to Rock VPN!")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Secure your connection and protect your privacy")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            if isLoading {
                ProgressView()
                    .padding()
                Text("Processing...")
                    .font(.caption)
                    .foregroundColor(.gray)
            } else {
                Button(action: isConnected ? disconnectVPN : setupAndConnectVPN) {
                    HStack {
                        Image(systemName: isConnected ? "wifi.slash" : "wifi")
                        Text(isConnected ? "Disconnect" : "Connect to VPN")
                    }
                    .padding()
                    .background(isConnected ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            
            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.footnote)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
            
            if !debugInfo.isEmpty {
                ScrollView {
                    Text(debugInfo)
                        .font(.system(size: 12, design: .monospaced))
                        .padding()
                }
                .frame(height: 150)
                .background(Color.black.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .onAppear {
            checkVPNStatus()
            saveDefaultCredentials()
        }
    }
    
    private func saveDefaultCredentials() {
        // Store the default credentials in the Keychain
        _ = saveToKeychain(key: kKeychainVPNUsernameKey, data: defaultUsername.data(using: .utf8)!)
        _ = saveToKeychain(key: kKeychainVPNPasswordKey, data: defaultPassword.data(using: .utf8)!)
        _ = saveToKeychain(key: kKeychainVPNSharedSecretKey, data: defaultSharedSecret.data(using: .utf8)!)
        _ = saveToKeychain(key: kKeychainVPNServerAddressKey, data: defaultServerAddress.data(using: .utf8)!)
        
        statusMessage = "VPN credentials configured"
    }
    
    private func checkVPNStatus() {
        let vpnManager = NEVPNManager.shared()
        vpnManager.loadFromPreferences { error in
            if let error = error {
                DispatchQueue.main.async {
                    self.statusMessage = "Error checking VPN status: \(error.localizedDescription)"
                }
                return
            }
            
            DispatchQueue.main.async {
                switch vpnManager.connection.status {
                case .connected:
                    self.isConnected = true
                    self.statusMessage = "VPN is connected"
                case .connecting:
                    self.isLoading = true
                    self.statusMessage = "VPN is connecting..."
                case .disconnecting:
                    self.isLoading = true
                    self.statusMessage = "VPN is disconnecting..."
                case .disconnected, .invalid:
                    self.isConnected = false
                    self.isLoading = false
                    self.statusMessage = "VPN is disconnected"
                @unknown default:
                    self.isConnected = false
                    self.isLoading = false
                    self.statusMessage = "VPN status is unknown"
                }
            }
            
            // Set up observation of status changes
            NotificationCenter.default.addObserver(
                forName: .NEVPNStatusDidChange,
                object: vpnManager.connection,
                queue: OperationQueue.main) { _ in
                    DispatchQueue.main.async {
                        switch vpnManager.connection.status {
                        case .connected:
                            self.isConnected = true
                            self.isLoading = false
                            self.statusMessage = "VPN Connected!"
                        case .connecting:
                            self.isLoading = true
                            self.statusMessage = "VPN is connecting..."
                        case .disconnecting:
                            self.isLoading = true
                            self.statusMessage = "VPN is disconnecting..."
                        case .disconnected, .invalid:
                            self.isConnected = false
                            self.isLoading = false
                            self.statusMessage = "VPN Disconnected"
                        @unknown default:
                            self.isConnected = false
                            self.isLoading = false
                            self.statusMessage = "VPN status is unknown"
                        }
                    }
            }
        }
    }
    
    private func setupAndConnectVPN() {
        isLoading = true
        statusMessage = "Setting up VPN..."
        
        // Get credentials from Keychain
        guard let serverAddressData = loadFromKeychain(key: kKeychainVPNServerAddressKey),
              let serverAddress = String(data: serverAddressData, encoding: .utf8),
              let usernameData = loadFromKeychain(key: kKeychainVPNUsernameKey),
              let username = String(data: usernameData, encoding: .utf8),
              let passwordData = loadFromKeychain(key: kKeychainVPNPasswordKey),
              let password = String(data: passwordData, encoding: .utf8),
              let sharedSecretData = loadFromKeychain(key: kKeychainVPNSharedSecretKey),
              let sharedSecret = String(data: sharedSecretData, encoding: .utf8) else {
            
            DispatchQueue.main.async {
                self.statusMessage = "Error: Missing VPN credentials"
                self.isLoading = false
                self.saveDefaultCredentials()
            }
            return
        }
        
        let vpnManager = NEVPNManager.shared()
        vpnManager.loadFromPreferences { error in
            if let error = error {
                DispatchQueue.main.async {
                    self.statusMessage = "Error loading VPN preferences: \(error.localizedDescription)"
                    self.isLoading = false
                }
                return
            }
            
            // Setup IPSec configuration
            let ipSecConfig = NEVPNProtocolIPSec()
            ipSecConfig.serverAddress = serverAddress
            ipSecConfig.username = username
            
            // Convert password to data and save as password reference
            if let passwordRef = self.createPasswordReference(username: username, password: password) {
                ipSecConfig.passwordReference = passwordRef
            } else {
                DispatchQueue.main.async {
                    self.statusMessage = "Error creating password reference"
                    self.isLoading = false
                }
                return
            }
            
            ipSecConfig.authenticationMethod = .sharedSecret
            if let sharedSecretRef = self.createSharedSecretReference(secret: sharedSecret) {
                ipSecConfig.sharedSecretReference = sharedSecretRef
            } else {
                DispatchQueue.main.async {
                    self.statusMessage = "Error creating shared secret reference"
                    self.isLoading = false
                }
                return
            }
            
            // Match the config in the mobileconfig file
            ipSecConfig.localIdentifier = ""
            ipSecConfig.remoteIdentifier = serverAddress
            ipSecConfig.useExtendedAuthentication = true  // This is equivalent to XAuthEnabled in mobileconfig
            
            vpnManager.protocolConfiguration = ipSecConfig
            vpnManager.isEnabled = true
            vpnManager.localizedDescription = "Rock VPN"
            
            // Save the configuration
            vpnManager.saveToPreferences { error in
                if let error = error {
                    DispatchQueue.main.async {
                        self.statusMessage = "Error saving VPN preferences: \(error.localizedDescription)"
                        self.isLoading = false
                    }
                    return
                }
                
                // Try to connect
                do {
                    try vpnManager.connection.startVPNTunnel()
                    DispatchQueue.main.async {
                        self.statusMessage = "Connecting to VPN..."
                    }
                } catch let error {
                    DispatchQueue.main.async {
                        self.statusMessage = "Failed to start VPN: \(error.localizedDescription)"
                        self.isLoading = false
                    }
                }
            }
        }
    }
    
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
            self.debugInfo = "Error creating password reference: \(status)"
            return nil
        }
    }
    
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
            self.debugInfo = "Error creating shared secret reference: \(status)"
            return nil
        }
    }
    
    private func disconnectVPN() {
        isLoading = true
        statusMessage = "Disconnecting VPN..."
        
        let vpnManager = NEVPNManager.shared()
        vpnManager.connection.stopVPNTunnel()
        // Status will be updated through the notification observer
    }
    
    // MARK: - Keychain Helper Functions
    
    private func saveToKeychain(key: String, data: Data) -> Bool {
        // First delete any existing item
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ] as CFDictionary)
        
        // Now add the new item
        let status = SecItemAdd([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ] as CFDictionary, nil)
        
        return status == errSecSuccess
    }
    
    private func loadFromKeychain(key: String) -> Data? {
        var result: AnyObject?
        let status = SecItemCopyMatching([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ] as CFDictionary, &result)
        
        if status == errSecSuccess {
            return result as? Data
        } else {
            print("\(key): SecItemCopyMatching failed: \(status)")
            return nil
        }
    }
}