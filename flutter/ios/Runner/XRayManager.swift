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
        
        // Load existing configuration
        vpnManager?.loadFromPreferences { error in
            if let error = error {
                print("⚠️ Error loading VPN preferences: \(error.localizedDescription)")
            } else {
                print("✅ VPN preferences loaded")
            }
        }
        
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
        
        print("🔄 XRay VPN Status changed: \(statusString)")
        
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
        
        // Extract UUID (user id) from the user part
        let uuid = String(uri.user ?? "")
        
        // Parse query parameters
        var queryParams: [String: String] = [:]
        if let query = uri.query {
            let components = query.components(separatedBy: "&")
            for component in components {
                let pair = component.components(separatedBy: "=")
                if pair.count == 2 {
                    queryParams[pair[0]] = pair[1].removingPercentEncoding ?? pair[1]
                }
            }
        }
        
        // Extract parameters
        let type = queryParams["type"] ?? "tcp"
        let security = queryParams["security"] ?? "none"
        let sni = queryParams["sni"]
        let fp = queryParams["fp"]
        let alpn = queryParams["alpn"]
        let pbk = queryParams["pbk"]
        let sid = queryParams["sid"]
        let spx = queryParams["spx"]
        let headerType = queryParams["headerType"]
        
        // Extract remark (server name) from fragment
        let remark = uri.fragment?.removingPercentEncoding ?? "VLESS Server"
        
        print("📋 Parsed VLESS URI:")
        print("   - Host: \(host)")
        print("   - Port: \(port)")
        print("   - UUID: \(uuid)")
        print("   - Type: \(type)")
        print("   - Security: \(security)")
        print("   - Remark: \(remark)")
        
        // Build XRay configuration
        var streamSettings: [String: Any] = [
            "network": type
        ]
        
        // Add security settings if present
        if security != "none" {
            var tlsSettings: [String: Any] = [:]
            if let sni = sni {
                tlsSettings["serverName"] = sni
            }
            if let fp = fp {
                tlsSettings["fingerprint"] = fp
            }
            if let alpn = alpn {
                tlsSettings["alpn"] = alpn.components(separatedBy: ",")
            }
            
            // Add reality settings if applicable
            if security == "reality" {
                var realitySettings: [String: Any] = [:]
                if let pbk = pbk {
                    realitySettings["publicKey"] = pbk
                }
                if let sid = sid {
                    realitySettings["shortId"] = sid
                }
                if let spx = spx {
                    realitySettings["spiderX"] = spx
                }
                tlsSettings["realitySettings"] = realitySettings
            }
            
            streamSettings["security"] = security
            streamSettings["tlsSettings"] = tlsSettings
        }
        
        // Add transport settings
        if type == "grpc" {
            streamSettings["grpcSettings"] = [
                "serviceName": queryParams["serviceName"] ?? ""
            ]
        } else if type == "ws" {
            streamSettings["wsSettings"] = [
                "path": queryParams["path"] ?? "/"
            ]
        } else if type == "tcp" {
            if let headerType = headerType {
                streamSettings["tcpSettings"] = [
                    "header": [
                        "type": headerType
                    ]
                ]
            }
        }
        
        let config: [String: Any] = [
            "inbounds": [
                [
                    "port": 10808,
                    "listen": "127.0.0.1",
                    "protocol": "socks",
                    "settings": [
                        "udp": true
                    ]
                ]
            ],
            "outbounds": [
                [
                    "protocol": "vless",
                    "settings": [
                        "vnext": [
                            [
                                "address": host,
                                "port": port,
                                "users": [
                                    [
                                        "id": uuid,
                                        "encryption": "none",
                                        "level": 0
                                    ]
                                ]
                            ]
                        ]
                    ],
                    "streamSettings": streamSettings
                ]
            ]
        ]
        
        return config
    }
    
    // Connect to VLESS server
    func connectVless(vlessUri: String, countryCode: String, countryName: String, completion: @escaping (Bool, String?) -> Void) {
        print("📡 Connecting to VLESS server: \(countryName) via XRay")
        
        guard let manager = vpnManager else {
            completion(false, "VPN Manager not initialized")
            return
        }
        
        guard let xrayConfig = parseVlessUri(vlessUri) else {
            completion(false, "Invalid VLESS URI")
            return
        }
        
        // Convert config to JSON data
        guard let jsonData = try? JSONSerialization.data(withJSONObject: xrayConfig, options: []) else {
            completion(false, "Failed to serialize XRay config")
            return
        }
        
        print("📋 XRay Config Size: \(jsonData.count) bytes")
        
        manager.loadFromPreferences { [weak self] error in
            if let error = error {
                completion(false, "Failed to load preferences: \(error.localizedDescription)")
                return
            }
            
            self?.configureVPN(manager: manager, xrayConfig: jsonData, countryName: countryName) { success, error in
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
    
    private func configureVPN(manager: NEVPNManager, xrayConfig: Data, countryName: String, completion: @escaping (Bool, String?) -> Void) {
        // Create packet tunnel protocol configuration
        let tunnelProtocol = NETunnelProviderProtocol()
        
        // Server address - must be set to a valid value
        tunnelProtocol.serverAddress = "127.0.0.1"
        
        // Store XRay config in provider configuration
        tunnelProtocol.providerConfiguration = [
            "xrayConfig": xrayConfig
        ]
        
        // Set the provider bundle identifier
        tunnelProtocol.providerBundleIdentifier = "com.theholylabs.network.PacketTunnelProvider"
        
        // Assign to manager
        manager.protocolConfiguration = tunnelProtocol
        manager.isEnabled = true
        manager.localizedDescription = "Rock VPN - \(countryName) (VLESS)"
        
        print("📋 Configuring VPN with:")
        print("   - Server Address: \(tunnelProtocol.serverAddress ?? "nil")")
        print("   - Provider Bundle ID: \(tunnelProtocol.providerBundleIdentifier ?? "nil")")
        print("   - Config Size: \(xrayConfig.count) bytes")
        
        // Save the configuration
        manager.saveToPreferences { error in
            if let error = error {
                let errorMessage = error.localizedDescription
                print("❌ Failed to save VPN configuration: \(errorMessage)")
                print("💡 Tip: Restart the app if you just updated the extension")
                
                completion(false, "Failed to save VPN configuration: \(errorMessage)")
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
    
    func getCurrentStatus() -> [String: Any] {
        guard let manager = vpnManager else {
            return ["status": "error", "isConnected": false]
        }
        
        let status = manager.connection.status
        let statusString = vpnStatusString(status)
        
        return [
            "status": statusString,
            "isConnected": status == .connected
        ]
    }
}
