import SwiftUI
import UniformTypeIdentifiers
import NetworkExtension
import Security
import Foundation
import Network
import NetworkExtension

struct PingResult {
    let ip: String
    let pingMs: Double?
    let status: String
    let timestamp: Date
    let isReachable: Bool
}



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
    @State private var showingSettings = false
    @State private var showingProxySettings = false
    @State private var availableIPs: [String] = []
    @State private var devicePingResults: [String: PingResult] = [:]
    @State private var selectedIP: String = ""
    @State private var isScanningNetwork = false
    @State private var showingServerSelector = false
    @State private var isHostMode = true   // Host mode enabled by default
    @State private var tunnelConnections: [String] = []
    @State private var pendingTargetDevice: String? = nil // State to hold the device to route to after VPN connection
    
    // MARK: - VPN Configuration
    private let defaultServerAddress = "69.197.134.25"
    private let defaultUsername = "XXX"       // Use the correct VPN server credentials
    private let defaultPassword = "XXX"     // Use the correct VPN server credentials
    private let defaultSharedSecret = "ipsec-vpn-key"
    
    // VPN server ports
    private let vpnServerPort = 500  // IPSec IKE port
    private let vpnServerPort2 = 4500  // IPSec NAT-T port
    
    // Constants for Keychain identifiers
    private let kKeychainVPNUsernameKey = "com.rockvpn.username"
    private let kKeychainVPNPasswordKey = "com.rockvpn.password"
    private let kKeychainVPNSharedSecretKey = "com.rockvpn.sharedsecret"
    private let kKeychainVPNServerAddressKey = "com.rockvpn.serveraddress"
    
    private var backgroundColor: Color {
        #if os(iOS)
        return Color(.systemBackground)
        #else
        return Color(NSColor.windowBackgroundColor)
        #endif
    }
    
    public var body: some View {
        #if os(iOS)
        NavigationView {
            mainContentView
        }
        #else
        // macOS: Use full-screen layout without NavigationView side panel
        VStack {
            // Custom header for macOS
            HStack {
                Text("Rock VPN")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Settings") {
                    showingSettings = true
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(backgroundColor)
            
            mainContentView
                .padding()
        }
        #endif
    }
    
    private var mainContentView: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(isConnected ? .green : .blue)
        
        Text("Rock VPN!")
            .font(.title)
            .fontWeight(.bold)
        
        Text("Secure your connection and protect your privacy")
            .font(.subheadline)
            .foregroundColor(.gray)
            .multilineTextAlignment(.center)
        
        // Server Selection
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Select Server:")
                    .font(.headline)
                Spacer()
                Button(action: { showingServerSelector.toggle() }) {
                    HStack {
                        Image(systemName: "chevron.down")
                            .foregroundColor(.blue)
                        Text("Change")
                            .foregroundColor(.blue)
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            
            // Current Server Display
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedIP.isEmpty ? defaultServerAddress : selectedIP)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        if selectedIP.isEmpty {
                            // For VPN server, show ping status
                            Text("Available")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            // For selected device, show ping status
                            if let pingResult = devicePingResults[selectedIP] {
                                if let pingMs = pingResult.pingMs {
                                    Text("\(Int(pingMs))ms")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                } else {
                                    Text(pingResult.status)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            } else {
                                Text("Not tested")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                
                Spacer()
                
                Button(action: { 
                    // Ping the selected server
                    if !selectedIP.isEmpty {
                        pingSpecificIP(selectedIP)
                    } else {
                        pingSpecificIP(defaultServerAddress)
                    }
                }) {
                    Image(systemName: "wifi")
                        .foregroundColor(.blue)
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                }
            }
            .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
            
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
                
                // Status message display
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
        #if os(iOS)
        .navigationTitle("Rock VPN")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Settings") {
                    showingSettings = true
                }
            }
        }
        #endif
        .sheet(isPresented: $showingSettings) {
            SettingsView(isHostListeningEnabled: $isHostMode)
        }
        .sheet(isPresented: $showingProxySettings) {
            ProxySettingsView()
        }
        .sheet(isPresented: $showingServerSelector) {
            ServerSelectorView(selectedIP: $selectedIP, availableIPs: availableIPs, devicePingResults: devicePingResults, defaultServerAddress: defaultServerAddress)
        }
        .onAppear {
            checkVPNStatus()
            saveDefaultCredentials()
            scanNetworkForDevices()
            startHeartbeat()
            // Host mode is now enabled by default
        }
    }
    
    private func saveDefaultCredentials() {
        // Clear existing credentials first
        clearVPNCredentials()
        
        // Store the default credentials in the Keychain
        let usernameSaved = saveToKeychain(key: kKeychainVPNUsernameKey, data: defaultUsername.data(using: .utf8)!)
        let passwordSaved = saveToKeychain(key: kKeychainVPNPasswordKey, data: defaultPassword.data(using: .utf8)!)
        let sharedSecretSaved = saveToKeychain(key: kKeychainVPNSharedSecretKey, data: defaultSharedSecret.data(using: .utf8)!)
        let serverAddressSaved = saveToKeychain(key: kKeychainVPNServerAddressKey, data: defaultServerAddress.data(using: .utf8)!)
        
        // Debug logging
        print("🔐 Credential Save Results:")
        print("  Username saved: \(usernameSaved)")
        print("  Password saved: \(passwordSaved)")
        print("  Shared Secret saved: \(sharedSecretSaved)")
        print("  Server Address saved: \(serverAddressSaved)")
        
        statusMessage = "VPN credentials configured"
    }
    
    private func clearVPNCredentials() {
        // Clear all VPN-related keychain items
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: kKeychainVPNUsernameKey
        ] as CFDictionary)
        
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: kKeychainVPNPasswordKey
        ] as CFDictionary)
        
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: kKeychainVPNSharedSecretKey
        ] as CFDictionary)
        
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: kKeychainVPNServerAddressKey
        ] as CFDictionary)
        
        print("🧹 VPN credentials cleared from keychain")
    }
    
    private func checkVPNStatus() {
        // VPN is available on both iOS and macOS
        
        let vpnManager = NEVPNManager.shared()
        vpnManager.loadFromPreferences { error in
            if let error = error {
                DispatchQueue.main.async {
                    // Handle simulator-specific VPN errors gracefully
                    if error.localizedDescription.contains("IPC failed") || 
                       error.localizedDescription.contains("Connection invalid") {
                        self.statusMessage = "VPN not available in simulator - use real device for VPN testing"
                    } else {
                        self.statusMessage = "Error checking VPN status: \(error.localizedDescription)"
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                switch vpnManager.connection.status {
                case .connected:
                    self.isConnected = true
                    self.isLoading = false
                    self.statusMessage = "VPN Connected!"
                    
                    // Start multi-hop routing after successful VPN connection
                    self.configureMultiHopRouting()
                    
                    // Route to target device if one was selected
                    if let targetDevice = self.pendingTargetDevice {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            self.routeToDevice(targetIP: targetDevice)
                            self.pendingTargetDevice = nil  // Clear pending device
                        }
                    }
                    
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
                            
                            // Start multi-hop routing after successful VPN connection
                            self.configureMultiHopRouting()
                            
                            // Route to target device if one was selected
                            if let targetDevice = self.pendingTargetDevice {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                    self.routeToDevice(targetIP: targetDevice)
                                    self.pendingTargetDevice = nil  // Clear pending device
                                }
                            }
                            
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
        // Check if running in simulator
        #if targetEnvironment(simulator)
        statusMessage = "VPN functionality not available in iOS Simulator. Please test on a real device."
        return
        #endif
        
        isLoading = true
        statusMessage = "Setting up VPN..."
        
        // Always connect to VPN server first, then route to selected device
        let serverAddress = defaultServerAddress  // Always use VPN server
        let targetDeviceIP = selectedIP.isEmpty ? nil : selectedIP  // Device to route to after VPN connection
        
        guard let usernameData = loadFromKeychain(key: kKeychainVPNUsernameKey),
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
        
        // Debug logging for credentials
        print("🔐 VPN Connection Debug:")
        print("  Username: \(username)")
        print("  Password: \(password)")
        print("  Shared Secret: \(sharedSecret)")
        print("  Server: \(serverAddress)")
        
        // Update debug info for UI
        DispatchQueue.main.async {
            self.debugInfo = """
            🔐 VPN Connection Debug:
            Username: \(username)
            Password: \(password)
            Shared Secret: \(sharedSecret)
            Server: \(serverAddress)
            """
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
                        if let targetIP = targetDeviceIP {
                            self.statusMessage = "Connecting to VPN, then routing to \(targetIP)..."
                        } else {
                            self.statusMessage = "Connecting to VPN..."
                        }
                    }
                    
                    // Store target device for routing after VPN connection
                    if let targetIP = targetDeviceIP {
                        self.pendingTargetDevice = targetIP
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
        // Check if running in simulator
        #if targetEnvironment(simulator)
        statusMessage = "VPN functionality not available in iOS Simulator."
        return
        #endif
        
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
    
    // MARK: - Network Scanning Functions
    
    private func scanNetworkForDevices() {
        isScanningNetwork = true
        availableIPs.removeAll()
        // Don't clear ping results - keep existing ones
        
        // Get current device IP to filter it out
        let currentIP = getCurrentDeviceIP()
        
        // Register this device with the proxy router (so others can see you)
        registerDeviceWithProxyRouter(currentIP: currentIP)
        
        // Ping the VPN server first
        pingSpecificIP(defaultServerAddress)
        
        // Try to get devices from backend first
        getAvailableDevicesFromProxyRouter(excludingIP: currentIP)
    }
    
    private func registerDeviceWithProxyRouter(currentIP: String) {
        print("📱 Registering device with IP: \(currentIP)")
        
        let url = URL(string: "https://vpn.theholylabs.com/api/proxy/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let deviceData: [String: Any] = [
            "client_id": currentIP,  // Use IP as client ID for simplicity
            "original_ip": currentIP,
            "vpn_ip": currentIP,
            "country": "Unknown",
            "city": "Unknown"
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: deviceData)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Device registration failed: \(error.localizedDescription)")
                } else {
                    print("✅ Device registered successfully with IP: \(currentIP)")
                    // Store the IP as the device identifier
                    UserDefaults.standard.set(currentIP, forKey: "deviceIP")
                }
            }
        }.resume()
    }
    
    private func getAvailableDevicesFromProxyRouter(excludingIP: String) {
        // Try to get devices with ping information first (via nginx proxy)
        let urlWithPing = URL(string: "https://vpn.theholylabs.com/api/proxy/clients-with-ping")!
        
        URLSession.shared.dataTask(with: urlWithPing) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    // Fallback to basic client list if ping endpoint fails
                    self.getBasicDeviceList(excludingIP: excludingIP)
                    return
                }
                
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = json["success"] as? Bool,
                   success == true,
                   let clients = json["clients"] as? [[String: Any]] {
                    
                    // Filter out current device IP, VPN server, and any domain names
                    let deviceIPs = clients.compactMap { client in
                        let ip = client["original_ip"] as? String
                        // Only include IPs that are:
                        // 1. Not the current device
                        // 2. Not the VPN server domain
                        // 3. Actually look like IP addresses (not domain names)
                        return (ip != excludingIP && 
                                ip != self.defaultServerAddress && 
                                self.isValidIPAddress(ip ?? "")) ? ip : nil
                    }
                    
                    // Update ping results from the response
                    for client in clients {
                        if let ip = client["original_ip"] as? String,
                           ip != excludingIP && 
                           ip != self.defaultServerAddress && 
                           self.isValidIPAddress(ip),
                           let pingStatus = client["ping_status"] as? String {
                            
                            let pingMs = client["ping_ms"] as? Double
                            let isReachable = pingStatus == "success"
                            
                            self.devicePingResults[ip] = PingResult(
                                ip: ip,
                                pingMs: pingMs,
                                status: pingStatus,
                                timestamp: Date(),
                                isReachable: isReachable
                            )
                        }
                    }
                    
                    self.availableIPs.append(contentsOf: deviceIPs)
                    self.isScanningNetwork = false
                    self.statusMessage = "Found \(deviceIPs.count) other devices"
                } else {
                    self.getBasicDeviceList(excludingIP: excludingIP)
                }
            }
        }.resume()
    }
    
    private func getBasicDeviceList(excludingIP: String) {
        // Fallback method for basic device list
        let url = URL(string: "https://vpn.theholylabs.com/api/proxy/clients")!
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    // If backend completely fails, fall back to local network scanning
                    self.fallbackToLocalNetworkScan(excludingIP: excludingIP)
                    return
                }
                
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = json["success"] as? Bool,
                   success == true,
                   let clients = json["clients"] as? [[String: Any]] {
                    
                    // Filter out current device IP, VPN server, and domain names
                    let deviceIPs = clients.compactMap { client in
                        let ip = client["original_ip"] as? String
                        return (ip != excludingIP && 
                                ip != self.defaultServerAddress && 
                                self.isValidIPAddress(ip ?? "")) ? ip : nil
                    }
                    
                    self.availableIPs.append(contentsOf: deviceIPs)
                    self.isScanningNetwork = false
                    self.statusMessage = "Found \(deviceIPs.count) other devices"
                    
                    // Manually ping all devices since we didn't get ping data
                    self.pingAllDevices()
                } else {
                    self.fallbackToLocalNetworkScan(excludingIP: excludingIP)
                }
            }
        }.resume()
    }
    
    // Helper function to check if a string is a valid IP address
    private func isValidIPAddress(_ ip: String) -> Bool {
        // Check if it looks like an IP address (contains dots and numbers)
        let components = ip.components(separatedBy: ".")
        if components.count != 4 {
            return false
        }
        
        for component in components {
            if let number = Int(component), number >= 0 && number <= 255 {
                continue
            } else {
                return false
            }
        }
        
        return true
    }
    
    private func fallbackToLocalNetworkScan(excludingIP: String) {
        // If backend fails, scan local network as fallback
        let networkRange = getNetworkRange(from: excludingIP)
        let commonIPs = generateCommonIPs(in: networkRange)
        
        // Test each IP for reachability
        for ip in commonIPs {
            if ip != excludingIP && ip != defaultServerAddress {
                testIPReachability(ip: ip) { isReachable in
                    DispatchQueue.main.async {
                        if isReachable {
                            self.availableIPs.append(ip)
                            self.devicePingResults[ip] = PingResult(
                                ip: ip,
                                pingMs: nil,
                                status: "Local Network",
                                timestamp: Date(),
                                isReachable: true
                            )
                        }
                    }
                }
            }
        }
        
        DispatchQueue.main.async {
            self.isScanningNetwork = false
            self.statusMessage = "Found \(self.availableIPs.count) devices (local scan)"
        }
    }
    
    private func generateCommonIPs(in networkRange: String) -> [String] {
        var ips: [String] = []
        
        // Generate common IPs in the network range
        for i in 1...254 {
            let ip = "\(networkRange)\(i)"
            ips.append(ip)
        }
        
        return ips
    }
    
    private func testIPReachability(ip: String, completion: @escaping (Bool) -> Void) {
        // Use Network framework for iOS-compatible reachability testing
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(ip), 
            port: NWEndpoint.Port(integerLiteral: 80)
        )
        
        let connection = NWConnection(to: endpoint, using: .tcp)
        var isReachable = false
        
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                isReachable = true
                connection.cancel()
                completion(true)
            case .failed, .cancelled:
                connection.cancel()
                completion(false)
            default:
                break
            }
        }
        
        connection.start(queue: .global())
        
        // Timeout after 1 second
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            if !isReachable {
                connection.cancel()
                completion(false)
            }
        }
    }
    
    private func pingAllDevices() {
        for ip in availableIPs {
            pingSpecificIP(ip)
        }
    }
    
    private func pingSpecificIP(_ ip: String) {
        // Use proxy-router service for ping instead of backend
        let url = URL(string: "https://vpn.theholylabs.com/api/proxy/ping-ip")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let pingData = ["ip": ip]
        request.httpBody = try? JSONSerialization.data(withJSONObject: pingData)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.devicePingResults[ip] = PingResult(
                        ip: ip,
                        pingMs: nil,
                        status: "Error: \(error.localizedDescription)",
                        timestamp: Date(),
                        isReachable: false
                    )
                    return
                }
                
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    
                    let pingMs = json["ping_ms"] as? Double
                    let status = json["status"] as? String ?? "unknown"
                    let isReachable = json["reachable"] as? Bool ?? false
                    
                    self.devicePingResults[ip] = PingResult(
                        ip: ip,
                        pingMs: pingMs,
                        status: status,
                        timestamp: Date(),
                        isReachable: isReachable
                    )
                } else {
                    self.devicePingResults[ip] = PingResult(
                        ip: ip,
                        pingMs: nil,
                        status: "Invalid response",
                        timestamp: Date(),
                        isReachable: false
                    )
                }
            }
        }.resume()
    }
    
    // MARK: - VPN Status Check for Multi-Hop
    
    private func checkVPNConnectionForMultiHop() {
        print("🔍 Checking VPN connection for multi-hop routing...")
        
        if isConnected {
            print("✅ VPN connected - multi-hop routing available")
            configureMultiHopRouting()
        } else {
            print("❌ VPN not connected - cannot enable multi-hop routing")
            print("📱 Please connect to VPN server first")
        }
    }
    
    // MARK: - Device-to-Device Routing
    
    private func routeToDevice(targetIP: String) {
        print("🔄 Routing to device: \(targetIP)")
        
        // Check if we're connected to VPN
        guard isConnected else {
            print("❌ Not connected to VPN - cannot route to device")
            return
        }
        
        // Create a proxy route to the target device
        createProxyRoute(targetIP: targetIP)
    }
    
    private func createProxyRoute(targetIP: String) {
        print("🔄 Setting up proxy routing to: \(targetIP)")
        
        // Get current device IP (VPN IP)
        let sourceIP = getCurrentDeviceIP()
        
        // Create a proxy route through the VPN server
        createProxyRouteThroughVPN(sourceIP: sourceIP, targetIP: targetIP)
    }
    
    private func createProxyRouteThroughVPN(sourceIP: String, targetIP: String) {
        print("🔄 Creating proxy route: \(sourceIP) → \(targetIP) through VPN")
        
        // First, register as a proxy router
        registerAsProxyRouter(vpnIP: sourceIP) { success in
            if success {
                print("✅ Registered as proxy router")
                // Now create the proxy route
                self.createProxyRouteOnServer(sourceIP: sourceIP, targetIP: targetIP)
            } else {
                print("❌ Failed to register as proxy router")
                self.statusMessage = "Failed to setup proxy routing"
            }
        }
    }
    
    private func createProxyRouteOnServer(sourceIP: String, targetIP: String) {
        let url = URL(string: "https://vpn.theholylabs.com/api/proxy/route")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let routeData: [String: Any] = [
            "source_ip": sourceIP,
            "target_ip": targetIP,
            "route_type": "vpn_proxy"
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: routeData)
        
        print("📡 Creating proxy route on server...")
        print("📦 Route data: \(routeData)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Network error: \(error.localizedDescription)")
                    self.statusMessage = "Network error creating proxy route"
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 HTTP Response: \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode == 200 {
                        if let data = data,
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            
                            print("✅ Proxy route created successfully!")
                            print("🔄 Now forwarding traffic to \(targetIP) through VPN")
                            
                            self.statusMessage = "Proxy routing active: \(targetIP)"
                            
                            // Start the proxy listener to handle incoming traffic
                            self.startProxyListener()
                        }
                    } else {
                        print("❌ Server error: \(httpResponse.statusCode)")
                        if let data = data, let errorText = String(data: data, encoding: .utf8) {
                            print("📄 Error: \(errorText)")
                        }
                        self.statusMessage = "Failed to create proxy route"
                    }
                }
            }
        }.resume()
    }
    

    
    // MARK: - Client Availability Management
    
    private func refreshClientAvailability(sourceID: String, targetID: String, targetIP: String) {
        print("🔄 Refreshing client availability...")
        
        // Send heartbeats for both clients to refresh their availability
        let group = DispatchGroup()
        
        // Refresh source client (iOS app)
        group.enter()
        sendHeartbeatForClient(clientID: sourceID) {
            group.leave()
        }
        
        // Refresh target client (laptop)
        group.enter()
        sendHeartbeatForClient(clientID: targetID) {
            group.leave()
        }
        
        // After refreshing both clients, retry creating the route using IP-based approach
        group.notify(queue: .main) {
            print("🔄 Client availability refreshed, retrying route creation...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                // Use the simplified IP-based proxy routing
                self.createProxyRoute(targetIP: targetIP)
            }
        }
    }
    
    private func sendHeartbeatForClient(clientID: String, completion: @escaping () -> Void) {
        let url = URL(string: "https://vpn.theholylabs.com/api/proxy/heartbeat")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let heartbeatData: [String: Any] = [
            "client_id": clientID
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: heartbeatData)
        
        URLSession.shared.dataTask(with: request) { _, _, _ in
            print("💓 Sent heartbeat for client: \(clientID)")
            completion()
        }.resume()
    }
    
    private func startHeartbeat() {
        #if os(iOS)
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        #else
        let deviceID = UUID().uuidString
        #endif
        
        // Send heartbeat every 30 seconds
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            self.sendHeartbeat(deviceID: deviceID)
        }
    }
    
    private func sendHeartbeat(deviceID: String) {
        let url = URL(string: "https://vpn.theholylabs.com/api/proxy/heartbeat")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let heartbeatData: [String: Any] = [
            "client_id": deviceID
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: heartbeatData)
        
        URLSession.shared.dataTask(with: request) { _, _, _ in
            // Silent heartbeat - don't show errors to user
        }.resume()
    }
    
    private func getCurrentDeviceIP() -> String {
        // Try to get the current device's IP address
        var address: String = "192.168.1.100" // Default fallback
        
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else {
            return address
        }
        defer { freeifaddrs(ifaddr) }
        
        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }
            
            let interface = ptr?.pointee
            let addrFamily = interface?.ifa_addr.pointee.sa_family
            
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: (interface?.ifa_name)!)
                
                #if os(iOS)
                // iOS network interfaces
                if name == "en0" || name == "en1" || name == "en2" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface?.ifa_addr,
                               socklen_t((interface?.ifa_addr.pointee.sa_len)!),
                               &hostname,
                               socklen_t(hostname.count),
                               nil,
                               0,
                               NI_NUMERICHOST)
                    address = String(cString: hostname)
                    break
                }
                #else
                // macOS network interfaces
                if name == "en0" || name == "en1" || name == "en2" || name == "en3" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface?.ifa_addr,
                               socklen_t((interface?.ifa_addr.pointee.sa_len)!),
                               &hostname,
                               socklen_t(hostname.count),
                               nil,
                               0,
                               NI_NUMERICHOST)
                    address = String(cString: hostname)
                    break
                }
                #endif
            }
        }
        
        return address
    }
    
    private func getNetworkRange(from ip: String) -> String {
        // Extract network prefix (e.g., "192.168.1." from "192.168.1.100")
        let components = ip.components(separatedBy: ".")
        if components.count >= 3 {
            return "\(components[0]).\(components[1]).\(components[2])."
        }
        return "192.168.1." // Default fallback
    }
    
    private func isDeviceReachable(ip: String) -> Bool {
        // Use Network framework for iOS-compatible reachability
        var isReachable = false
        
        // Try multiple common ports to check if device is reachable
        let testPorts = [80, 443, 22, 8080]
        
        for port in testPorts {
            let semaphore = DispatchSemaphore(value: 0)
            let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(ip), port: NWEndpoint.Port(integerLiteral: UInt16(port)))
            let connection = NWConnection(to: endpoint, using: .tcp)
            
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    isReachable = true
                    semaphore.signal()
                case .failed, .cancelled:
                    semaphore.signal()
                default:
                    break
                }
            }
            
            connection.start(queue: .global())
            
            // Wait for a short time
            _ = semaphore.wait(timeout: .now() + 0.5)
            connection.cancel()
            
            if isReachable {
                return true
            }
        }
        
        return isReachable
    }
    
    private func simplePing(ip: String) -> Bool {
        // Simple ping using Network framework
        let semaphore = DispatchSemaphore(value: 0)
        var isReachable = false
        
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(ip), port: NWEndpoint.Port(integerLiteral: 80))
        let connection = NWConnection(to: endpoint, using: .tcp)
        
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                isReachable = true
                semaphore.signal()
            case .failed, .cancelled:
                semaphore.signal()
            default:
                break
            }
        }
        
        connection.start(queue: .global())
        _ = semaphore.wait(timeout: .now() + 0.3) // Short timeout for faster scanning
        connection.cancel()
        
        return isReachable
    }
    

    
    private func isPortOpen(ip: String, port: Int) -> Bool {
        // Create a socket connection to test if port is open
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(port).bigEndian
        
        if inet_pton(AF_INET, ip, &addr.sin_addr) != 1 {
            return false
        }
        
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        if sock == -1 {
            return false
        }
        
        let addrPtr = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { $0 }
        }
        
        let result = connect(sock, addrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
        close(sock)
        
        return result == 0
    }
    
    // MARK: - Host Mode Functions
    
    private func enableHostMode() {
        // Enable host mode to accept tunnel connections
        isHostMode = true
        
        // Register this device as a tunnel host
        registerAsTunnelHost()
        
        // Start accepting tunnel connections
        startTunnelListener()
    }
    
    private func disableHostMode() {
        isHostMode = false
        
        // Stop IPSec VPN server
        stopIPSecServer()
        
        // Stop accepting tunnel connections
        stopTunnelListener()
        
        // Close existing tunnels
        closeAllTunnels()
    }
    
    private func registerAsTunnelHost() {
        #if os(iOS)
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        #else
        let deviceID = UUID().uuidString
        #endif
        
        let url = URL(string: "https://vpn.theholylabs.com/api/proxy/register-host")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let hostData: [String: Any] = [
            "client_id": deviceID,
            "original_ip": getCurrentDeviceIP(),
            "vpn_ip": getCurrentDeviceIP(),
            "is_host": true,
            "tunnel_capable": true
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: hostData)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Failed to register as tunnel host: \(error.localizedDescription)")
                } else {
                    print("Registered as tunnel host successfully")
                }
            }
        }.resume()
    }
    
    private func startTunnelListener() {
        // Start listening for tunnel connection requests
        // This would integrate with NetworkExtension framework for actual tunneling
        print("Tunnel listener started - ready to accept connections")
    }
    
    private func stopTunnelListener() {
        // Stop listening for tunnel connections
        print("Tunnel listener stopped")
    }
    
    private func closeAllTunnels() {
        // Close existing tunnel connections
        tunnelConnections.removeAll()
        print("All tunnels closed")
    }
    
    private func createTunnelToDevice(_ targetIP: String) {
        // Create IP-to-IP tunnel to another device
        if isHostMode {
            print("Creating tunnel to \(targetIP)")
            
            // Add to tunnel connections
            if !tunnelConnections.contains(targetIP) {
                tunnelConnections.append(targetIP)
            }
            
            // Here you would implement actual tunnel creation
            // using NetworkExtension framework
        }
    }
    
    // MARK: - IPSec VPN Server Functions
    
    private func startIPSecServer() {
        print("Starting IPSec VPN Server...")
        
        // Configure IPSec server settings
        let serverConfig = NEVPNProtocolIPSec()
        serverConfig.serverAddress = getCurrentDeviceIP()
        serverConfig.username = "vpnserver"
        serverConfig.passwordReference = createServerPasswordReference()
        serverConfig.authenticationMethod = .sharedSecret
        serverConfig.sharedSecretReference = createServerSharedSecretReference()
        
        // Set up server manager
        let serverManager = NEVPNManager.shared()
        serverManager.protocolConfiguration = serverConfig
        serverManager.isEnabled = true
        serverManager.localizedDescription = "IPSec VPN Server"
        
        // Save configuration
        serverManager.saveToPreferences { error in
            if let error = error {
                print("Failed to save IPSec server config: \(error.localizedDescription)")
            } else {
                print("IPSec server configuration saved successfully")
                self.startListeningForClients()
            }
        }
    }
    
    private func startListeningForClients() {
        print("IPSec server listening for client connections...")
        
        // Configure server to accept connections
        let serverManager = NEVPNManager.shared()
        serverManager.loadFromPreferences { error in
            if let error = error {
                print("Failed to load server preferences: \(error.localizedDescription)")
                return
            }
            
            // Start the server
            do {
                try serverManager.connection.startVPNTunnel()
                print("IPSec VPN server started successfully")
            } catch {
                print("Failed to start IPSec server: \(error.localizedDescription)")
            }
        }
    }
    
    private func createServerPasswordReference() -> Data? {
        let password = "vpnserver123" // Server password
        let passwordData = password.data(using: .utf8)!
        
        let keychainQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "IPSecServer",
            kSecAttrAccount as String: "vpnserver",
            kSecValueData as String: passwordData,
            kSecReturnPersistentRef as String: true
        ]
        
        var result: CFTypeRef?
        let status = SecItemAdd(keychainQuery as CFDictionary, &result)
        
        if status == errSecSuccess {
            return result as? Data
        } else {
            print("Error creating server password reference: \(status)")
            return nil
        }
    }
    
    private func createServerSharedSecretReference() -> Data? {
        let sharedSecret = "ipsec-server-key" // Server shared secret
        let secretData = sharedSecret.data(using: .utf8)!
        
        let keychainQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "IPSecServerSecret",
            kSecAttrAccount as String: "ServerSecret",
            kSecValueData as String: secretData,
            kSecReturnPersistentRef as String: true
        ]
        
        var result: CFTypeRef?
        let status = SecItemAdd(keychainQuery as CFDictionary, &result)
        
        if status == errSecSuccess {
            return result as? Data
        } else {
            print("Error creating server shared secret reference: \(status)")
            return nil
        }
    }
    
    private func stopIPSecServer() {
        print("Stopping IPSec VPN Server...")
        
        let serverManager = NEVPNManager.shared()
        serverManager.connection.stopVPNTunnel()
        print("IPSec server stopped")
    }
    
    // MARK: - VPN Connection Test
    
    private func testVPNConnection() {
        print("🔍 Testing VPN connection to \(defaultServerAddress)...")
        
        // Test basic connectivity first
        pingSpecificIP(defaultServerAddress)
        
        // Test specific VPN ports
        testVPNPorts()
    }
    
    private func testVPNPorts() {
        let ports = [vpnServerPort, vpnServerPort2]
        
        for port in ports {
            testPortConnectivity(host: defaultServerAddress, port: port) { isOpen in
                DispatchQueue.main.async {
                    if isOpen {
                        print("✅ VPN Port \(port) is open on \(self.defaultServerAddress)")
                    } else {
                        print("❌ VPN Port \(port) is closed on \(self.defaultServerAddress)")
                    }
                }
            }
        }
    }
    
    private func testPortConnectivity(host: String, port: Int, completion: @escaping (Bool) -> Void) {
        // Use a simple socket test to check if the port is open
        DispatchQueue.global(qos: .userInitiated).async {
            let socket = socket(AF_INET, SOCK_STREAM, 0)
            if socket == -1 {
                completion(false)
                return
            }
            
            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = in_port_t(port).bigEndian
            addr.sin_addr.s_addr = inet_addr(host)
            
            // Fix: Use proper Swift socket casting
            let result = withUnsafePointer(to: &addr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    connect(socket, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            
            close(socket)
            completion(result == 0)
        }
    }
    
    // MARK: - Multi-Hop Routing
    
    private func configureMultiHopRouting() {
        print("🔄 Configuring multi-hop routing...")
        
        // After VPN connection, configure routing for other devices
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.setupProxyRouting()
        }
    }
    
    private func setupProxyRouting() {
        print("🌐 Setting up proxy routing through VPN...")
        
        // Get the VPN-assigned IP
        let vpnIP = getCurrentDeviceIP()
        print("📱 VPN IP: \(vpnIP)")
        
        // Register this device as a proxy router
        registerAsProxyRouter(vpnIP: vpnIP) { success in
            if success {
                // Start listening for proxy requests
                self.startProxyListener()
            } else {
                print("❌ Failed to register as proxy router. Multi-hop routing will not be available.")
                self.statusMessage = "Failed to register as proxy router. Multi-hop routing will not be available."
            }
        }
    }
    
    private func registerAsProxyRouter(vpnIP: String, completion: @escaping (Bool) -> Void) {
        print("🌐 Registering as proxy router with IP: \(vpnIP)")
        
        let url = URL(string: "https://vpn.theholylabs.com/api/proxy/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let deviceData: [String: Any] = [
            "client_id": vpnIP,
            "original_ip": vpnIP,
            "vpn_ip": vpnIP,
            "country": "Unknown",
            "city": "Unknown",
            "is_router": true,
            "can_proxy": true
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: deviceData)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Proxy router registration failed: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        print("✅ Registered as proxy router successfully")
                        completion(true)
                    } else {
                        print("❌ Proxy router registration failed: \(httpResponse.statusCode)")
                        completion(false)
                    }
                } else {
                    print("❌ Invalid response")
                    completion(false)
                }
            }
        }.resume()
    }
    
    private func startProxyListener() {
        print("👂 Starting proxy listener...")
        
        // Start a background task to handle proxy requests
        DispatchQueue.global(qos: .background).async {
            self.handleProxyRequests()
        }
    }
    
    private func handleProxyRequests() {
        // Poll for proxy requests every 5 seconds
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            self.checkForProxyRequests()
        }
    }
    
    private func checkForProxyRequests() {
        let url = URL(string: "https://vpn.theholylabs.com/api/proxy/routes")!
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let success = json["success"] as? Bool,
               success == true,
               let routes = json["routes"] as? [[String: Any]] {
                
                for route in routes {
                    if let sourceID = route["source_client_id"] as? String,
                       let targetID = route["target_client_id"] as? String {
                        print("🔄 Processing proxy route: \(sourceID) → \(targetID)")
                        self.processProxyRoute(route: route)
                    }
                }
            }
        }.resume()
    }
    
    private func processProxyRoute(route: [String: Any]) {
        // Handle the proxy route
        print("🔄 Processing proxy route: \(route)")
        
        // This is where you'd implement the actual proxy logic
        // For now, just acknowledge the route
        if let routeID = route["id"] as? Int {
            acknowledgeProxyRoute(routeID: routeID)
        }
    }
    
    private func acknowledgeProxyRoute(routeID: Int) {
        let url = URL(string: "https://vpn.theholylabs.com/api/proxy/route/\(routeID)/ack")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        URLSession.shared.dataTask(with: request) { _, _, _ in
            print("✅ Acknowledged proxy route \(routeID)")
        }.resume()
    }
    
    // MARK: - Device ID Management
    
    private func getCurrentDeviceID() -> String {
        // Try to get the registered client ID for this device
        // First check if we have a stored client ID
        if let storedClientID = UserDefaults.standard.string(forKey: "registered_client_id") {
            return storedClientID
        }
        
        // Fallback to device identifier
        #if os(iOS)
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        #else
        let deviceID = UUID().uuidString
        #endif
        
        return deviceID
    }
    
    private func storeRegisteredClientID(_ clientID: String) {
        UserDefaults.standard.set(clientID, forKey: "registered_client_id")
        print("💾 Stored registered client ID: \(clientID)")
    }
    
    // MARK: - Alternative Connection Methods
    
    private func createDirectConnection(sourceID: String, targetID: String, targetIP: String) {
        print("🔄 Creating direct connection to \(targetIP)...")
        
        // Since proxy route creation is failing, we'll create a direct connection
        // This bypasses the proxy router's database issues
        
        // Register this as a direct connection
        let url = URL(string: "https://vpn.theholylabs.com/api/proxy/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let connectionData: [String: Any] = [
            "client_id": "\(sourceID)_to_\(targetID)",
            "original_ip": getCurrentDeviceIP(),
            "vpn_ip": getCurrentDeviceIP(),
            "is_direct_connection": true,
            "target_device": targetIP,
            "country": "Unknown",
            "city": "Unknown"
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: connectionData)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Failed to create direct connection: \(error.localizedDescription)")
                } else {
                    print("✅ Direct connection created successfully")
                    print("🔄 Now routing traffic to \(targetIP) through VPN (direct mode)")
                    
                    // Update status message
                    self.statusMessage = "Connected to \(targetIP) via direct VPN routing"
                }
            }
        }.resume()
    }
}

