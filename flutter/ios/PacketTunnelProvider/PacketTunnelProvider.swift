//
//  PacketTunnelProvider.swift
//  PacketTunnelProvider
//
//  Created for VLESS/XRay VPN Support
//

import NetworkExtension
import os

final class PacketTunnelProvider: NEPacketTunnelProvider {
    
    private let logger = Logger(subsystem: "com.theholylabs.network.PacketTunnelProvider", category: "VPN")
    
    override func startTunnel(options: [String : NSObject]? = nil) async throws {
        logger.info("🚀 PacketTunnelProvider: Starting tunnel...")
        
        do {
            guard
                let protocolConfiguration = protocolConfiguration as? NETunnelProviderProtocol,
                let providerConfiguration = protocolConfiguration.providerConfiguration
            else {
                logger.error("❌ PacketTunnelProvider: Invalid protocol configuration")
                throw NSError(domain: "PacketTunnelProvider", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid protocol configuration"])
            }
            
            guard let xrayConfigData: Data = providerConfiguration["xrayConfig"] as? Data else {
                logger.error("❌ PacketTunnelProvider: Missing XRay config")
                throw NSError(domain: "PacketTunnelProvider", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing XRay config"])
            }
            
            logger.info("✅ PacketTunnelProvider: Received XRay config: \(xrayConfigData.count) bytes")
            
            // Configure tunnel network settings
            let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "254.1.1.1")
            settings.mtu = 1500
            
            settings.ipv4Settings = {
                let settings = NEIPv4Settings(addresses: ["198.18.0.1"], subnetMasks: ["255.255.0.0"])
                settings.includedRoutes = [NEIPv4Route.default()]
                return settings
            }()
            
            settings.dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "1.1.1.1"])
            
            try await self.setTunnelNetworkSettings(settings)
            logger.info("✅ PacketTunnelProvider: Network settings configured successfully")
            
            // For now, just create a basic tunnel - we'll add XRay later
            logger.info("✅ PacketTunnelProvider: Basic tunnel started successfully")
            
        } catch {
            logger.error("❌ PacketTunnelProvider: Failed to start tunnel: \(error.localizedDescription)")
            throw error
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        logger.info("🛑 PacketTunnelProvider: Stopping tunnel (reason: \(reason.rawValue))...")
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        if let message = String(data: messageData, encoding: .utf8) {
            logger.debug("📨 PacketTunnelProvider: Received message: \(message)")
        }
        completionHandler?(messageData)
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
        logger.debug("😴 PacketTunnelProvider: Sleep called")
        completionHandler()
    }
}