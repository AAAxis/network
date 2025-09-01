#!/bin/bash

echo "🔍 Testing Proxy Routing Solution"
echo "================================="

echo ""
echo "📱 Proxy Routing Flow:"
echo "  1. iOS device connects to VPN server (enters the 'room')"
echo "  2. iOS device registers as a proxy router"
echo "  3. iOS device creates proxy route to target device"
echo "  4. Traffic flows: Internet → VPN Server → iOS Device → Target Device"

echo ""
echo "🌐 VPN Server: 69.197.134.25"
echo "🔑 iOS Account: ios_device / ios123"
echo "🔑 Laptop Account: laptop_device / laptop123"

echo ""
echo "📡 Testing Proxy Router API endpoints..."

# Test proxy router status
echo "🔍 Testing proxy router status..."
curl -s "https://vpn.theholylabs.com/api/proxy/status" | jq '.status.system_status' 2>/dev/null || echo "❌ Status endpoint not accessible"

# Test client registration
echo "🔍 Testing client registration..."
curl -s "https://vpn.theholylabs.com/api/proxy/register" -X POST -H "Content-Type: application/json" -d '{"client_id":"test_ios","original_ip":"169.254.153.231","vpn_ip":"169.254.153.231","is_router":true,"can_proxy":true}' | jq '.success' 2>/dev/null || echo "❌ Registration endpoint not accessible"

# Test proxy route creation
echo "🔍 Testing proxy route creation..."
curl -s "https://vpn.theholylabs.com/api/proxy/route" -X POST -H "Content-Type: application/json" -d '{"source_ip":"169.254.153.231","target_ip":"172.20.10.8","route_type":"vpn_proxy"}' | jq '.success' 2>/dev/null || echo "❌ Route creation endpoint not accessible"

echo ""
echo "💡 To test the complete flow:"
echo "  1. Deploy the updated docker-compose.yml with multiple VPN users"
echo "  2. Connect iOS device to VPN using ios_device/ios123"
echo "  3. Connect laptop to VPN using laptop_device/laptop123"
echo "  4. iOS device will create proxy route to laptop"
echo "  5. Traffic will flow through iOS device as proxy"