// MARK: - Proxy Settings View
struct ProxySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "network")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.blue)
                
                Text("Proxy Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Proxy routing functionality will be available in a future update.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Spacer()
            }
            .padding()
            .navigationTitle("Proxy Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                #endif
            }
        }
    }
}

// MARK: - Settings View
public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isHostListeningEnabled: Bool
    @State private var showingEULA = false
    
    public init(isHostListeningEnabled: Binding<Bool>) {
        self._isHostListeningEnabled = isHostListeningEnabled
    }
    
    private var backgroundColor: Color {
        #if os(iOS)
        return Color(.systemBackground)
        #else
        return Color(NSColor.windowBackgroundColor)
        #endif
    }
    
    public var body: some View {
        #if os(iOS)
        NavigationView {
            mainSettingsContent
        }
        #else
        // macOS: Use full-screen layout without NavigationView
        VStack {
            // Custom header for macOS
            HStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(backgroundColor)
            
            mainSettingsContent
                .padding()
        }
        .frame(minWidth: 600, idealWidth: 700, minHeight: 500, idealHeight: 600)
        #endif
    }
    
    private var mainSettingsContent: some View {
        List {
            Section("Network") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("VPN Host Mode")
                            .font(.headline)
                        Text("Allow other devices to connect through this device")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Toggle("", isOn: $isHostListeningEnabled)
                        .onChange(of: isHostListeningEnabled) { _, newValue in
                            if newValue {
                                enableHostListening()
                            } else {
                                disableHostListening()
                            }
                        }
                

                }
            }
            
            Section("Device Info") {
                HStack {
                    Text("Local IP Address")
                    Spacer()
                    Text(getLocalIPAddress())
                        .foregroundColor(.gray)
                }
            }
            
            Section("Privacy") {
                Link("Privacy Policy", destination: URL(string: "https://theholylabs.com/privacy")!)
                    .foregroundColor(.blue)
            }
            
            Section("Legal") {
                Button("End User License Agreement") {
                    showingEULA = true
                }
                .foregroundColor(.primary)
            }
            
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.gray)
                }
                
                HStack {
                    Text("App Name")
                    Spacer()
                    Text("Rock VPN")
                        .foregroundColor(.gray)
                }
            }
        }
        .navigationTitle("Settings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
            #else
            ToolbarItem(placement: .primaryAction) {
                Button("Done") {
                    dismiss()
                }
            }
            #endif
        }
        .sheet(isPresented: $showingEULA) {
            EULAView()
        }
    }
    
    private func enableHostListening() {
        // Enable host mode to accept tunnel connections
        print("VPN Host mode enabled - accepting connections")
        // Note: This would need to be connected to the NetworkView's host mode
    }
    
    private func disableHostListening() {
        // Disable host mode to stop accepting tunnel connections
        print("VPN Host mode disabled - not accepting connections")
        // Note: This would need to be connected to the NetworkView's host mode
    }
    
    private func getLocalIPAddress() -> String {
        var address: String = "Unknown"
        
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else {
            return address
        }
        defer { freeifaddrs(ifaddr) }
        
        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }
            
            let interface = ptr?.pointee
            let addrFamily = interface?.ifa_addr.pointee.sa_family
            
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: (interface?.ifa_name)!)
                
                #if os(iOS)
                // iOS network interfaces
                if name == "en0" || name == "en1" || name == "en2" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface?.ifa_addr,
                               socklen_t((interface?.ifa_addr.pointee.sa_len)!),
                               &hostname,
                               socklen_t(hostname.count),
                               nil,
                               0,
                               NI_NUMERICHOST)
                    address = String(cString: hostname)
                    break
                }
                #else
                // macOS network interfaces
                if name == "en0" || name == "en1" || name == "en2" || name == "en3" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface?.ifa_addr,
                               socklen_t((interface?.ifa_addr.pointee.sa_len)!),
                               &hostname,
                               socklen_t(hostname.count),
                               nil,
                               0,
                               NI_NUMERICHOST)
                    address = String(cString: hostname)
                    break
                }
                #endif
            }
        }
        
        return address
    }
}

