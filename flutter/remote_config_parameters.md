# Firebase Remote Config Parameters

This document lists all Firebase Remote Config parameters needed for the VPN app.

## VPN Servers Parameter

**Parameter Name:** `vpn_servers`  
**Type:** String (JSON)  
**Description:** JSON array of VPN server configurations

**Value:** (see `remote_config_vpn_servers.json` for the full JSON array)

## VPN Credentials Parameters

### Username
**Parameter Name:** `vpn_username`  
**Type:** String  
**Default Value:** `dima`  
**Description:** VPN connection username

### Password
**Parameter Name:** `vpn_password`  
**Type:** String  
**Default Value:** `rabbit`  
**Description:** VPN connection password

### Shared Secret
**Parameter Name:** `vpn_shared_secret`  
**Type:** String  
**Default Value:** `ipsec-vpn-key`  
**Description:** VPN IPsec pre-shared key (PSK)

## Ad Configuration Parameters

### Interstitial Ads
**Parameter Name:** `interstitial_ads_enabled`  
**Type:** Boolean  
**Default Value:** `true`  
**Description:** Enable/disable interstitial ads

### Reward Ads
**Parameter Name:** `reward_ads_enabled`  
**Type:** Boolean  
**Default Value:** `true`  
**Description:** Enable/disable reward ads

## Setup Instructions

1. Go to **Firebase Console** → **Remote Config**
2. Add each parameter above with the specified type and default value
3. For `vpn_servers`, paste the JSON array from `remote_config_vpn_servers.json`
4. Click **"Publish changes"** after adding all parameters

## Notes

- All parameters will fall back to default values if Remote Config is unavailable
- VPN credentials can be updated remotely without app updates
- Server list can be updated remotely without app updates
- Ad configuration can be toggled remotely

