//
//  PacketTunnelProvider.swift
//  PacketTunnelProvider
//
//  Created by Admin on 31/10/2025.
//

import NetworkExtension

class PacketTunnelProvider: NEPacketTunnelProvider {

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        print("✅ PacketTunnelProvider: startTunnel called")
        
        // Get XRay config from provider configuration
        guard let protocolConfig = self.protocolConfiguration as? NETunnelProviderProtocol,
              let providerConfig = protocolConfig.providerConfiguration,
              let xrayConfigData = providerConfig["xrayConfig"] as? Data else {
            print("❌ PacketTunnelProvider: No XRay config found in provider configuration")
            // Even without config, complete to allow VPN to be configured
            // The actual config will be used when connecting
            completionHandler(nil)
            return
        }
        
        print("✅ PacketTunnelProvider: Starting tunnel with config size: \(xrayConfigData.count) bytes")
        
        // TODO: Initialize XRay with config and start tunnel
        // For now, just set up basic network settings to allow the VPN configuration to be saved
        // The actual XRay implementation will be added later
        
        // Set up network settings
        let networkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        
        // Configure IPv4 settings
        let ipv4Settings = NEIPv4Settings(addresses: ["10.0.0.2"], subnetMasks: ["255.255.255.0"])
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        networkSettings.ipv4Settings = ipv4Settings
        
        // Set DNS
        let dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "8.8.4.4"])
        networkSettings.dnsSettings = dnsSettings
        
        // Apply network settings
        setTunnelNetworkSettings(networkSettings) { error in
            if let error = error {
                print("❌ PacketTunnelProvider: Failed to set network settings: \(error.localizedDescription)")
                completionHandler(error)
            } else {
                print("✅ PacketTunnelProvider: Tunnel started successfully")
                completionHandler(nil)
            }
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // Add code here to start the process of stopping the tunnel.
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Add code here to handle the message.
        if let handler = completionHandler {
            handler(messageData)
        }
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
        // Add code here to get ready to sleep.
        completionHandler()
    }
    
    override func wake() {
        // Add code here to wake up.
    }
}
