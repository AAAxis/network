//
//  PacketTunnelProvider.swift
//  PacketTunnelProvider
//
//  Complete XRay/VLESS implementation with Tun2SocksKit
//

import NetworkExtension
import XRay
import Tun2SocksKit
import os

final class PacketTunnelProvider: NEPacketTunnelProvider {
    override func startTunnel(options: [String : NSObject]? = nil) async throws {
        // Try to get config from providerConfiguration first
        var xrayConfig: Data?
        
        if let protocolConfiguration = protocolConfiguration as? NETunnelProviderProtocol,
           let providerConfiguration = protocolConfiguration.providerConfiguration,
           let configData = providerConfiguration["xrayConfig"] as? Data {
            xrayConfig = configData
        } else if let sharedDefaults = UserDefaults(suiteName: "group.com.theholylabs.network"),
                  let configString = sharedDefaults.string(forKey: "xrayConfig"),
                  let configData = configString.data(using: .utf8) {
            // Fallback to app group shared defaults
            xrayConfig = configData
        }
        
        guard let xrayConfig = xrayConfig else {
            throw NSError(domain: "PacketTunnelProvider", code: 1, userInfo: [NSLocalizedDescriptionKey: "No XRay config found"])
        }
        guard let tunport: Int = parseConfig(jsonData: xrayConfig) else {
            throw NSError()
        }

        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "254.1.1.1")
        settings.mtu = 9000
        settings.ipv4Settings = {
            let settings = NEIPv4Settings(addresses: ["198.18.0.1"], subnetMasks: ["255.255.0.0"])
            settings.includedRoutes = [NEIPv4Route.default()]
            return settings
        }()
        settings.ipv6Settings = {
            let settings = NEIPv6Settings(addresses: ["fd6e:a81b:704f:1211::1"], networkPrefixLengths: [64])
            settings.includedRoutes = [NEIPv6Route.default()]
            return settings
        }()
        settings.dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "114.114.114.114"])
        try await self.setTunnelNetworkSettings(settings)
        self.startXRay(xrayConfig: xrayConfig)
        self.startSocks5Tunnel(serverPort: tunport)

    }
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        stopXRay()
        Socks5Tunnel.quit()

        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        if let message = String(data: messageData, encoding: .utf8) {
            if (message == "xray_traffic"){
                completionHandler?("\(Socks5Tunnel.stats.up.bytes),\(Socks5Tunnel.stats.down.bytes)".data(using: .utf8))
            }else if (message.hasPrefix("xray_delay")){
                var error: NSError?
                var delay: Int64 = -1
                let url = String(message[message.index(message.startIndex, offsetBy: 10)...])
                XRayMeasureDelay(url, &delay, &error)
                completionHandler?("\(delay)".data(using: .utf8))
            }
            else{
                completionHandler?(messageData)
            }

        }else{
            completionHandler?(messageData)
        }
    }

    override func sleep(completionHandler: @escaping () -> Void) {
        completionHandler()
    }

    private func startSocks5Tunnel(serverPort port: Int) {
        let config = """
        tunnel:
          mtu: 9000
        socks5:
          port: \(port)
          address: 127.0.0.1
          udp: 'udp'
        misc:
          task-stack-size: 20480
          connect-timeout: 5000
          read-write-timeout: 60000
          log-file: stdout
          log-level: debug
          limit-nofile: 65535
        """
        DispatchQueue.global(qos: .userInitiated).async {
            _ = Socks5Tunnel.run(withConfig: .string(content: config))
        }
    }

    private func startXRay(xrayConfig: Data) {
        XRaySetMemoryLimit()

        var error: NSError?
        _ = XRayStart(xrayConfig, nil, &error)
    }

    private func stopXRay() {
        XRayStop()
    }

    private func parseConfig(jsonData: Data) -> Int? {
        do {
            if let configJSON = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any],
               let inbounds = configJSON["inbounds"] as? [[String: Any]] {
                for inbound in inbounds {
                    if let protocolType = inbound["protocol"] as? String, let port = inbound["port"] as? Int {
                        switch protocolType {
                        case "socks":
                            return port
                        case "http":
                            return port
                        default:
                            break
                        }
                    }
                }
            }
        } catch {
            print("Failed to parse JSON: \(error)")
        }
        return nil;
    }
}