// MARK: - EULA View
struct EULAView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(eulaText)
                        .font(.system(size: 14))
                        .padding()
                }
            }
            .navigationTitle("End User License Agreement")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                #endif
            }
        }
    }
    
    private let eulaText = """
LICENSED APPLICATION END USER LICENSE AGREEMENT

Apps made available through the App Store are licensed, not sold, to you. Your license to each App is subject to your prior acceptance of either this Licensed Application End User License Agreement ("Standard EULA"), or a custom end user license agreement between you and the Application Provider ("Custom EULA"), if one is provided. Your license to any Apple App under this Standard EULA or Custom EULA is granted by Apple, and your license to any Third Party App under this Standard EULA or Custom EULA is granted by the Application Provider of that Third Party App. Any App that is subject to this Standard EULA is referred to herein as the "Licensed Application." The Application Provider or Apple as applicable ("Licensor") reserves all rights in and to the Licensed Application not expressly granted to you under this Standard EULA.

a. Scope of License: Licensor grants to you a nontransferable license to use the Licensed Application on any Apple-branded products that you own or control and as permitted by the Usage Rules. The terms of this Standard EULA will govern any content, materials, or services accessible from or purchased within the Licensed Application as well as upgrades provided by Licensor that replace or supplement the original Licensed Application, unless such upgrade is accompanied by a Custom EULA. Except as provided in the Usage Rules, you may not distribute or make the Licensed Application available over a network where it could be used by multiple devices at the same time. You may not transfer, redistribute or sublicense the Licensed Application and, if you sell your Apple Device to a third party, you must remove the Licensed Application from the Apple Device before doing so. You may not copy (except as permitted by this license and the Usage Rules), reverse-engineer, disassemble, attempt to derive the source code of, modify, or create derivative works of the Licensed Application, any updates, or any part thereof (except as and only to the extent that any foregoing restriction is prohibited by applicable law or to the extent as may be permitted by the licensing terms governing use of any open-sourced components included with the Licensed Application).

b. Consent to Use of Data: You agree that Licensor may collect and use technical data and related information—including but not limited to technical information about your device, system and application software, and peripherals—that is gathered periodically to facilitate the provision of software updates, product support, and other services to you (if any) related to the Licensed Application. Licensor may use this information, as long as it is in a form that does not personally identify you, to improve its products or to provide services or technologies to you.

c. Termination. This Standard EULA is effective until terminated by you or Licensor. Your rights under this Standard EULA will terminate automatically if you fail to comply with any of its terms.

d. External Services. The Licensed Application may enable access to Licensor's and/or third-party services and websites (collectively and individually, "External Services"). You agree to use the External Services at your sole risk. Licensor is not responsible for examining or evaluating the content or accuracy of any third-party External Services, and shall not be liable for any such third-party External Services. Data displayed by any Licensed Application or External Service, including but not limited to financial, medical and location information, is for general informational purposes only and is not guaranteed by Licensor or its agents. You will not use the External Services in any manner that is inconsistent with the terms of this Standard EULA or that infringes the intellectual property rights of Licensor or any third party. You agree not to use the External Services to harass, abuse, stalk, threaten or defame any person or entity, and that Licensor is not responsible for any such use. External Services may not be available in all languages or in your Home Country, and may not be appropriate or available for use in any particular location. To the extent you choose to use such External Services, you are solely responsible for compliance with any applicable laws. Licensor reserves the right to change, suspend, remove, disable or impose access restrictions or limits on any External Services at any time without notice or liability to you.

e. NO WARRANTY: YOU EXPRESSLY ACKNOWLEDGE AND AGREE THAT USE OF THE LICENSED APPLICATION IS AT YOUR SOLE RISK. TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, THE LICENSED APPLICATION AND ANY SERVICES PERFORMED OR PROVIDED BY THE LICENSED APPLICATION ARE PROVIDED "AS IS" AND "AS AVAILABLE," WITH ALL FAULTS AND WITHOUT WARRANTY OF ANY KIND, AND LICENSOR HEREBY DISCLAIMS ALL WARRANTIES AND CONDITIONS WITH RESPECT TO THE LICENSED APPLICATION AND ANY SERVICES, EITHER EXPRESS, IMPLIED, OR STATUTORY, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES AND/OR CONDITIONS OF MERCHANTABILITY, OF SATISFACTORY QUALITY, OF FITNESS FOR A PARTICULAR PURPOSE, OF ACCURACY, OF QUIET ENJOYMENT, AND OF NONINFRINGEMENT OF THIRD-PARTY RIGHTS. NO ORAL OR WRITTEN INFORMATION OR ADVICE GIVEN BY LICENSOR OR ITS AUTHORIZED REPRESENTATIVE SHALL CREATE A WARRANTY. SHOULD THE LICENSED APPLICATION OR SERVICES PROVE DEFECTIVE, YOU ASSUME THE ENTIRE COST OF ALL NECESSARY SERVICING, REPAIR, OR CORRECTION. SOME JURISDICTIONS DO NOT ALLOW THE EXCLUSION OF IMPLIED WARRANTIES OR LIMITATIONS ON APPLICABLE STATUTORY RIGHTS OF A CONSUMER, SO THE ABOVE EXCLUSION AND LIMITATIONS MAY NOT APPLY TO YOU.

f. Limitation of Liability. TO THE EXTENT NOT PROHIBITED BY LAW, IN NO EVENT SHALL LICENSOR BE LIABLE FOR PERSONAL INJURY OR ANY INCIDENTAL, SPECIAL, INDIRECT, OR CONSEQUENTIAL DAMAGES WHATSOEVER, INCLUDING, WITHOUT LIMITATION, DAMAGES FOR LOSS OF PROFITS, LOSS OF DATA, BUSINESS INTERRUPTION, OR ANY OTHER COMMERCIAL DAMAGES OR LOSSES, ARISING OUT OF OR RELATED TO YOUR USE OF OR INABILITY TO USE THE LICENSED APPLICATION, HOWEVER CAUSED, REGARDLESS OF THE THEORY OF LIABILITY (CONTRACT, TORT, OR OTHERWISE) AND EVEN IF LICENSOR HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES. SOME JURISDICTIONS DO NOT ALLOW THE LIMITATION OF LIABILITY FOR PERSONAL INJURY, OR OF INCIDENTAL OR CONSEQUENTIAL DAMAGES, SO THIS LIMITATION MAY NOT APPLY TO YOU. In no event shall Licensor's total liability to you for all damages (other than as may be required by applicable law in cases involving personal injury) exceed the amount of fifty dollars ($50.00). The foregoing limitations will apply even if the above stated remedy fails of its essential purpose.

g. You may not use or otherwise export or re-export the Licensed Application except as authorized by United States law and the laws of the jurisdiction in which the Licensed Application was obtained. In particular, but without limitation, the Licensed Application may not be exported or re-exported (a) into any U.S.-embargoed countries or (b) to anyone on the U.S. Treasury Department's Specially Designated Nationals List or the U.S. Department of Commerce Denied Persons List or Entity List. By using the Licensed Application, you represent and warrant that you are not located in any such country or on any such list. You also agree that you will not use these products for any purposes prohibited by United States law, including, without limitation, the development, design, manufacture, or production of nuclear, missile, or chemical or biological weapons.

h. The Licensed Application and related documentation are "Commercial Items", as that term is defined at 48 C.F.R. §2.101, consisting of "Commercial Computer Software" and "Commercial Computer Software Documentation", as such terms are used in 48 C.F.R. §12.212 or 48 C.F.R. §227.7202, as applicable. Consistent with 48 C.F.R. §12.212 or 48 C.F.R. §227.7202-1 through 227.7202-4, as applicable, the Commercial Computer Software and Commercial Computer Software Documentation are being licensed to U.S. Government end users (a) only as Commercial Items and (b) with only those rights as are granted to all other end users pursuant to the terms and conditions herein. Unpublished-rights reserved under the copyright laws of the United States.

i. Except to the extent expressly provided in the following paragraph, this Agreement and the relationship between you and Apple shall be governed by the laws of the State of California, excluding its conflicts of law provisions. You and Apple agree to submit to the personal and exclusive jurisdiction of the courts located within the county of Santa Clara, California, to resolve any dispute or claim arising from this Agreement. If (a) you are not a U.S. citizen; (b) you do not reside in the U.S.; (c) you are not accessing the Service from the U.S.; and (d) you are a citizen of one of the countries identified below, you hereby agree that any dispute or claim arising from this Agreement shall be governed by the applicable law set forth below, without regard to any conflict of law provisions, and you hereby irrevocably submit to the non-exclusive jurisdiction of the courts located in the state, province or country identified below whose law governs:

If you are a citizen of any European Union country or Switzerland, Norway or Iceland, the governing law and forum shall be the laws and courts of your usual place of residence.

Specifically excluded from application to this Agreement is that law known as the United Nations Convention on the International Sale of Goods.

Source: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
"""
}

