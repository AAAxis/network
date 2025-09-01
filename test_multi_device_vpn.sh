#!/bin/bash

echo "🔍 Testing Multi-Device VPN Setup"
echo "=================================="

# Test VPN server accessibility
echo "📡 Testing VPN server accessibility..."
ping -c 3 69.197.134.25

echo ""
echo "🔐 VPN User Accounts Available:"
echo "  - dima:rabbit (original)"
echo "  - ios_device:ios123 (iOS device)"
echo "  - laptop_device:laptop123 (laptop)"

echo ""
echo "📱 To test multi-device VPN:"
echo "  1. Connect iOS device using: ios_device / ios123"
echo "  2. Connect laptop using: laptop_device / laptop123"
echo "  3. Both devices should be able to see each other through VPN"

echo ""
echo "🌐 VPN Server IP: 69.197.134.25"
echo "🔑 Shared Secret: ipsec-vpn-key"
echo "📡 Ports: 500/udp, 4500/udp"

echo ""
echo "💡 After both devices connect:"
echo "  - iOS device should be able to ping laptop"
echo "  - Laptop should be able to ping iOS device"
echo "  - Traffic routes through VPN server"
