//
//  XRayManager.swift
//  Runner
//
//  Created for VLESS/XRay VPN Support
//

import Foundation
import NetworkExtension

class XRayManager: NSObject {
    static let shared = XRayManager()
    
    private var vpnManager: NEVPNManager?
    private var statusObserver: NSObjectProtocol?
    
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
        case .connected:
            return "connected"
        case .connecting:
            return "connecting"
        case .disconnected:
            return "disconnected"
        case .disconnecting:
            return "disconnecting"
        case .invalid:
            return "failed"
        case .reasserting:
            return "connecting"
        @unknown default:
            return "unknown"
        }
    }
    
    // Parse VLESS URI and generate XRay config JSON
    func parseVlessUri(_ uriString: String) -> [String: Any]? {
        guard let uri = URL(string: uriString),
              uri.scheme == "vless",
              let host = uri.host,
              let port = uri.port else {
            print("❌ Invalid VLESS URI format")
            return nil
        }
        
        // Extract UUID from user info (format: vless://UUID@host:port)
        let userInfo = uri.user?.isEmpty == false ? uri.user : nil
        guard let uuid = userInfo else {
            print("❌ Missing UUID in VLESS URI")
            return nil
        }
        
        // Parse query parameters
        var queryParams: [String: String] = [:]
        if let query = uri.query {
            let pairs = query.components(separatedBy: "&")
            for pair in pairs {
                let parts = pair.components(separatedBy: "=")
                if parts.count == 2 {
                    queryParams[parts[0]] = parts[1].removingPercentEncoding ?? parts[1]
                }
            }
        }
        
        // Extract path from query params (ws path)
        let wsPath = queryParams["path"] ?? "/xray"
        let encryption = queryParams["encryption"] ?? "none"
        let network = queryParams["type"] ?? "ws"
        
        // Generate XRay config with SOCKS inbound for PacketTunnelProvider
        let config: [String: Any] = [
            "log": [
                "loglevel": "warning"
            ],
            "inbounds": [
                [
                    "tag": "socks",
                    "port": 10808,
                    "listen": "127.0.0.1",
                    "protocol": "socks",
                    "settings": [
                        "auth": "noauth",
                        "udp": true
                    ]
                ]
            ],
            "outbounds": [
                [
                    "tag": "proxy",
                    "protocol": "vless",
                    "settings": [
                        "vnext": [
                            [
                                "address": host,
                                "port": port,
                                "users": [
                                    [
                                        "id": uuid,
                                        "encryption": encryption,
                                        "flow": ""
                                    ]
                                ]
                            ]
                        ]
                    ],
                    "streamSettings": [
                        "network": network,
                        "security": queryParams["security"] ?? "none",
                        "wsSettings": [
                            "path": wsPath,
                            "headers": [:]
                        ]
                    ]
                ],
                [
                    "tag": "direct",
                    "protocol": "freedom"
                ],
                [
                    "tag": "block",
                    "protocol": "blackhole"
                ]
            ],
            "routing": [
                "domainStrategy": "IPIfNonMatch",
                "rules": [
                    [
                        "type": "field",
                        "outboundTag": "direct",
                        "domain": ["geosite:cn"]
                    ]
                ]
            ]
        ]
        
        return config
    }
    
    // Connect to VLESS server
    func connectVless(vlessUri: String, countryCode: String, countryName: String, completion: @escaping (Bool, String?) -> Void) {
        guard let manager = vpnManager else {
            completion(false, "VPN Manager not initialized")
            return
        }
        
        guard let xrayConfig = parseVlessUri(vlessUri) else {
            completion(false, "Failed to parse VLESS URI")
            return
        }
        
        // Convert config to JSON data
        guard let jsonData = try? JSONSerialization.data(withJSONObject: xrayConfig, options: []) else {
            completion(false, "Failed to serialize XRay config")
            return
        }
        
        print("📡 Connecting to VLESS server: \(countryName) via XRay")
        
        manager.loadFromPreferences { [weak self] error in
            if let error = error {
                completion(false, "Failed to load preferences: \(error.localizedDescription)")
                return
            }
            
            self?.configureVPN(manager: manager, xrayConfig: jsonData, countryName: countryName) { success, error in
                if success {
                    do {
                        try manager.connection.startVPNTunnel()
                        print("✅ VPN tunnel start initiated successfully")
                        completion(true, nil)
                    } catch {
                        print("❌ Failed to start VPN tunnel: \(error.localizedDescription)")
                        completion(false, "Failed to start VPN: \(error.localizedDescription)")
                    }
                } else {
                    print("❌ VPN configuration failed: \(error ?? "Unknown error")")
                    completion(false, error)
                }
            }
        }
    }
    
    private func configureVPN(manager: NEVPNManager, xrayConfig: Data, countryName: String, completion: @escaping (Bool, String?) -> Void) {
        // Create packet tunnel protocol configuration
        let tunnelProtocol = NETunnelProviderProtocol()
        tunnelProtocol.serverAddress = "127.0.0.1"
        tunnelProtocol.username = ""
        tunnelProtocol.passwordReference = nil
        
        // Store XRay config in provider configuration
        tunnelProtocol.providerConfiguration = [
            "xrayConfig": xrayConfig
        ]
        
        // NOTE: The packet tunnel provider bundle identifier must match your app's extension
        // Update this to match your actual packet tunnel extension bundle ID
        tunnelProtocol.providerBundleIdentifier = "com.theholylabs.network.PacketTunnelProvider"
        
        manager.protocolConfiguration = tunnelProtocol
        manager.isEnabled = true
        manager.localizedDescription = "Rock VPN - \(countryName) (VLESS)"
        
        // Save the configuration
        manager.saveToPreferences { error in
            if let error = error {
                completion(false, "Failed to save VPN configuration: \(error.localizedDescription)")
            } else {
                print("✅ VPN configured for VLESS: \(countryName)")
                completion(true, nil)
            }
        }
    }
    
    func disconnectVless(completion: @escaping (Bool, String?) -> Void) {
        guard let manager = vpnManager else {
            completion(false, "VPN Manager not initialized")
            return
        }
        
        manager.connection.stopVPNTunnel()
        completion(true, nil)
    }
}