// MARK: - Server Selector View
struct ServerSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedIP: String
    let availableIPs: [String]
    let devicePingResults: [String: PingResult]
    let defaultServerAddress: String
    @State private var isScanningNetwork = false
    
    private var backgroundColor: Color {
        #if os(iOS)
        return Color(.systemBackground)
        #else
        return Color(NSColor.windowBackgroundColor)
        #endif
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Select Server")
                    .font(.title)
                    .fontWeight(.bold)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(backgroundColor)
            
            // Content
            VStack(spacing: 20) {
                // Default VPN Server (always visible)
                VStack(alignment: .leading, spacing: 12) {
                    Text("VPN Server:")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ServerRow(
                        server: defaultServerAddress,
                        displayName: defaultServerAddress,
                        isSelected: selectedIP.isEmpty,
                        pingResult: devicePingResults[defaultServerAddress],
                        isDefault: true
                    ) {
                        selectedIP = ""
                        dismiss()
                    }
                }
                
                // Available Devices Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Available Devices:")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if !availableIPs.isEmpty {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(availableIPs.filter { 
                                    $0 != defaultServerAddress && 
                                    $0 != "169.254.153.231" 
                                }, id: \.self) { ip in
                                    ServerRow(
                                        server: ip,
                                        displayName: ip,
                                        isSelected: selectedIP == ip,
                                        pingResult: devicePingResults[ip],
                                        isDefault: false
                                    ) {
                                        selectedIP = ip
                                        dismiss()
                                    }
                                }
                            }
                        }
                        .refreshable {
                            // Pull to refresh - scan network for new devices
                            await refreshDeviceList()
                        }
                    } else {
                        Text("No other devices found.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .background(backgroundColor)
    }
    
    private func refreshDeviceList() async {
        // Trigger network scan to refresh available devices
        await MainActor.run {
            // This will trigger the parent view to refresh the device list
            // The parent view should handle the actual network scanning
        }
    }
}

// MARK: - Server Row Component
struct ServerRow: View {
    let server: String
    let displayName: String
    let isSelected: Bool
    let pingResult: PingResult?
    let isDefault: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(displayName)
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        

                    }
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        Text(statusText)
                            .font(.caption)
                            .foregroundColor(statusColor)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(isSelected ? Color.green.opacity(0.1) : Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var statusColor: Color {
        if isDefault {
            return .green
        }
        
        if let pingResult = pingResult {
            return pingResult.isReachable ? .green : .red
        }
        
        return .gray
    }
    
    private var statusText: String {
        if let pingResult = pingResult {
            if let pingMs = pingResult.pingMs {
                return "\(Int(pingMs))ms"
            } else {
                return pingResult.status
            }
        }
        
        return "Not tested"
    }
}
