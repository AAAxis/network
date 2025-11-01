//
//  XRayManager.swift
//  Runner
//
//  Created for VLESS/XRay VPN Support using XRayVPNFramework
//

import Foundation
import NetworkExtension
import XRayVPNFramework
import Combine

class XRayManager: NSObject {
    static let shared = XRayManager()
    
    private var statusCancellable: AnyCancellable?
    private var currentVPNStatus: NEVPNStatus = .disconnected
    
    override init() {
        super.init()
        observeVPNStatus()
    }
    
    deinit {
        statusCancellable?.cancel()
    }
    
    private func observeVPNStatus() {
        // Observe VPN status changes from XRayVPN service (as per README step 1)
        statusCancellable = XRayVPN.vpnService.status.sink { [weak self] status in
            self?.statusDidChange(status)
        }
    }
    
    private func statusDidChange(_ status: NEVPNStatus) {
        currentVPNStatus = status
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
    func parseVlessUri(_ uriString: String) -> String? {
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
        
        // Convert to JSON string
        guard let jsonData = try? JSONSerialization.data(withJSONObject: config, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("❌ Failed to serialize XRay config")
            return nil
        }
        
        return jsonString
    }
    
    // Connect to VLESS server using XRayVPN.vpnService (as per README step 2)
    func connectVless(vlessUri: String, countryCode: String, countryName: String, completion: @escaping (Bool, String?) -> Void) {
        print("📡 Connecting to VLESS server: \(countryName) via XRay")
        
        guard let configString = parseVlessUri(vlessUri) else {
            completion(false, "Invalid VLESS URI")
            return
        }
        
        print("📋 XRay Config JSON:")
        print(configString)
        
        // Store config in app group shared UserDefaults for PacketTunnelProvider to read
        if let sharedDefaults = UserDefaults(suiteName: "group.com.theholylabs.network") {
            sharedDefaults.set(configString, forKey: "xrayConfig")
            sharedDefaults.synchronize()
        }
        
        // Use XRayVPN.vpnService.connect() as per README
        Task {
            do {
                try await XRayVPN.vpnService.connect()
                print("✅ XRay VPN connected successfully")
                completion(true, nil)
            } catch {
                print("❌ XRay VPN connection failed: \(error.localizedDescription)")
                completion(false, "Connection failed: \(error.localizedDescription)")
            }
        }
    }
    
    // Disconnect from VPN (as per README step 3)
    func disconnectVless(completion: @escaping (Bool, String?) -> Void) {
        print("📡 Disconnecting XRay VPN...")
        XRayVPN.vpnService.disconnect()
        completion(true, nil)
    }
    
    func getCurrentStatus() -> [String: Any] {
        let statusString = vpnStatusString(currentVPNStatus)
        
        return [
            "status": statusString,
            "isConnected": currentVPNStatus == .connected
        ]
    }
}
