# VPN Connection Fix

## The Problem
Your VPN server is not responding because:
1. **iOS app** tries to connect to `69.197.134.25` (your public VPN server)
2. **VPN server** is running in Docker but ports might not be properly exposed
3. **Proxy router** is trying to connect to private addresses

## The Solution

### Step 1: Fix Docker VPN Server Ports
Your `docker-compose.yml` has the VPN server configured, but the ports might not be accessible from the internet.

**Current configuration:**
```yaml
ipsec-vpn:
  ports:
    - "500:500/udp"    # IPSec IKE
    - "4500:4500/udp"  # IPSec NAT-T
```

**Make sure these ports are open on your server firewall:**
```bash
# On your server, check if ports are open
sudo ufw allow 500/udp
sudo ufw allow 4500/udp

# Or if using iptables
sudo iptables -A INPUT -p udp --dport 500 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 4500 -j ACCEPT
```

### Step 2: Test VPN Server Connectivity
Test if your VPN server is reachable:

```bash
# Test from your local machine
nc -zu 69.197.134.25 500
nc -zu 69.197.134.25 4500

# Or use telnet
telnet 69.197.134.25 500
telnet 69.197.134.25 4500
```

### Step 3: Check VPN Server Status
Check if your VPN server is running properly:

```bash
# Check Docker container status
docker ps | grep ipsec-vpn

# Check VPN server logs
docker logs ipsec-vpn

# Check if VPN service is listening
docker exec ipsec-vpn netstat -tulpn | grep -E ':(500|4500)'
```

### Step 4: iOS App Connection Flow
The correct connection flow should be:

1. **iOS app** → **VPN Server** (`69.197.134.25:500/4500`)
2. **After VPN connection** → **Proxy to other devices**

### Step 5: Fix iOS App VPN Configuration
Make sure your iOS app is using the correct VPN settings:

- **Server**: `69.197.134.25`
- **Username**: `dima`
- **Password**: `rabbit`
- **Shared Secret**: `ipsec-vpn-key`
- **Protocol**: IPSec

### Step 6: Test Connection
1. Build and run your iOS app
2. Try to connect to VPN
3. Check console logs for connection errors
4. Use the VPN connection test function I added

## Common Issues & Solutions

### Issue: "VPN server did not respond"
**Solution**: Check if ports 500 and 4500 are open on your server

### Issue: "Tunnel listener started - ready to accept connections"
**Solution**: This means the VPN connection was successful, but the proxy routing isn't working

### Issue: "Device registered successfully, Registered as tunnel host successfully"
**Solution**: This means your device connected to the VPN server, but the proxy routing to other devices failed

## Next Steps
1. Test your VPN server connectivity
2. Make sure firewall rules allow UDP ports 500 and 4500
3. Test the iOS app connection
4. If VPN connects but proxy fails, check the proxy router configuration

## Debug Commands
```bash
# Check VPN server status
docker exec ipsec-vpn ipsec status

# Check VPN server logs
docker logs ipsec-vpn

# Test VPN connectivity
nc -zu 69.197.134.25 500
nc -zu 69.197.134.25 4500

# Check server firewall
sudo ufw status
sudo iptables -L -n
```
