#!/bin/bash

# VPN Connection Test Script
# This script tests if your VPN server is reachable

VPN_SERVER="69.197.134.25"
VPN_PORTS=(500 4500)

echo "🔍 Testing VPN server connectivity to $VPN_SERVER"
echo "=================================================="

# Test basic ping
echo "📡 Testing basic connectivity..."
if ping -c 3 $VPN_SERVER > /dev/null 2>&1; then
    echo "✅ Server is reachable via ping"
else
    echo "❌ Server is not reachable via ping"
    echo "   This might indicate a network issue or server is down"
fi

echo ""

# Test VPN ports
echo "🔐 Testing VPN ports..."
for port in "${VPN_PORTS[@]}"; do
    echo -n "Port $port (UDP): "
    
    # Test UDP port
    if nc -zu $VPN_SERVER $port 2>/dev/null; then
        echo "✅ OPEN"
    else
        echo "❌ CLOSED"
    fi
done

echo ""

# Test from Docker container if available
if command -v docker &> /dev/null; then
    echo "🐳 Testing from Docker container..."
    
    # Check if ipsec-vpn container is running
    if docker ps | grep -q ipsec-vpn; then
        echo "✅ IPSec VPN container is running"
        
        # Check VPN server logs
        echo "📋 Recent VPN server logs:"
        docker logs ipsec-vpn --tail 10 | grep -E "(error|fail|success|connected)" || echo "No relevant logs found"
        
        # Check if VPN service is listening
        echo "🔍 Checking if VPN service is listening on ports:"
        for port in "${VPN_PORTS[@]}"; do
            if docker exec ipsec-vpn netstat -tulpn 2>/dev/null | grep -q ":$port"; then
                echo "✅ Port $port is being listened to"
            else
                echo "❌ Port $port is not being listened to"
            fi
        done
    else
        echo "❌ IPSec VPN container is not running"
        echo "   Start it with: docker-compose up ipsec-vpn"
    fi
else
    echo "🐳 Docker not available, skipping container checks"
fi

echo ""

# Test proxy router if available
echo "🌐 Testing proxy router..."
PROXY_ROUTER_URL="https://vpn.theholylabs.com/api/proxy/status"

if curl -s "$PROXY_ROUTER_URL" > /dev/null 2>&1; then
    echo "✅ Proxy router is accessible"
    
    # Get proxy router status
    RESPONSE=$(curl -s "$PROXY_ROUTER_URL")
    if [ $? -eq 0 ]; then
        echo "📊 Proxy router status:"
        echo "$RESPONSE" | jq '.' 2>/dev/null || echo "$RESPONSE"
    fi
else
    echo "❌ Proxy router is not accessible"
    echo "   URL: $PROXY_ROUTER_URL"
fi

echo ""
echo "=================================================="
echo "🎯 Summary:"
echo "1. If ping fails: Check if server is online"
echo "2. If ports are closed: Check firewall rules on server"
echo "3. If Docker container not running: Start with docker-compose"
echo "4. If proxy router fails: Check nginx and backend services"
echo ""
echo "🔧 Next steps:"
echo "1. Ensure UDP ports 500 and 4500 are open on your server"
echo "2. Check VPN server logs: docker logs ipsec-vpn"
echo "3. Test iOS app connection"
echo "4. Check proxy router configuration"
